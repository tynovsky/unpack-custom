use strict;
use warnings;
use Test::More 0.98;
use Test::Exception;
use lib 't/lib';
use TestUtil qw(clean dat_files);
use Unpack::Custom::Recursive;
use Unpack::Custom::Ordinary;

my $dest = 'dest_nonexistent';
clean($dest);

for my $class (qw(Unpack::Custom::Recursive Unpack::Custom::Ordinary)) {
    my $unpacker = $class->new();

    throws_ok {
        $unpacker->extract(['t/nonexistent.7z'], $dest);
    } qr/does not exist/, "$class dies on non-existing file";

    throws_ok {
        $unpacker->extract('t/r.zip', $dest);
    } qr/ARRAY reference/, "$class dies when files are not an ARRAY ref";

    throws_ok {
        $unpacker->extract(['t/r.zip']);
    } qr/destination is required/, "$class dies without destination";

    is(scalar(dat_files($dest)), 0, 'No files extracted');
}

clean($dest);

done_testing;
