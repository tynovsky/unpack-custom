use strict;
use Test::More 0.98;
use Unpack::Custom::Recursive;
use IO::Select;
use File::Path qw(remove_tree);
use Try::Tiny;
use Data::Dumper;

my $unpacker = Unpack::Custom::Recursive->new({ no_recursive => 1 });

my $extracted = $unpacker->extract(['t/2014-05-28.part1.rar'], 'dest');

my @result = glob('dest/*.dat');
#note `ls dest`;
is(@result, 58, '58 files extracted, one skipped');
# my $last = int(`grep 033257BA7D4C9F4EC128362F667EFC9E525BE5DD dest/names.txt | wc --lines`);

# is($last, 0, 'Last file is the one skipped');

remove_tree('dest');
done_testing;


