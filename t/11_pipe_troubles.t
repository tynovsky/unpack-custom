use strict;
use Test::More 0.98;
use Unpack::Custom::Recursive;
use File::Path qw(remove_tree);

my $unpacker = Unpack::Custom::Recursive->new();

$unpacker->extract(['t/pipe_troubles.zip'], 'dest');

ok(1, 'Extraction finished');

#remove_tree('dest');

done_testing;


