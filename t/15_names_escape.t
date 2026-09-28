use strict;
use warnings;
use Test::More 0.98;
use lib 't/lib';
use TestUtil qw(clean read_names);
use Unpack::Custom::Recursive;
use IO::Compress::Zip qw($ZipError);
use Digest::SHA qw(sha256_hex);

my ($archive, $dest) = ('t/names.zip', 'dest_names');
clean($archive, $dest);

my $zip = IO::Compress::Zip->new($archive, Name => "tab\there.txt")
    or die "zip failed: $ZipError";
print {$zip} "tab\n";
$zip->close;

Unpack::Custom::Recursive->new()->extract([$archive], $dest);

is(read_names($dest)->{ sha256_hex("tab\n") }, "$archive/tab\\there.txt",
    'tab in name escaped');

is(Unpack::Custom::Recursive::escape_name("a\\b\nc\rd"), 'a\\\\b\\nc\\rd',
    'backslash, newline and carriage return escaped');

clean($archive, $dest);

done_testing;
