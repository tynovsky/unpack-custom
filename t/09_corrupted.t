use strict;
use Test::More 0.98;
use Unpack::Custom::Recursive;
use File::Path qw(remove_tree);

my $unpacker = Unpack::Custom::Recursive->new();

`7z a t/corrupted.7z LICENSE META.json`;
`sed -i 's/a/b/' t/corrupted.7z`;


$unpacker->extract(['t/corrupted.7z'], 'dest');

my @files = glob('dest/*.dat');
is(@files, 1, 'No files extracted from corrupted file');

remove_tree('dest');
unlink 't/corrupted.7z';

done_testing;

