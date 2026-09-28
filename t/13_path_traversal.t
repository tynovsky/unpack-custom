use strict;
use warnings;
use Test::More 0.98;
use lib 't/lib';
use TestUtil qw(clean);
use Unpack::Custom::Ordinary;
use IO::Compress::Zip qw(zip $ZipError);

my ($archive, $dest) = ('t/traversal.zip', 'dest_traversal/inner');
clean($archive, 'dest_traversal');

my $zip = IO::Compress::Zip->new($archive, Name => '../evil.txt')
    or die "zip failed: $ZipError";
print {$zip} "evil\n";
$zip->newStream(Name => '/absolute.txt');
print {$zip} "absolute\n";
$zip->newStream(Name => 'good/./file.txt');
print {$zip} "good\n";
$zip->close;

my $unpacker = Unpack::Custom::Ordinary->new();
my @warnings;
{
    local $SIG{__WARN__} = sub { push @warnings, @_ };
    $unpacker->extract([$archive], $dest);
}

ok(! -e 'dest_traversal/evil.txt', 'no file written outside destination');
ok(-e "$dest/absolute.txt", 'absolute path made relative');
ok(-e "$dest/good/file.txt", 'normal file extracted');
ok((grep { /unsafe path '\.\.\/evil\.txt'/ } @warnings), 'warned about unsafe path');

is_deeply(
    [ Unpack::Custom::Ordinary::safe_path_parts('a/../../b') ], [],
    'path with .. rejected',
);
is_deeply(
    [ Unpack::Custom::Ordinary::safe_path_parts('C:\\dir\\file') ], ['dir', 'file'],
    'windows path',
);

clean($archive, 'dest_traversal');

done_testing;
