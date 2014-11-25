package Unpack::Recursive;
use v5.16;
use strict;
use warnings;
use IPC::Open3;
use Symbol 'gensym';

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

sub szip_list {
	my ($self, $filename) = @_;
	my ($pid, $out) = $self->run_7zip('l', $filename, ['-slt']);

	my $seen_header = 0;
	my @files;
	my $file;
	while (my $line = <$out>) {
		if (not $seen_header) {
			$seen_header = $line =~ /^----------$/;
			next
		}
		
		if ($line =~ /^$/) {
			push @files, $file;
			$file = {};
		}
		my ($key, $value) = $line =~ /(.*?) = (.*)/;
		if (grep $_ eq lc($key), qw(path size)) {
			$file->{lc $key} = $value;
		}
	}
	
	return \@files;
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

