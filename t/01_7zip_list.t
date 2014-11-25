use strict;
use Test::More 0.98;
use Unpack::Recursive;
use IO::Select;

my $unpacker = Unpack::Recursive->new();

my $out =  $unpacker->szip_list('t/archive.7z');
like($out, qr/Listing archive/, 'list contains string "Listing archive"'); 

# note $out;


done_testing;


