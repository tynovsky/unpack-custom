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

=for stopwords rar xz iso sevenzip

=head1 NAME

Unpack::Custom - extract archives with 7-Zip using user-defined callbacks

=head1 SYNOPSIS

    use Unpack::Custom;

    # total size of the files in the archives by extension, nothing is
    # written to the disk
    my %size_of;
    my $unpacker = Unpack::Custom->new(
        initialize    => sub { %size_of = () },
        want_unpack   => sub {
            my ($self, $file) = @_;
            return $file =~ /\.(?:zip|7z|tar)$/;
        },
        before_unpack => sub { },
        save          => sub {
            my ($self, $contents, $file) = @_;
            my ($extension) = $file->{path} =~ /\.(\w+)$/;
            $size_of{ lc($extension // '') } += length $contents;
            return $file->{path};
        },
        after_unpack  => sub {
            my ($self, $archive, $extracted, $corrupted) = @_;
            warn "$archive: corrupted @$corrupted\n" if @$corrupted;
        },
        finalize      => sub { return { %size_of } },
    );

    my $size_of = $unpacker->extract(['a.zip', 'b.7z'], 'unused');

=head1 DESCRIPTION

Unpack::Custom extracts archives of any format 7-Zip can read (zip, 7z,
rar, tar, gzip, bzip2, xz, iso, cab, but also e.g. executables, see
L</REQUIREMENTS>) and lets
you decide what happens with the extracted files. The files are extracted
into memory and handed to your C<save> callback; nothing is written to the
disk unless the callback does it.

C<extract> processes a queue of files. For each file it asks C<want_unpack>
whether to extract it, then calls C<before_unpack>, C<save> for every file
in the archive and C<after_unpack>. Callbacks may add files to the queue,
which is how L<Unpack::Custom::Recursive> extracts nested archives.

Two ready-made unpackers are built on this module:

=over

=item L<Unpack::Custom::Ordinary>

extracts archives into a directory tree, like C<7z x>

=item L<Unpack::Custom::Recursive>

extracts archives recursively (archives in archives) into files named by
the SHA-256 of their content, so each content is stored once

=back

=head1 CALLBACKS

All six callbacks are required (use C<sub { }> for the ones you don't
need). Each callback gets the unpacker object as its first argument; any
other arguments given to C<new> (e.g. your own options) are available in it
as C<< $self->{name} >>. An exception thrown by a callback stops C<extract>
and is propagated to its caller.

=head2 initialize($self)

Called once at the start of C<extract>, after the state of the run
(L</"THE STATE OF A RUN">) is set up. It may change the queue in
C<< $self->{var}{files} >>, e.g. copy the input files somewhere.

=head2 want_unpack($self, $file)

Called for each file taken from the queue. Return true to extract the
file; if it returns false, the file is skipped and no other callback is
called for it. A typical implementation asks 7-Zip whether the file is an
archive; it may store the listing in C<< $self->{var}{list} >>, so the
archive is not listed twice:

    want_unpack => sub {
        my ($self, $file) = @_;
        my ($list) = $self->{szip}->info($file, $self->password_params);
        $self->{var}{list} = $list;
        return @$list > 0;
    },

=head2 before_unpack($self, $file)

Called before the file is extracted. It may set C<< $self->{var}{list} >>
(see L</"THE STATE OF A RUN">) and add switches for this file only to
C<< $self->{var}{extra_params} >>.

=head2 save($self, $contents, $file)

Called for each file extracted from the archive (directories are skipped).
C<$contents> is the whole content of the file as a byte string, C<$file> is
a HASH reference with the keys C<path> (the path inside the archive) and
C<size> (missing when 7-Zip does not know it, e.g. for C<bzip2>). Return
a value describing the saved file (e.g. its new name); the values are
passed to C<after_unpack>. Return an empty list for a file you don't want
to count as extracted.

=head2 after_unpack($self, $file, \@extracted, \@corrupted)

Called after the file was extracted. C<@extracted> are the values returned
by C<save>, C<@corrupted> are the paths (inside the archive) of the files
7-Zip reported as corrupted (CRC error, data error, wrong password, ...);
their content may already have been passed to C<save>. Push files to
C<< $self->{var}{files} >> to process them too.

=head2 finalize($self)

Called once at the end. Its return value is the return value of
C<extract>.

=head1 METHODS

=head2 new(%args) or new(\%args)

Takes the six callbacks and these optional arguments:

=over

=item sevenzip_params

Default ARRAY reference of switches passed to 7-Zip, e.g.
C<['-pPASSWORD']>. All C<-p> switches are tried as passwords (and the
empty password), see L<Unpack::SevenZip/extract>.

=item sevenzip

Path to the 7-Zip binary (default C<7z>).

=back

Dies if a callback is missing or if the 7-Zip binary can't be run.

=head2 extract(\@files, $destination, \@sevenzip_params)

Processes the queue of C<@files> and returns whatever C<finalize> returns.
C<$destination> is required, but used only by the callbacks. The optional
C<@sevenzip_params> are used instead of the ones given to C<new> for this
call only. Neither C<@files> nor C<@sevenzip_params> are modified.

Dies if C<@files> is not an ARRAY reference, if a file does not exist or
if C<$destination> is missing.

=head2 password_params

Returns an ARRAY reference with the first password switch (C<-p...>) of the
current run, or an empty ARRAY reference. Use it to list encrypted
archives: C<< $self->{szip}->info($file, $self->password_params) >>.

=head2 $self->{szip}

The L<Unpack::SevenZip> object, use it to list archives in the callbacks.

=head1 THE STATE OF A RUN

C<< $self->{var} >> is a HASH reference reset at the start of each
C<extract> call. Callbacks may keep their own data in it too.

=over

=item files

The queue of files to process. Callbacks may push more files to it.

=item destination

The destination given to C<extract>.

=item sevenzip_params

The 7-Zip switches used for this run.

=item list

Reset before each file. When C<want_unpack> or C<before_unpack> sets it to
the list of files in the archive (as returned by
L<Unpack::SevenZip/info>), the archive is not listed again. The list is
used to split the output of 7-Zip into files, so it must contain exactly
the files 7-Zip extracts, in the same order (exclude the others with C<-x!>
switches in C<extra_params>).

=item extra_params

Reset to an empty ARRAY reference before each file. Additional 7-Zip
switches used only for the current file.

=back

=head1 REQUIREMENTS

The 7-Zip command line program C<7z>, e.g. the C<7zip> package (or the
older C<p7zip-full>) on Debian and Ubuntu; RAR archives need the C<7zip-rar>
package there. Use the C<sevenzip> argument when C<7z> is not in the
C<PATH>.

=head1 LIMITATIONS

Each extracted file is kept in memory while it is passed to C<save>, so
the largest file in an archive has to fit into memory.

=head1 SEE ALSO

L<Unpack::Custom::Ordinary>, L<Unpack::Custom::Recursive>,
L<Unpack::SevenZip>

=head1 LICENSE

Copyright (C) Týnovský Miroslav.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Týnovský Miroslav E<lt>tynovsky@seznam.czE<gt>

=cut
