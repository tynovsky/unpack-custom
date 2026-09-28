use strict;
use warnings;
use Test::More 0.98;
use lib 't/lib';
use TestUtil qw(run_7z clean dat_files);
use Unpack::Custom::Recursive;

my ($archive, $dest) = ('t/password.7z', 'dest_password');
clean($archive, $dest);

run_7z('a', '-pHESLO', $archive, 'META.json', 'LICENSE');

my $unpacker = Unpack::Custom::Recursive->new();
$unpacker->extract([$archive], $dest);

is(scalar(dat_files($dest)), 1, 'Not extracted without password');

my $params = ['-pHESLO'];
$unpacker->extract([$archive], $dest, $params);
is(scalar(dat_files($dest)), 2, 'Extracted with password');
is_deeply($params, ['-pHESLO'], 'sevenzip params not modified');

clean($dest);

$unpacker->extract([$archive], $dest);
is(scalar(dat_files($dest)), 1, 'password is not remembered from previous call');

clean($dest);

my $with_default = Unpack::Custom::Recursive->new({ sevenzip_params => ['-pHESLO'] });
$with_default->extract([$archive], $dest);
is(scalar(dat_files($dest)), 2, 'Extracted with password given to new()');

clean($archive, $dest);

done_testing;
