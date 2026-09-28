use strict;
use warnings;
use Test::More 0.98;
use lib 't/lib';
use TestUtil qw(run_7z clean);
use Unpack::Custom::Ordinary;

my ($archive, $dest) = ('t/ordinary.7z', 'dest_ordinary');
clean($archive, $dest);

run_7z('a', $archive, 'META.json', 't/01_ordinary.t');

my $unpacker = Unpack::Custom::Ordinary->new();

my @files  = ($archive);
my $params = ['-pinfected'];
$unpacker->extract(\@files, $dest, $params);

ok(-e "$dest/META.json", 'META.json extracted');
ok(-e "$dest/t/01_ordinary.t", 'test file extracted');
is(-s "$dest/META.json", -s 'META.json', 'META.json has the right size');
is_deeply(\@files, [$archive], 'list of files not modified');
is_deeply($params, ['-pinfected'], 'sevenzip params not modified');

clean($archive, $dest);

done_testing;
