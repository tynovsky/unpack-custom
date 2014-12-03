use strict;
use Test::More 0.98;
use Test::Exception;
use Unpack::Recursive;
use File::Path qw(remove_tree);

my $unpacker = Unpack::Recursive->new();

dies_ok {
    $unpacker->extract_sha('t/nonexistent.7z', 'dest');
}, 'dies on non-existing file';

my @files = glob('dest/*.dat');
is(@files, 0, 'No files extracted from nonexistent file');

remove_tree('dest');

done_testing;
