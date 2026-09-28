use strict;
use warnings;
use Test::More 0.98;
use lib 't/lib';
use TestUtil qw(clean dat_files);
use Unpack::Custom::Recursive;

my $dest = 'dest_quine';
clean($dest);

my $unpacker = Unpack::Custom::Recursive->new();

$unpacker->extract(['t/r.zip'], $dest);

is(scalar(dat_files($dest)), 0, 'Nothing was extracted (it\'s a trap!).');
ok(-e "$dest/names.txt", 'names.txt written');

clean($dest);

done_testing;
