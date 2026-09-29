package Unpack::Custom::Ordinary;

use strict;
use warnings;

use Carp;
use File::Path qw(make_path);
use Path::Tiny;
use Unpack::Custom;

our $VERSION = "0.3.0";

our %callbacks = (
    initialize => sub {
        my ($self) = @_;

        make_path($self->{var}{destination});
    },

    finalize      => sub { },
    before_unpack => sub { },
    after_unpack  => sub { },

    want_unpack => sub {
        my ($self, $file) = @_;

        my ($list) = $self->{szip}->info($file, $self->password_params);
        $self->{var}{list} = $list;

        return @$list > 0;
    },

    save => sub {
        my ($self, $contents, $file) = @_;

        return if ! $file || ! defined $file->{path};

        my @parts = safe_path_parts($file->{path});
        if (! @parts) {
            Carp::carp("Skipping unsafe path '$file->{path}'");
            return;
        }

        my $filename = path($self->{var}{destination})->child(@parts);
        $filename->parent->mkpath();
        open my $fh, '>:raw', "$filename"
            or die "Cannot write '$filename': $!";
        print {$fh} $contents
            or die "Cannot write '$filename': $!";
        close $fh
            or die "Cannot write '$filename': $!";

        return "$filename";
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

# Split a path from an archive into components that are safe to append to
# the destination directory. Leading slashes, drive letters and '.' components
# are dropped; paths containing '..' are rejected (empty list returned).
sub safe_path_parts {
    my ($path) = @_;

    $path =~ s{^[A-Za-z]:}{};
    my @parts = grep { $_ ne '' && $_ ne '.' } split m{[/\\]+}, $path;

    return if grep { $_ eq '..' } @parts;
    return @parts;
}

1;
__END__

=encoding utf-8

=head1 NAME

Unpack::Custom::Ordinary - extract archives into a directory, like C<7z x>

=head1 SYNOPSIS

    use Unpack::Custom::Ordinary;

    my $unpacker = Unpack::Custom::Ordinary->new();
    $unpacker->extract(['archive.7z', 'other.zip'], 'destination');

    # encrypted archives
    $unpacker->extract(['secret.7z'], 'destination', ['-pPASSWORD']);

=head1 DESCRIPTION

Unpack::Custom::Ordinary takes any kind of archive 7-Zip can read and
extracts it into a directory tree below the destination, the same way as
C<7z x> does. Hence the name 'Ordinary'. It is the simplest unpacker built
on L<Unpack::Custom>.

=over

=item *

The destination directory is created when it does not exist.

=item *

All archives are extracted into the same destination; existing files are
overwritten.

=item *

Archives inside the archives are not extracted (use
L<Unpack::Custom::Recursive> for that).

=item *

Files which are not archives are skipped.

=item *

Paths inside the archive are always extracted below the destination:
absolute paths are made relative and entries containing C<..> are skipped
with a warning.

=back

=head1 METHODS

=head2 new(\%args)

Takes the optional arguments of L<Unpack::Custom/new>. Any of the
L<callbacks|Unpack::Custom/CALLBACKS> can be overridden too, e.g. to
extract only some files:

    my $unpacker = Unpack::Custom::Ordinary->new({
        save => sub {
            my ($self, $contents, $file) = @_;
            return if $file->{path} !~ /\.txt$/;
            return $Unpack::Custom::Ordinary::callbacks{save}->(@_);
        },
    });

=head2 extract(\@archives, $destination, \@sevenzip_params)

Extracts the archives, see L<Unpack::Custom/extract>. Returns nothing.

=head1 SEE ALSO

L<Unpack::Custom>, L<Unpack::Custom::Recursive>

=head1 LICENSE

Copyright (C) Týnovský Miroslav.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Týnovský Miroslav E<lt>tynovsky@seznam.czE<gt>

=cut
