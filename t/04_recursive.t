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

$unpacker->extract_recursive_sha(1, @files);

my @result = glob('dest/*.dat');
#note `ls dest`;
is(@result, 3, 'Three files extracted');

remove_tree('dest');

done_testing;
