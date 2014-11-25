use strict;
use Test::More 0.98;
use Unpack::Recursive;
use Data::Dumper;

my $unpacker = Unpack::Recursive->new();

my $files =  $unpacker->szip_list('t/archive.7z');

is(@$files, 24, 'there are 24 files in the archive');

note Dumper $files;


done_testing;


