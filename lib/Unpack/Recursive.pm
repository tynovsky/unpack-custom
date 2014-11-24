package Unpack::Recursive;
use v5.16;
use strict;
use warnings;

our $VERSION = "0.01";

my $sevenzip = '7za';

sub new {
	my ($class, $args) = @_;
	$args //= {};
	
	return bless $args, $class;
}

sub run_7zip {
	my ($self, $command, $switches, $archive_name, $files) = @_;
	$_ //= [] for $switches, $files;
	$_ //= '' for $command, $archive_name;

	my $cmd = "$sevenzip $command @$switches $archive_name @$files";
	say STDERR $cmd;

	open my $output, '|-' , $cmd;

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

