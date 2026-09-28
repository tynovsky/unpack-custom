use strict;
use warnings;
use Test::More 0.98;
use lib 't/lib';
use TestUtil qw(run_7z clean dat_files read_names);
use Unpack::Custom::Recursive;
use Unpack::Custom::Ordinary;
use File::Copy;
use Digest::SHA;

my $dest = 'dest_state';
my @tmp  = ($dest, 't/state_inner.7z', 't/state_outer.7z', '0', 't/state_copy.7z');
clean(@tmp);

run_7z('a', 't/state_inner.7z', 'META.json');
run_7z('a', 't/state_outer.7z', 't/state_inner.7z', 'LICENSE');
copy('t/state_outer.7z', '0') or die "copy failed: $!";
copy('t/state_outer.7z', 't/state_copy.7z') or die "copy failed: $!";

my %sha = map {
    $_ => Digest::SHA->new(256)->addfile($_, 'b')->hexdigest
} qw(META.json LICENSE t/state_inner.7z);

sub extracted { [ map { m{([0-9a-f]{64})\.dat$} } dat_files($dest) ] }
sub shas      { [ sort @sha{@_} ] }

my $unpacker = Unpack::Custom::Recursive->new();

# the same object used twice: the nested archive has to be unpacked again
for my $run (1, 2) {
    clean($dest);
    $unpacker->extract(['t/state_outer.7z'], $dest);
    is_deeply(extracted(), shas(qw(META.json LICENSE)),
        "run $run: nested archive unpacked");
}

# a file named '0' does not stop the queue
clean($dest);
Unpack::Custom::Ordinary->new()->extract(['0'], $dest);
ok(-e "$dest/LICENSE", "file named '0' processed");

# the same content given twice is processed once
clean($dest);
my @warnings;
{
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    $unpacker->extract(['t/state_outer.7z', 't/state_copy.7z'], $dest);
}
is_deeply(extracted(), shas(qw(META.json LICENSE)), 'duplicate input processed once');
is_deeply(\@warnings, [], 'no warnings');
is(read_names($dest)->{ $sha{'META.json'} }, 't/state_outer.7z/t/state_inner.7z/META.json',
    'first input name is used');

# no_recursive
clean($dest);
Unpack::Custom::Recursive->new({ no_recursive => 1 })
    ->extract(['t/state_outer.7z'], $dest);
is_deeply(extracted(), shas(qw(t/state_inner.7z LICENSE)), 'no_recursive: nested archive kept');

# max_depth
clean($dest);
Unpack::Custom::Recursive->new({ max_depth => 0 })
    ->extract(['t/state_outer.7z'], $dest);
is_deeply(extracted(), shas(qw(t/state_inner.7z LICENSE)), 'max_depth 0: nested archive not unpacked');

clean($dest);
Unpack::Custom::Recursive->new({ max_depth => 1 })
    ->extract(['t/state_outer.7z'], $dest);
is_deeply(extracted(), shas(qw(META.json LICENSE)), 'max_depth 1: nested archive unpacked');

# max_extracted_size
clean($dest);
{
    my @size_warnings;
    local $SIG{__WARN__} = sub { push @size_warnings, @_ };
    Unpack::Custom::Recursive->new({ max_extracted_size => 1 })
        ->extract(['t/state_outer.7z'], $dest);
    is(scalar(dat_files($dest)), 1, 'max_extracted_size: nothing extracted');
    ok((grep { /max_extracted_size exceeded/ } @size_warnings), 'warned about size');
}

clean(@tmp);

done_testing;
