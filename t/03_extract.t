use strict;
use Test::More 0.98;
use Unpack::Recursive;
use IO::Select;

my $unpacker = Unpack::Recursive->new();

$unpacker->extract('t/archive.7z');

