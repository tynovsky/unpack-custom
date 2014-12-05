package Unpack::Recursive;

use v5.16;
use strict;
use warnings;
use Data::Dumper;

use File::Path qw(make_path);
use Digest::SHA qw(sha256_hex);
use Unpack::SevenZip;
use Clone qw(clone);
use File::Copy;

our $VERSION = "0.01";

sub new {
    my ($class, $args) = @_;
    $args //= {};

    $args->{szip} = 'Unpack::SevenZip'->new();
    return bless $args, $class;
}

sub extract_recursive_sha {
    my ($self,
        $files,
        $delete_archives,
        $destination,
        $params,
        $want_extract) = @_;

    make_path($destination);

    my %name_of;
    for my $file (@$files) {
        my $sha = $self->file_sha($file);
        copy "$file", "$destination/$sha.dat" or die "copy failed: $!";
        $name_of{$sha} = { name => $file, parent => '', sha => $sha };
    }

    while (my $f = shift @$files) {
        my $extracted = $self->extract_sha(
            $f, $destination, undef, $want_extract
        );
        if (keys %$extracted && $delete_archives) {
            unlink $f; #was archive, now it is extracted, delete it
        }
        for my $sha (keys %$extracted) {
            if (! $name_of{$sha} ) {
                # say STDERR $sha;
                push @$files, "$destination/$sha.dat";
            }
        }
        %name_of = (%name_of, %$extracted);
    }
    for my $value (values %name_of) {
        my @parents = ($value->{sha});
        $value->{parents} = \@parents;
        my $item = clone($value);
        while ($item = clone($name_of{ $item->{parent} })) {
            last if grep $_ eq $item->{sha}, @parents;
            push @parents, $item->{sha};
        }
    }

    open my $fh, '>', "$destination/names.txt";
    while (my ($key, $value) = each %name_of) {
        my $fullname = join '/', map {
                $name_of{$_}->{name}
            } reverse @{$value->{parents}};
        print {$fh} "$key\t$fullname\n";
    }
    close $fh;

    return \%name_of;
}

sub extract_sha {
    my ($self, $filename, $destination, $params, $want_extract) = @_;

    #initialize
    my $parent_sha = $self->file_sha($filename);
    make_path($destination);
    my @names;
    my ($list, $info) = $self->{szip}->info($filename);
    $params //= [];
    if ($info->{multivolume} && $info->{multivolume} eq '+') {
        my $last_file = pop @$list;
        push @$params, "-x!$last_file->{path}";
        if ($info->{characteristics} !~ /FirstVolume/) {
            my $first_file = shift @$list;
            push @$params, "-x!$first_file->{path}";
        }
    }

    # define function for saving extracted files
    my $save = sub {
        my ($contents, $file) = @_;

        my $sha = sha256_hex($contents);

        if ( grep {$_->{sha} eq $sha} @names ) {
            print STDERR "Skipping $file->{path}, seen before\n";
            return
        }

        my $filename = "$destination/$sha.dat";
        open my $fh, '>:bytes', $filename;
        print {$fh} $contents;
        close $fh;

        push @names, {
            sha => $sha,
            parent => $parent_sha,
            name => $file->{path},
        };
        close $fh;

        return $filename
    };

    # define function for recognizing archives
    $want_extract //= sub {
        my ($file) = @_;
        my ($list) = $self->{szip}->info($file);
        return @$list > 0;
    };

    #run general extract method
    my ($extracted_files, $corrupted_paths) = $self->{szip}->extract(
        $filename, $want_extract, $save, $params, $list
    );

    #finalize - remove corrupted files and store names
    my %name_of;
    for my $file (@names) {
        if (grep $file->{name} eq $_, @$corrupted_paths) {
            print STDERR "deleting corrupted ", Dumper $file;
            unlink "$destination/$file->{sha}.dat";
        }
        else {
            $name_of{$file->{sha}} = { name   => $file->{name},
                                       parent => $file->{parent},
                                       sha    => $file->{sha}    };
        }
    }

    return \%name_of;
}

sub file_sha {
    my ($self, $filename) = @_;

    state $sha_obj = 'Digest::SHA'->new(256);
    $sha_obj->addfile($filename, 'b');
    return $sha_obj->hexdigest();
}

1;
__END__

=encoding utf-8

=head1 NAME

Unpack::Recursive - It's new $module

=head1 SYNOPSIS

    use Unpack::Recursive;

=head1 DESCRIPTION

Unpack::Recursive takes any kind of archive and unpacks it. If it contains an
archive, it is unpacked (recursively) too.

=head1 LICENSE

Copyright (C) Týnovský Miroslav.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Týnovský Miroslav E<lt>tynovsky@avast.comE<gt>

=cut

