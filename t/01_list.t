use strict;
use Test::More 0.98;
use Unpack::Recursive;
use Data::Dumper;

my $unpacker = Unpack::Recursive->new();

my $files =  $unpacker->list('t/archive.7z');

is(@$files, 24, 'there are 24 files in the archive');
is($files->[20]->{size}, 140288, '19th filesize is correct');
is($files->[20]->{path}, '7zS.sfx', '19th filepath is correct');

#note Dumper $files;


done_testing;


