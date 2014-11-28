package Unpack::Recursive;

use v5.16;
use strict;
use warnings;
use Data::Dumper;

use File::Path qw(make_path);
use Digest::SHA qw(sha256_hex);
use Unpack::SevenZip;

our $VERSION = "0.01";

sub new {
    my ($class, $args) = @_;
    $args //= {};

    $args->{szip} = 'Unpack::SevenZip'->new();
    return bless $args, $class;
}

sub extract_recursive_sha {
    my ($self, $files, $delete_archives, $destination, $params) = @_;

    make_path($destination);
    open my $names_fh, '>>', "$destination/names.txt"
        or die "Could not open $destination/names.txt: $!";
    print {$names_fh} $self->file_sha($_), "\t\t$_\n" for @$files;
    close $names_fh;

    while (my $f = shift @$files) {
        my $extracted = $self->extract_sha($f, $destination);
        if (@$extracted && $delete_archives) {
            unlink $f; #was archive, now it is extracted, delete it
        }
        push @$files, @$extracted;
    }
}

sub extract_sha {
    my ($self, $filename, $destination, $params) = @_;

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
    my $want_extract = sub {
        my ($file) = @_;
        my ($list) = $self->{szip}->info($file);
        return @$list > 0;
    };

    #run general extract method
    my ($extracted_files, $corrupted_paths) = $self->{szip}->extract(
        $filename, $want_extract, $save, $params, $list
    );

    #finalize - remove corrupted files and store names
    my @names_ok;
    for my $file (@names) {
        if (grep $file->{name} eq $_, @$corrupted_paths) {
            print STDERR "deleting corrupted ", Dumper $file;
            unlink "$destination/$file->{sha}.dat";
        }
        else {
            push @names_ok, $file;
        }
    }
    open my $names_fh, '>>', "$destination/names.txt";
    print {$names_fh} "$_->{sha}\t$_->{parent}\t$_->{name}\n" for @names_ok;
    close $names_fh;

    return $extracted_files;
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

