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

=head1 NAME

Unpack::Custom::Recursive - extract archives recursively, deduplicated by content

=head1 SYNOPSIS

    use Unpack::Custom::Recursive;

    my $unpacker = Unpack::Custom::Recursive->new({
        max_depth          => 10,         # optional
        max_extracted_size => 2 ** 30,    # optional, in bytes
    });
    my $name_of = $unpacker->extract(['archive.zip'], 'destination');

=head1 DESCRIPTION

Unpack::Custom::Recursive takes any kind of archive (restricted to what 7zip
can extract) and unpacks it. If it contains an archive, it is unpacked
(recursively) too.

Every file is stored in the destination directory as C<< <sha256>.dat >>,
so each content is stored only once. Archives which were successfully
unpacked are deleted from the destination (the input files themselves are
copied to the destination first and never touched). The file
C<names.txt> in the destination contains one line per content:

    <sha256> TAB <input>/<archive>/.../<file>

Backslash, tab, newline and carriage return in names are escaped as
C<\\>, C<\t>, C<\n> and C<\r>. When the same content appears several times,
the first name seen is used.

C<extract> returns a HASH reference keyed by sha256 with the name, the
parent sha256 and the list of all ancestors of every file.

=head1 OPTIONS

=over

=item no_recursive

Do not unpack archives found inside the input archives.

=item max_depth

Do not unpack archives nested deeper than this (inputs have depth 0, their
content depth 1, ...).

=item max_extracted_size

Stop writing new files when the total size of the extracted files would
exceed this number of bytes. Note that L<Unpack::SevenZip> keeps each
extracted file in memory while it is being saved.

=back

Any of the callbacks of L<Unpack::Custom> can be overridden too.

=head1 LICENSE

Copyright (C) Týnovský Miroslav.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Týnovský Miroslav E<lt>tynovsky@seznam.czE<gt>

=cut
