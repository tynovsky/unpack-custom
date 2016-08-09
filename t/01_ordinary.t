use strict;
use warnings;
use Test::More 0.98;
use File::Path qw(remove_tree);
use Data::Dumper;
use Unpack::Custom::Ordinary;

my $sevenzip = $ENV{SEVENZIP} // '7z';

my $unpacker = Unpack::Custom::Ordinary->new();

`$sevenzip a t/ordinary.7z META.json t/01_ordinary.t`;

my @files = qw(t/ordinary.7z);

$unpacker->extract([@files], 'dest', ['-pinfected']);

ok(-e 'dest/META.json', 'META.json extracted');
ok(-e 'dest/t/01_ordinary.t', 'test file extracted');

note `ls dest`;

unlink 't/ordinary.7z';

done_testing;
