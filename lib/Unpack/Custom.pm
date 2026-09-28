package Unpack::Custom;

use strict;
use warnings;

use Carp;
use Unpack::SevenZip 0.02; # runs 7z without a shell

our $VERSION = "0.3.0";

my @SUBS = qw(initialize finalize before_unpack after_unpack want_unpack save);

# generate a method for each callback: $self->save(@args) calls
# $self->{save}->($self, @args)
for my $sub (@SUBS) {
    no strict 'refs';
    *{$sub} = sub {
        my $self = shift;
        return $self->{$sub}->($self, @_);
    };
}

sub new {
    my $class = shift;

    my %args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;

    my $error = '';
    for my $param (@SUBS) {
        if (! $args{$param}) {
            $error .= "Missing required parameter $param\n";
        }
        elsif (ref $args{$param} ne 'CODE') {
            $error .= "Invalid parameter $param, expecting CODE\n";
        }
    }
    if (defined $args{sevenzip_params} && ref $args{sevenzip_params} ne 'ARRAY') {
        $error .= "Invalid parameter sevenzip_params, expecting ARRAY\n";
    }

    Carp::croak($error) if $error;

    $args{sevenzip_params} = [ @{ $args{sevenzip_params} // [] } ];
    $args{szip} = 'Unpack::SevenZip'->new(
        defined $args{sevenzip} ? { sevenzip => $args{sevenzip} } : ()
    );

    return bless \%args, $class;
}

sub extract {
    my ($self, $files, $destination, $sevenzip_params) = @_;

    Carp::croak('extract: first argument must be an ARRAY reference of files')
        if ref $files ne 'ARRAY';
    Carp::croak('extract: destination is required')
        if ! defined $destination || $destination eq '';
    Carp::croak('extract: sevenzip params must be an ARRAY reference')
        if defined $sevenzip_params && ref $sevenzip_params ne 'ARRAY';
    for my $file (@$files) {
        Carp::croak('extract: undefined file name') if ! defined $file;
        Carp::croak("extract: file '$file' does not exist or is not a file")
            if ! -f $file;
    }

    # fresh state for every run; work on copies so that neither the caller's
    # arrays nor the object defaults get modified
    $self->{var} = {
        files           => [ @$files ],
        destination     => $destination,
        sevenzip_params => [ @{ $sevenzip_params // $self->{sevenzip_params} } ],
    };

    $self->initialize();

    my $queue = $self->{var}{files};
    while (@$queue) {
        my $file = shift @$queue;

        # per-file state, callbacks may fill it in
        $self->{var}{list}         = undef;
        $self->{var}{extra_params} = [];

        next if ! $self->want_unpack($file);

        $self->before_unpack($file);
        my ($extracted_files, $corrupted_paths) = $self->{szip}->extract(
            $file,
            sub { $self->save(@_) },
            [ @{ $self->{var}{sevenzip_params} }, @{ $self->{var}{extra_params} } ],
            $self->{var}{list},
        );
        $self->after_unpack($file, $extracted_files // [], $corrupted_paths // []);
    }

    return $self->finalize();
}

# sevenzip params with password (-p) switches only; used for listing archives
sub password_params {
    my ($self) = @_;

    my ($password) = grep /^-p/, @{ $self->{var}{sevenzip_params} // [] };
    return defined $password ? [ $password ] : [];
}

1;
__END__

=encoding utf-8

=head1 NAME

Unpack::Custom - extract archives with 7-Zip using user-defined callbacks

=head1 SYNOPSIS

    use Unpack::Custom;

    my $unpacker = Unpack::Custom->new(
        initialize    => sub { my ($self) = @_; ... },
        want_unpack   => sub { my ($self, $file) = @_; return 1 },
        before_unpack => sub { my ($self, $file) = @_; ... },
        save          => sub {
            my ($self, $contents, $file_info) = @_;
            # $file_info->{path}, $file_info->{size}
            ...
            return $saved_filename;
        },
        after_unpack  => sub {
            my ($self, $file, $extracted_files, $corrupted_paths) = @_;
            ...
        },
        finalize      => sub { my ($self) = @_; return $result },

        sevenzip_params => ['-pPASSWORD'],   # optional
        sevenzip        => '/usr/bin/7z',    # optional, path to 7z binary
    );

    my $result = $unpacker->extract(\@archives, $destination, \@sevenzip_params);

=head1 DESCRIPTION

Unpack::Custom is a wrapper around L<Unpack::SevenZip> which allows user to
define callback functions implementing behavior during extracting an archive.
You can specify what to do before unpacking starts, before and after unpacking
a file, and after unpacking finishes. Moreover you can also specify how to
recognize if a file is an archive we want to unpack. This general module is
used in L<Unpack::Custom::Ordinary> and L<Unpack::Custom::Recursive>.

=head1 METHODS

=head2 new(%args) or new(\%args)

All six callbacks (C<initialize>, C<finalize>, C<before_unpack>,
C<after_unpack>, C<want_unpack>, C<save>) are required. Each callback gets the
unpacker object as its first argument. Optional arguments:

=over

=item sevenzip_params

Default ARRAY reference of switches passed to 7z (e.g. C<['-pPASSWORD']>).

=item sevenzip

Path to the 7z binary (default C<7z>).

=back

=head2 extract(\@files, $destination, \@sevenzip_params)

Processes the queue of C<@files> and returns whatever C<finalize> returns.
Neither C<@files> nor C<@sevenzip_params> are modified. The optional
C<@sevenzip_params> override the defaults given to C<new> for this call only.
Dies if any of the files does not exist.

The state of the current run is kept in C<< $self->{var} >> (which is reset
at the start of each C<extract> call) and callbacks may use it:

=over

=item files

The queue of files to process. Callbacks may push more files to it (this is
how recursive extraction works).

=item destination

The destination given to C<extract>.

=item sevenzip_params

The 7z switches used for this run.

=item list

Reset before each file. If C<want_unpack> or C<before_unpack> sets it to the
list of files in the archive (as returned by C<< $self->{szip}->info >>), the
archive does not have to be listed again.

=item extra_params

Reset to an empty ARRAY before each file. Additional 7z switches used only for
the current file.

=back

=head2 password_params

Returns an ARRAY reference with the first password switch (C<-p...>) of the
current run, or an empty ARRAY reference. Useful for listing archives with
C<< $self->{szip}->info($file, $self->password_params) >>.

=head1 LICENSE

Copyright (C) Týnovský Miroslav.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Týnovský Miroslav E<lt>tynovsky@seznam.czE<gt>

=cut
