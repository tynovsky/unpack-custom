use strict;
use Test::More 0.98;
use Unpack::Recursive;
use File::Path qw(remove_tree);

my $unpacker = Unpack::Recursive->new();

`cp LICENSE t/nonarchive.7z`;

$unpacker->extract_recursive_sha(['t/nonarchive.7z'], 0, 'dest');

my @files = glob('dest/*.dat');
is(@files, 1, 'No files extracted from non-archive');

remove_tree('dest');
unlink 't/nonarchive.7z';

done_testing;


