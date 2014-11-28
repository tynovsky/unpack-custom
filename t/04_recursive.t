use strict;
use Test::More 0.98;
use Unpack::Recursive;
use IO::Select;
use File::Path qw(remove_tree);
use Try::Tiny;
use Data::Dumper;

my $unpacker = Unpack::Recursive->new();

`7z a b.7z META.json README.md`;
`7z a t/recursive.7z b.7z LICENSE`;
`rm b.7z`;

my @files = qw(t/recursive.7z);

$unpacker->extract_recursive_sha([@files], 1, 'dest');

my @result = glob('dest/*.dat');
#note `ls dest`;
#note `cat dest/names.txt`;
is(@result, 3, 'Three files extracted');
open my $fh, '<', 'dest/names.txt';
is(scalar(() = <$fh>), 5, 'There are five records in names.txt');
close $fh;

remove_tree('dest');

done_testing;
