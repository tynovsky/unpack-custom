use strict;
use Test::More 0.98;
use Unpack::Recursive;

my $unpacker = Unpack::Recursive->new();

$unpacker->run_7zip('b');


done_testing;

