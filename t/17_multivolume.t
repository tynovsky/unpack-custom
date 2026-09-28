use strict;
use warnings;
use Test::More 0.98;
use lib 't/lib';
use TestUtil qw(clean);
use Unpack::Custom::Recursive;

# a fake 7z listing of a middle volume of a multivolume (RAR) archive: its
# first and last file are only partially contained in it
{
    package FakeSevenZip;
    sub new { bless {}, shift }
    sub info {
        return (
            [ map { { path => $_, size => 1 } } "it's first.txt", 'middle.txt', 'last *.txt' ],
            { multivolume => '+', characteristics => '' },
        );
    }
}

my $unpacker = Unpack::Custom::Recursive->new()->{_unpack_custom};
$unpacker->{szip} = FakeSevenZip->new;
$unpacker->{var} = { sevenzip_params => ['-pX'], extra_params => [] };

$unpacker->before_unpack('volume.part2.rar');

is_deeply($unpacker->{var}{list}, [ { path => 'middle.txt', size => 1 } ],
    'only complete files are extracted');
is_deeply($unpacker->{var}{extra_params}, ['-spd', '-x!last *.txt', "-x!it's first.txt"],
    'partial files excluded literally');
is_deeply($unpacker->{var}{sevenzip_params}, ['-pX'], 'sevenzip params not modified');

done_testing;
