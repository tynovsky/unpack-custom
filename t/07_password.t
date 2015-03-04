use strict;
use Test::More 0.98;
use Unpack::Custom::Recursive;
use IO::Select;
use File::Path qw(remove_tree);

`7z a -pHESLO t/password.7z META.json LICENSE`;

my $unpacker = Unpack::Custom::Recursive->new();
$unpacker->extract(['t/password.7z'], 'dest');

my @files = glob('dest/*.dat');
is(@files, 1, 'Not extracted without password');

$unpacker->extract(['t/password.7z'], 'dest', ['-pHESLO']);
note `ls dest`;
note `cat dest/names.txt`;
#note `cat dest/*.dat`;
@files = glob('dest/*.dat');
is(@files, 2, 'Extracted with password');

remove_tree('dest');
unlink 't/password.7z';

done_testing;
