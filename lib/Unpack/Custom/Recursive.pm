package Unpack::Custom::Recursive;

use v5.16;
use strict;
use warnings;
use Data::Dumper;

use File::Path qw(make_path);
use Digest::SHA qw(sha256_hex);
use Unpack::Custom;
use Clone qw(clone);
use File::Copy;

our $VERSION = "0.01";

our %callbacks = (
    initialize => sub {
        my ($self) = @_;

        make_path($self->{var}{destination});
        my $name_of = $self->{var}{name_of} = {};
        for my $file (@{ $self->{var}{files} }) {
            my $sha = file_sha($file);
            copy "$file", "$self->{var}{destination}/$sha.dat" #TODO: expensive copy
                or die "copy failed: $!";
            $name_of->{$sha} = { name => $file, parent => '', sha => $sha };
            $file = "$self->{var}{destination}/$sha.dat";
        }
    },

    finalize => sub {
        my ($self) = @_;

        my $name_of = $self->{var}{name_of};

        for my $value (values %$name_of) {
            my @parents = ($value->{sha});
            $value->{parents} = \@parents;
            my $item = clone($value);
            while ($item = clone($name_of->{ $item->{parent} })) {
                last if grep $_ eq $item->{sha}, @parents;
                push @parents, $item->{sha};
            }
        }

        open my $fh, '>', "$self->{var}{destination}/names.txt";
        while (my ($key, $value) = each %$name_of) {
            my $fullname = join '/', map {
                    $name_of->{$_}->{name}
                } reverse @{$value->{parents}};
            print {$fh} "$key\t$fullname\n";
        }
        close $fh;

        return $name_of;
    },

    before_unpack => sub {
        my ($self, $file) = @_;

        $self->{var}{names} = [];
        my ($list, $info) = $self->{szip}->info($file);
        my $params = $self->{sevenzip_params};
        if ($info->{multivolume} && $info->{multivolume} eq '+') {
            my $last_file = pop @$list;
            push @$params, "-x!$last_file->{path}";
            if ($info->{characteristics} !~ /FirstVolume/) {
                my $first_file = shift @$list;
                push @$params, "-x!$first_file->{path}";
            }
        }
        $self->{var}{list} = $list;
        # print STDERR Dumper $list;
    },

    after_unpack => sub {
        my ($self, $file, $extracted_files, $corrupted_paths) = @_;

        my $parent_sha = file_sha($file);
        $self->{var}{already_unpacked}{$parent_sha} = 1;
        my $name_of = $self->{var}{name_of};
        for my $file (@{ $self->{var}{names} }) {
            if (grep $file->{name} eq $_, @$corrupted_paths) {
                print STDERR "deleting corrupted ", Dumper $file;
                unlink "$self->{var}{destination}/$file->{sha}.dat";
            }
            else {
                $name_of->{$file->{sha}} = { name   => $file->{name},
                                             parent => $parent_sha,
                                             sha    => $file->{sha}    };

                # recursive unpack: put newly extracted files to the queue
                if (! $self->{var}{already_unpacked}{$file->{sha}}
                    && ! $self->{no_recursive}
                ) {
                    my $filename = "$self->{var}{destination}/$file->{sha}.dat";
                    # say STDERR "pushing $filename to queue";
                    push @{ $self->{var}{files} }, $filename;
                }
            }
        }

        if (@$extracted_files) {
            unlink $file; #was an archive, now it is extracted, delete it
        }
    },

    want_unpack => sub {
        my ($self, $file) = @_;
        my ($list) = $self->{szip}->info($file);
        return @$list > 0;
    },

    save => sub {
        my ($self, $contents, $file) = @_;

        my $sha = sha256_hex($contents);

        if ( grep {$_->{sha} eq $sha} @{ $self->{var}{names} } ) {
            print STDERR "Skipping $file->{path}, seen before\n";
            return
        }

        my $filename = "$self->{var}{destination}/$sha.dat";
        open my $fh, '>:bytes', $filename;
        print {$fh} $contents;
        close $fh;
        # say STDERR "Saved $file->{path} to $filename";

        push @{ $self->{var}{names} }, {
            sha => $sha,
            name => $file->{path},
        };
        close $fh;

        return $filename
    }
);

sub new {
    my ($class, $args) = @_;

    $args = { %callbacks, %{ $args // {} }};
    $args->{_unpack_custom} = 'Unpack::Custom'->new($args);

    return bless $args, $class;
}

sub extract {
    my $self = shift;
    $self->{_unpack_custom}->extract(@_);
}

sub file_sha {
    my ($filename) = @_;

    # say STDERR "compute sha: $filename";
    state $sha_obj = 'Digest::SHA'->new(256);
    $sha_obj->addfile($filename, 'b');
    return $sha_obj->hexdigest();
}

1;
__END__

=encoding utf-8

=head1 NAME

Unpack::Custom::Recursive - It's new $module

=head1 SYNOPSIS

    use Unpack::Custom::Recursive;

=head1 DESCRIPTION

Unpack::Custom::Recursive takes any kind of archive (restricted to what 7zip
can extract) and unpacks it. If it contains an archive, it is unpacked
(recursively) too.

=head1 LICENSE

Copyright (C) Týnovský Miroslav.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Týnovský Miroslav E<lt>tynovsky@avast.comE<gt>

=cut

