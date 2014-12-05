use strict;
use Test::More 0.98;
use Unpack::Custom::Recursive;
use IO::Select;
use File::Path qw(remove_tree);
use Try::Tiny;
use Data::Dumper;

my $unpacker = Unpack::Custom::Recursive->new();

my @files = qw(t/r.zip);

$unpacker->extract([ @files ], 'dest');

my @result = glob('dest/*.dat');
note `ls dest`;
is(@result, 0, 'Nothing was extracted (it\'s a trap!).');
note `cat dest/names.txt`;

remove_tree('dest');
done_testing;

