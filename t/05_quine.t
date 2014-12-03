use strict;
use Test::More 0.98;
use Unpack::Recursive;
use IO::Select;
use File::Path qw(remove_tree);
use Try::Tiny;
use Data::Dumper;

my $unpacker = Unpack::Recursive->new();

`cp t/r.zip t/quine.zip`;

my @files = qw(t/quine.zip);

$unpacker->extract_recursive_sha([ @files ], 0, 'dest');

ok(1);


my @result = glob('dest/*.dat');
note `ls dest`;
is(@result, 1, 'One file was extracted (avoided endless loop!).');
note `cat dest/names.txt`;

remove_tree('dest');
done_testing;

