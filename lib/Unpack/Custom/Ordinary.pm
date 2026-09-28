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

Unpack::Custom::Ordinary - extract archives the same way as C<7z x>

=head1 SYNOPSIS

    use Unpack::Custom::Ordinary;

    my $unpacker = Unpack::Custom::Ordinary->new();
    $unpacker->extract(['archive.7z'], 'destination', ['-pPASSWORD']);

=head1 DESCRIPTION

Unpack::Custom::Ordinary takes any kind of archive (restricted to what 7zip
can extract) and unpacks it. It unpacks it into the very same result as
7z x would do. Hence the name 'Ordinary'.

Paths inside the archive are always extracted below the destination
directory: absolute paths are made relative and entries containing C<..>
are skipped with a warning.

Any of the callbacks of L<Unpack::Custom> can be overridden by passing it
to C<new>:

    my $unpacker = Unpack::Custom::Ordinary->new({
        save => sub { my ($self, $contents, $file) = @_; ... },
    });

=head1 LICENSE

Copyright (C) Týnovský Miroslav.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Týnovský Miroslav E<lt>tynovsky@avast.comE<gt>

=cut
