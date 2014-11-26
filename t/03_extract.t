use strict;
use Test::More 0.98;
use Unpack::Recursive;
use IO::Select;
use File::Path qw(remove_tree);

my $unpacker = Unpack::Recursive->new();

$unpacker->extract_sha('t/archive.7z', 'dest');

#note `find dest`;
my @files = glob('dest/*.dat');
is(@files, 24, 'All files extracted');

open my $fh, '<', 'dest/names.txt';
my @names = <$fh>;
close $fh;
is(@names, 25, 'All names are there');

remove_tree('dest');

done_testing;
