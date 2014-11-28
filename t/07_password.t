use strict;
use Test::More 0.98;
use Unpack::Recursive;
use IO::Select;
use File::Path qw(remove_tree);

my $unpacker = Unpack::Recursive->new();

$unpacker->extract_sha('t/password.7z', 'dest');

my @files = glob('dest/*.dat');
is(@files, 0, 'Not extracted without password');

$unpacker->extract_sha('t/password.7z', 'dest', ['-pHESLO']);
@files = glob('dest/*.dat');
is(@files, 1, 'Extracted with password');

remove_tree('dest');

done_testing;
