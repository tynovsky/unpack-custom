use strict;
use warnings;
use Test::More 0.98;
use lib 't/lib';
use TestUtil qw(clean dat_files corrupt_dat_files read_names);
use Unpack::Custom::Recursive;

my $dest = 'dest_pipe_troubles';
clean($dest);

my $unpacker = Unpack::Custom::Recursive->new();

$unpacker->extract(['t/pipe_troubles.zip'], $dest);

ok(scalar(dat_files($dest)) > 0, 'Files extracted');
is_deeply([corrupt_dat_files($dest)], [], 'content matches file names');

my $name_of = read_names($dest);
ok((grep { m{^t/pipe_troubles\.zip/gmc\.inf$} } values %$name_of),
    'top level file listed in names.txt');

clean($dest);

done_testing;
