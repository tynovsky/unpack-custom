use strict;
use warnings;
use Test::More 0.98;
use Test::Exception;
use lib 't/lib';
use TestUtil qw(sevenzip);
use Unpack::Custom;
use Unpack::Custom::Recursive;

my %callbacks = %Unpack::Custom::Recursive::callbacks;

throws_ok { Unpack::Custom->new() } qr/Missing required parameter save/,
    'dies without callbacks';
throws_ok { Unpack::Custom->new(%callbacks, save => 'x') }
    qr/Invalid parameter save, expecting CODE/, 'dies on non-CODE callback';
throws_ok { Unpack::Custom->new(%callbacks, sevenzip_params => '-p') }
    qr/Invalid parameter sevenzip_params/, 'dies on non-ARRAY sevenzip_params';
throws_ok { Unpack::Custom->new(%callbacks, sevenzip => 'true') }
    qr/doesn't seem to be 7zip/, 'sevenzip binary is passed to Unpack::SevenZip';

my $params = ['-pX'];
my $unpacker = Unpack::Custom->new({ %callbacks, sevenzip => sevenzip(), sevenzip_params => $params });
isa_ok($unpacker, 'Unpack::Custom');
ok($unpacker->can($_), "method $_") for qw(initialize finalize save want_unpack);
ok(! $unpacker->can('nonexistent'), 'no AUTOLOAD for unknown methods');
throws_ok { $unpacker->nonexistent } qr/Can't locate object method/,
    'unknown method dies';
push @$params, '-y';
is_deeply($unpacker->{sevenzip_params}, ['-pX'], 'default params copied');

done_testing;
