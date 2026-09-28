use strict;
use warnings;
use Test::More 0.98;
use lib 't/lib';
use TestUtil qw(clean dat_files);
use Unpack::Custom::Recursive;

my $dest = 'dest_quine';

my $unpacker = Unpack::Custom::Recursive->new();

# r.zip contains itself, quine.zip contains a directory with r.zip
for my $quine (qw(t/r.zip t/quine.zip)) {
    clean($dest);
    $unpacker->extract([$quine], $dest);

    is(scalar(dat_files($dest)), 0, "$quine: nothing was extracted (it's a trap!).");
    ok(-e "$dest/names.txt", "$quine: names.txt written");
}

clean($dest);

done_testing;
