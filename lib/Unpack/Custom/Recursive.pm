package Unpack::Custom::Recursive;

use strict;
use warnings;

use File::Path qw(make_path);
use File::Copy;
use Digest::SHA qw(sha256_hex);
use Unpack::Custom;

our $VERSION = "0.3.0";

our %callbacks = (
    initialize => sub {
        my ($self) = @_;

        my $var = $self->{var};
        make_path($var->{destination});

        $var->{name_of}         = {}; # sha => { name, parent, sha }
        $var->{seen}            = {}; # sha => 1 for every file queued so far
        $var->{sha_of}          = {}; # queued filename => sha
        $var->{depth_of}        = {}; # sha => nesting level (inputs are 0)
        $var->{extracted_bytes} = 0;
        $var->{names}           = [];

        my @queue;
        for my $file (@{ $var->{files} }) {
            my $sha = file_sha($file);
            next if $var->{seen}{$sha}++; # same content given twice

            my $target = dat_filename($self, $sha);
            if (! -e $target) {
                copy($file, $target) #TODO: expensive copy
                    or die "Cannot copy '$file' to '$target': $!";
            }
            $var->{name_of}{$sha}  = { name => $file, parent => '', sha => $sha };
            $var->{sha_of}{$target} = $sha;
            $var->{depth_of}{$sha}  = 0;
            push @queue, $target;
        }
        @{ $var->{files} } = @queue;
    },

    finalize => sub {
        my ($self) = @_;

        my $name_of = $self->{var}{name_of};

        for my $value (values %$name_of) {
            my @parents = ($value->{sha});
            $value->{parents} = \@parents;
            my $item = $value;
            while ($item = $name_of->{ $item->{parent} }) {
                last if grep $_ eq $item->{sha}, @parents;
                push @parents, $item->{sha};
            }
        }

        my $names_file = "$self->{var}{destination}/names.txt";
        open my $fh, '>:raw', $names_file
            or die "Cannot write '$names_file': $!";
        for my $key (sort keys %$name_of) {
            my $fullname = join '/', map {
                    escape_name($name_of->{$_}->{name})
                } reverse @{ $name_of->{$key}{parents} };
            print {$fh} "$key\t$fullname\n"
                or die "Cannot write '$names_file': $!";
        }
        close $fh
            or die "Cannot write '$names_file': $!";

        return $name_of;
    },

    before_unpack => sub {
        my ($self, $file) = @_;

        my $var = $self->{var};
        $var->{names} = [];

        # reuse the listing made by want_unpack
        my $cached = delete $var->{info};
        my ($list, $info) = $cached && $cached->{file} eq $file
            ? @{$cached}{qw(list info)}
            : $self->{szip}->info($file, $self->password_params);

        # multivolume archive (e.g. RAR): the first and the last file of
        # a volume may be only partially contained in it, skip them
        if ($info && ($info->{multivolume} // '') eq '+' && @$list) {
            my @excluded = (pop @$list);
            if (($info->{characteristics} // '') !~ /FirstVolume/ && @$list) {
                push @excluded, shift @$list;
            }
            for my $excluded (@excluded) {
                my $path = $excluded->{path} // next;
                # wildcard characters in the name have to be taken literally
                push @{ $var->{extra_params} }, '-spd'
                    if $path =~ /[*?]/
                    && ! grep { $_ eq '-spd' } @{ $var->{extra_params} };
                push @{ $var->{extra_params} }, "-x!$path";
            }
        }
        $var->{list} = $list;
    },

    after_unpack => sub {
        my ($self, $file, $extracted_files, $corrupted_paths) = @_;

        my $var        = $self->{var};
        my $parent_sha = $var->{sha_of}{$file} // file_sha($file);
        my $depth      = ($var->{depth_of}{$parent_sha} // 0) + 1;
        my $name_of    = $var->{name_of};
        my %corrupted  = map { $_ => 1 } @$corrupted_paths;

        my $extracted_ok = 0;
        for my $item (@{ $var->{names} }) {
            if ($corrupted{ $item->{name} }) {
                warn "Deleting corrupted file '$item->{name}' extracted from '$file'\n";
                # delete only a file which was written for this corrupted item
                unlink dat_filename($self, $item->{sha}) if $item->{written};
                next;
            }
            $extracted_ok++;

            # the first name seen for a content is kept
            next if $name_of->{ $item->{sha} };
            $name_of->{ $item->{sha} } = {
                name   => $item->{name},
                parent => $parent_sha,
                sha    => $item->{sha},
            };
            $var->{depth_of}{ $item->{sha} } = $depth;

            # recursive unpack: put newly extracted files to the queue
            next if $self->{no_recursive};
            next if $var->{seen}{ $item->{sha} }++;
            next if defined $self->{max_depth} && $depth > $self->{max_depth};
            my $filename = dat_filename($self, $item->{sha});
            next if ! -e $filename;
            $var->{sha_of}{$filename} = $item->{sha};
            push @{ $var->{files} }, $filename;
        }

        if ($extracted_ok) {
            unlink $file; #was an archive, now it is extracted, delete it
        }
    },

    want_unpack => sub {
        my ($self, $file) = @_;

        my ($list, $info) = $self->{szip}->info($file, $self->password_params);
        $self->{var}{info} = { file => $file, list => $list, info => $info };

        return @$list > 0;
    },

    save => sub {
        my ($self, $contents, $file) = @_;

        return if ! $file || ! defined $file->{path};

        my $var = $self->{var};
        my $sha = sha256_hex($contents);

        # the same content twice in one archive
        return if grep { $_->{sha} eq $sha } @{ $var->{names} };

        my $item = { sha => $sha, name => $file->{path}, written => 0 };
        my $filename = dat_filename($self, $sha);

        # content seen before (possibly an archive which was already unpacked
        # and deleted) or already present in the destination: nothing to write
        if (! $var->{seen}{$sha} && ! -e $filename) {
            my $size = length $contents;
            if (defined $self->{max_extracted_size}
                && $var->{extracted_bytes} + $size > $self->{max_extracted_size}
            ) {
                warn "Skipping '$file->{path}': max_extracted_size exceeded\n";
                return;
            }
            $var->{extracted_bytes} += $size;

            open my $fh, '>:raw', $filename
                or die "Cannot write '$filename': $!";
            print {$fh} $contents
                or die "Cannot write '$filename': $!";
            close $fh
                or die "Cannot write '$filename': $!";
            $item->{written} = 1;
        }

        push @{ $var->{names} }, $item;

        return $filename
    }
);

sub new {
    my ($class, $args) = @_;

    $args = { %callbacks, %{ $args // {} } };
    $args->{_unpack_custom} = 'Unpack::Custom'->new($args);

    return bless $args, $class;
}

sub extract {
    my $self = shift;
    return $self->{_unpack_custom}->extract(@_);
}

sub dat_filename {
    my ($self, $sha) = @_;

    return "$self->{var}{destination}/$sha.dat";
}

sub file_sha {
    my ($filename) = @_;

    open my $fh, '<:raw', $filename
        or die "Cannot read '$filename': $!";
    my $sha = 'Digest::SHA'->new(256)->addfile($fh)->hexdigest();
    close $fh;

    return $sha;
}

# names.txt is tab separated, one record per line
sub escape_name {
    my ($name) = @_;

    my %escape = ("\\" => "\\\\", "\t" => "\\t", "\n" => "\\n", "\r" => "\\r");
    $name =~ s/([\\\t\n\r])/$escape{$1}/g;

    return $name;
}

1;
__END__

=encoding utf-8

=for stopwords deduplicated quine

=head1 NAME

Unpack::Custom::Recursive - extract archives recursively, deduplicated by content

=head1 SYNOPSIS

    use Unpack::Custom::Recursive;

    my $unpacker = Unpack::Custom::Recursive->new({
        max_depth          => 10,         # optional
        max_extracted_size => 2 ** 30,    # optional, in bytes
    });
    my $name_of = $unpacker->extract(['photos.zip'], 'destination', ['-pPASSWORD']);

    for my $sha (keys %$name_of) {
        # destination/$sha.dat exists for the files which are not archives
        print "$sha: $name_of->{$sha}{name}\n";
    }

=head1 DESCRIPTION

Unpack::Custom::Recursive takes any kind of archive 7-Zip can read and
extracts it. If it contains an archive, it is extracted too, and so on,
until only files which are not archives are left. It is built on
L<Unpack::Custom>.

Every file is stored in the destination directory as C<< <sha256>.dat >>,
where C<< <sha256> >> is the SHA-256 of its content (in hex), so each
content is stored only once, however many times it occurs. This is useful
e.g. for scanning all the files in a set of archives.

For example, for C<photos.zip> containing C<inner.7z> (which contains
C<META.json>) and C<docs/LICENSE>, the destination contains:

    1106089c….dat     # the content of LICENSE
    4b9f4152….dat     # the content of META.json
    names.txt

=over

=item *

The input files are copied to the destination first; the originals are
never modified or deleted.

=item *

An archive is deleted from the destination once at least one file was
extracted from it, so only the files which are not archives (and the
archives which could not be extracted) are left.

=item *

Files which 7-Zip reports as corrupted are deleted, with a warning.

=item *

Nested encrypted archives are extracted with the same passwords (C<-p>
switches) as the input. An archive which can't be extracted (e.g. because
of a wrong password) is kept as it is.

=item *

The same content is processed only once, so an archive which contains
itself (a "quine") does not cause an endless loop.

=back

=head2 names.txt

C<names.txt> in the destination has one line per content: the SHA-256, a
tab and the path of the file, starting with the input file name and going
through all the archives it is nested in:

    1106089c…	photos.zip/docs/LICENSE
    4b9f4152…	photos.zip/inner.7z/META.json
    8fcdd5b3…	photos.zip/inner.7z
    a2e5f3d2…	photos.zip

The archives themselves are listed too (they were deleted from the
destination). The lines are sorted by the SHA-256. Backslash, tab, newline
and carriage return in names are escaped as C<\\>, C<\t>, C<\n> and C<\r>.
When the same content occurs several times, only the first name seen is
used.

=head1 METHODS

=head2 new(\%args)

Takes the optional arguments of L<Unpack::Custom/new> and these options:

=over

=item no_recursive

Do not extract archives found inside the input archives.

=item max_depth

Do not extract archives nested deeper than this. The input files have
depth 0, the files in them depth 1 and so on, so C<< max_depth => 0 >>
extracts only the input archives.

=item max_extracted_size

Stop writing new files when the total size of the extracted files would
exceed this number of bytes; the skipped files are reported by a warning.
Use it together with C<max_depth> as a protection against zip bombs.

=back

Any of the L<callbacks|Unpack::Custom/CALLBACKS> can be overridden too.

=head2 extract(\@files, $destination, \@sevenzip_params)

Extracts the files, see L<Unpack::Custom/extract>, writes C<names.txt>
and returns a HASH reference keyed by the SHA-256 of every file, archive
and input file:

    {
        '4b9f4152…' => {
            name    => 'META.json',   # name in the parent archive
            sha     => '4b9f4152…',
            parent  => '8fcdd5b3…',   # SHA-256 of the parent, '' for an input file
            parents => [              # the file itself and all its ancestors
                '4b9f4152…',          # META.json
                '8fcdd5b3…',          # inner.7z
                'a2e5f3d2…',          # photos.zip
            ],
        },
        ...
    }

The files in C<$destination> from previous runs are kept; content already
present there is not written again.

=head1 LIMITATIONS

See L<Unpack::Custom/LIMITATIONS>: each extracted file is kept in memory
while it is being saved.

=head1 SEE ALSO

L<Unpack::Custom>, L<Unpack::Custom::Ordinary>, L<Unpack::SevenZip>

=head1 LICENSE

Copyright (C) Týnovský Miroslav.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Týnovský Miroslav E<lt>tynovsky@seznam.czE<gt>

=cut
