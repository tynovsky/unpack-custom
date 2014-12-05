package Unpack::Custom;

use v5.16;
use strict;
use warnings;
use Data::Dumper;

use Carp;
use File::Path qw(make_path);
use Unpack::SevenZip;
use vars qw($AUTOLOAD);

our $VERSION = "0.01";

my @SUBS = qw(initialize finalize before_unpack after_unpack want_unpack save);

sub AUTOLOAD {
    my $self = shift;
    my $sub = $AUTOLOAD =~ s/.*:://r;
    if (grep $_ eq $sub, @SUBS) {
        return $self->{$sub}->($self, @_);
    }
}

use subs @SUBS;

sub new {
    my $class = shift;

    my %args = ref $_[0] eq 'HASH' ? %{ $_[0] } : @_;

    my $error = '';
    for my $param (@SUBS) {
        $error .= "Missing required parameter $param\n"
            if ! $args{$param};
        $error .= "Invalid parameter $param, expecting CODE\n"
            if ref $args{$param} ne 'CODE';
    }

    Carp::croak($error) if $error;

    $args{sevenzip_params} //= [];
    $args{szip} = 'Unpack::SevenZip'->new();

    return bless \%args, $class;
}

sub extract {
    my ($self, $files, $destination, $sevenzip_params) = @_;

    $self->{var}{files}       = $files;
    $self->{var}{destination} = $destination;

    $self->{sevenzip_params} = $sevenzip_params if $sevenzip_params;

    $self->initialize();

    while (my $file = shift @$files) {
        next if ! $self->want_unpack($file);

        # say STDERR "Working on $file";
        $self->before_unpack($file);
        my ($extracted_files, $corrupted_paths) = $self->{szip}->extract(
            $file,
            sub { $self->save(@_) },
            $self->{sevenzip_params},
            $self->{var}{list}
        );
        $self->after_unpack($file, $extracted_files, $corrupted_paths);
    }
    # print STDERR Dumper @$files;

    return $self->finalize();
}

1
