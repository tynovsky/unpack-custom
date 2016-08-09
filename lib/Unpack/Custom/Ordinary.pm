package Unpack::Custom::Ordinary;

use strict;
use warnings;

use File::Path qw(make_path);
use Unpack::Custom;
use Clone qw(clone);
use File::Copy;
use Path::Tiny;

our %callbacks = (
    initialize    => sub { },
    finalize      => sub { },
    before_unpack => sub { },
    after_unpack  => sub { },

    want_unpack => sub {
        my ($self, $file) = @_;

        my ($list) = $self->{szip}->info($file);

        return @$list > 0;
    },

    save => sub {
        my ($self, $contents, $file) = @_;

        my $filename = path($self->{var}{destination})->child($file->{path});
        $filename->parent->mkpath();
        $filename->spew({binmode => ":raw"}, $contents);

        return $filename
    }
);

sub new {
    my ($class, $args) = @_;

    $args = { %callbacks, %{ $args // {} }};
    $args->{_unpack_custom} = 'Unpack::Custom'->new($args);

    return bless $args, $class;
}

sub extract {
    my $self = shift;
    $self->{_unpack_custom}->extract(@_);
}

1;
__END__

=encoding utf-8

=head1 NAME

Unpack::Custom::Ordinary - It's new $module

=head1 SYNOPSIS

    use Unpack::Custom::Ordinary;

=head1 DESCRIPTION

Unpack::Custom::Ordinary takes any kind of archive (restricted to what 7zip
can extract) and unpacks it. It unpacks it into the very same result as
7z x would do. Hence the name 'Ordinary'.

=head1 LICENSE

Copyright (C) Týnovský Miroslav.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Týnovský Miroslav E<lt>tynovsky@avast.comE<gt>

=cut


