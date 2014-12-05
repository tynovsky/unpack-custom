use strict;
use Test::More 0.98;
use Unpack::Custom::Recursive;
use IO::Select;
use File::Path qw(remove_tree);

remove_tree('dest');
my $unpacker = Unpack::Custom::Recursive->new();

$unpacker->extract([ 't/archive.7z' ], 'dest');

# note `find dest`;
my @files = glob('dest/*.dat');
is(@files, 50, 'All files extracted');

open my $fh, '<', 'dest/names.txt';
my @names = <$fh>;
close $fh;
is(@names, 62, 'All names are there');

remove_tree('dest');

done_testing;
