use strict;
use Test::More 0.98;
use Unpack::Recursive;

my $unpacker = Unpack::Recursive->new();

my $output = $unpacker->run_7zip('b');
ok($output, 'Got the output handle');

my $seen_total = 0;
while (<$output>) {
	$seen_total = 1 if /^Tot:/
}

ok($seen_total, 'Seen the last line "Tot:"');


done_testing;

