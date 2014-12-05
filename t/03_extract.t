use strict;
use Test::More 0.98;
use Unpack::Recursive;
use IO::Select;
use File::Path qw(remove_tree);

my $unpacker = Unpack::Recursive->new();

$unpacker->extract_recursive_sha([ 't/archive.7z' ], 0, 'dest');

# note `find dest`;
my @files = glob('dest/*.dat');
is(@files, 62, 'All files extracted');

open my $fh, '<', 'dest/names.txt';
my @names = <$fh>;
close $fh;
is(@names, 62, 'All names are there');

remove_tree('dest');

done_testing;
