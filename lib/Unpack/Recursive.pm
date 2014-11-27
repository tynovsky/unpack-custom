package Unpack::Recursive;

use v5.16;
use strict;
use warnings;
use Data::Dumper;

use IPC::Open3;
use File::Basename;
use File::Path qw(make_path);
use Digest::SHA qw(sha256_hex);
use IO::Handle;

our $VERSION = "0.01";

my $sevenzip = '/home/tynovsky/p7zip_9.20.1/bin/7z';

sub new {
    my ($class, $args) = @_;
    $args //= {};

    return bless $args, $class;
}

sub run_7zip {
    my ($self, $command, $archive_name, $switches, $files, $stdin) = @_;
    $_ //= [] for $switches, $files;
    $_ //= '' for $command, $archive_name;

    my ($out, $err) = (IO::Handle->new, IO::Handle->new);
    my $cmd = "$sevenzip $command @$switches '$archive_name' @$files";
    #print STDERR "$cmd\n";
    my $pid = open3 $stdin, $out, $err, $cmd;

    return ($pid, $out, $err)
}

sub info {
    my ($self, $filename) = @_;
    my ($pid, $out) = $self->run_7zip('l', $filename, ['-slt']);

    my ($file_list_started, $info_started, @files, $file, $info);
    while (my $line = <$out>) {
        $file_list_started ||= $line =~ /^----------$/;
        $info_started      ||= $line =~ /^--$/;
        next if $line =~ /^-+$/;

        if ($file_list_started) {
            if ($line =~ /^$/) { # empty lines separate the files
                push @files, $file;
                $file = {};
                next
            }
            my ($key, $value) = $line =~ /(.*?) = (.*)/;
            if (grep $_ eq lc($key), qw(path size)) {
                $file->{lc $key} = $value;
            }
        }
        elsif ($info_started) {
            if( my ($key, $value) = $line =~ /(.*?) = (.*)/ ) {
                $info->{lc $key} = $value;
            }
        }
        else {
            next
        }
    }

    return (\@files, $info);
}

sub extract_sha {
    my ($self, $filename, $destination) = @_;

    #initialize
    my $parent_sha = $self->file_sha($filename);
    make_path($destination);
    my @names = ({sha => $parent_sha, parent => '', name => $filename});
    my ($list, $info) = $self->info($filename);
    my @params;
    if ($info->{multivolume} && $info->{multivolume} eq '+') {
        my $last_file = pop @$list;
        push @params, "-x!$last_file->{path}";
        if ($info->{characteristics} !~ /FirstVolume/) {
            my $first_file = shift @$list;
            push @params, "-x!$first_file->{path}";
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
        my ($list) = $self->info($file);
        return @$list > 0;
    };

    #run general extract method
    my $extracted_files = $self->extract(
        $filename, $want_extract, $save, \@params, $list
    );

    #finalize
    open my $names_fh, '>>', "$destination/names.txt";
    print {$names_fh} "$_->{sha}\t$_->{parent}\t$_->{name}\n" for @names;
    close $names_fh;

    return $extracted_files;
}

sub extract {
    my ($self, $filename, $want_extract, $save, $params, $list) = @_;

    return [] if ! $want_extract->($filename);

    $list   //= ($self->info($filename))[0];
    $params //= [];
    push @$params, '-so';

    my ($pid, $out, $err) = $self->run_7zip('x', $filename, $params);
    return $self->process_7zip_out( $out, $err, $list, $save);
}

sub process_7zip_out {
    my ($self, $out, $err, $list, $save_fn) = @_;

    my $success = 0;
    my $szip_out;
    my $reader = IO::Select->new($err, $out);

    my $file = shift @$list;
    my $contents;
    my @extracted_files;
    while ( my @ready = $reader->can_read() ) {
        foreach my $fh (@ready) {
            if (defined fileno($out) && fileno($fh) == fileno($out)) {
                use bytes;
                my $read_anything = 0;
                my $data;
                while (my $read_bytes = $fh->read($data, 4096)) {
                    $contents .= $data;
                    if (length($contents) >= $file->{size}) {
                        push @extracted_files, $save_fn->(
                            substr($contents, 0, $file->{size}),
                            $file,
                        );
                        $contents = substr($contents, $file->{size});
                        $file = shift @$list;
                    }
                    $read_anything = 1;
                }
                if (!$read_anything) {
                    $reader->remove($fh);
                    $fh->close();
                    next
                }
            }
            elsif (defined fileno($err) && fileno($fh) == fileno($err)) {
                my $line = <$fh>;
                if (!defined $line) {
                    $reader->remove($fh);
                    $fh->close();
                    next
                }
                $success = 1 if $line =~ /^Everything is Ok/;
                $szip_out .= $line;
            }
        }
    }
    if ($contents) {
        push @extracted_files, $save_fn->($contents, $file);
    }

    if (! $success ) {
        print STDERR $szip_out;
        die "7zip failed to extract.\n";
    }

    return \@extracted_files;
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

