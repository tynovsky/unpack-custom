use strict;
use warnings;
use Test::More 0.98;
use lib 't/lib';
use TestUtil qw(run_7z clean dat_files corrupt_dat_files);
use Unpack::Custom::Recursive;

my ($archive, $dest) = ('t/corrupted.7z', 'dest_corrupted');
clean($archive, $dest);

run_7z('a', $archive, 'LICENSE', 'META.json');

# damage the archive: replace the first 'a' on every line by 'b'
{
    open my $fh, '+<:raw', $archive or die "Cannot open $archive: $!";
    local $/ = "\n";
    my @lines = <$fh>;
    s/a/b/ for @lines;
    seek $fh, 0, 0;
    print {$fh} @lines;
    close $fh or die "Cannot write $archive: $!";
}

my $unpacker = Unpack::Custom::Recursive->new();
$unpacker->extract([$archive], $dest);

my @files = dat_files($dest);
is(scalar(@files), 1, 'No files extracted from corrupted file');
is_deeply([corrupt_dat_files($dest)], [], 'content matches file names');

clean($archive, $dest);

done_testing;
