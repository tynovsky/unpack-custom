use strict;
use warnings;
use Test::More 0.98;
use lib 't/lib';
use TestUtil qw(clean dat_files);
use Unpack::Custom::Recursive;
use File::Copy;

my ($file, $dest) = ('t/nonarchive.7z', 'dest_nonarchive');
clean($file, $dest);

copy('LICENSE', $file) or die "copy failed: $!";

my $unpacker = Unpack::Custom::Recursive->new();
$unpacker->extract([$file], $dest);

is(scalar(dat_files($dest)), 1, 'No files extracted from non-archive');
ok(-e $file, 'input file not deleted');

clean($file, $dest);

done_testing;
