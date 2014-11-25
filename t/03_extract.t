use strict;
use Test::More 0.98;
use Unpack::Recursive;
use IO::Select;
use File::Path qw(remove_tree);

my $unpacker = Unpack::Recursive->new();

$unpacker->extract('t/archive.7z', 'dest');

#note `find dest`;
my $file_count = int( `find dest -type f -name "*.dat" | wc --lines` );
is($file_count, 24, 'All files extracted');
remove_tree('dest');

done_testing;

