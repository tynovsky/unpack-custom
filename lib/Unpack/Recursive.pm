package Unpack::Recursive;
use v5.16;
use strict;
use warnings;
use IPC::Open3;
use Symbol 'gensym';
use Data::Dumper;
use File::Basename;
use File::Path qw(make_path);
use Digest::SHA qw(sha256_hex);

use IO::Pty;

our $VERSION = "0.01";

my $sevenzip = '7z';

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
    my $cmd = "$sevenzip $command @$switches $archive_name @$files";
    my $pid = open3 $stdin, $out, $err, $cmd;

    return ($pid, $out, $err)
}

sub list {
    my ($self, $filename) = @_;
    my ($pid, $out) = $self->run_7zip('l', $filename, ['-slt']);

    my ($seen_header, @files, $file);
    while (my $line = <$out>) {
        if (not $seen_header) {
            $seen_header = $line =~ /^----------$/;
            next
        }
        if ($line =~ /^$/) {
            push @files, $file;
            $file = {};
            next
        }
        my ($key, $value) = $line =~ /(.*?) = (.*)/;
        if (grep $_ eq lc($key), qw(path size)) {
            $file->{lc $key} = $value;
        }
    }

    return \@files;
}

#TODO: split!
sub extract {
    my ($self, $filename, $destination) = @_;
    use bytes;

    my $list = $self->list($filename);
    my ($pid, $out, $err) = $self->run_7zip('x', $filename, ['-so'] );

    my $success = 0;
    my $err_log;
    my $reader = IO::Select->new($err, $out);

    my $file = shift @$list;
    my $contents;
    while ( my @ready = $reader->can_read() ) {
        foreach my $fh (@ready) {
            if (defined fileno($out) && fileno($fh) == fileno($out)) {
                my $read_anything = 0;
                my $data;
                while (my $read_bytes = $fh->read($data, 4096)) {
                    $contents .= $data;
                    if (length($contents) >= $file->{size}) {
                        $self->save(
                            substr($contents, 0, $file->{size}),
                            $file,
                            $destination,
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
                $err_log .= $line;
            }
        }
    }
    no bytes;
    waitpid(0, $pid);

    return ($success, $err_log);
}

sub save_normal {
    my ($self, $contents, $file, $destination) = @_;
    use bytes;

    make_path($destination . '/' . dirname($file->{path}));
    open my $fh, '>', $destination . '/' . $file->{path};
    print {$fh} $contents;
    close $fh;

    no bytes;
}

sub save {
    my ($self, $contents, $file, $destination) = @_;
    use bytes;

    make_path($destination);
    my $sha = sha256_hex($contents);
    open my $fh, '>', "$destination/$sha.dat";
    print {$fh} $contents;
    close $fh;

    open $fh, '>>', "$destination/names.txt";
    print {$fh} "$sha\t$file->{path}\n";
    close $fh;

    no bytes;
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

