use strict;
use Test::More 0.98;
use Unpack::Custom::Recursive;
use File::Path qw(remove_tree);

my $unpacker = Unpack::Custom::Recursive->new();

`cp LICENSE t/nonarchive.7z`;

$unpacker->extract(['t/nonarchive.7z'], 'dest');

my @files = glob('dest/*.dat');
is(@files, 1, 'No files extracted from non-archive');

remove_tree('dest');
unlink 't/nonarchive.7z';

done_testing;


