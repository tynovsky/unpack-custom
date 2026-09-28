use strict;
use warnings;
use Test::More 0.98;
use lib 't/lib';
use TestUtil qw(run_7z clean dat_files corrupt_dat_files read_names);
use Unpack::Custom::Recursive;
use Digest::SHA;

my ($archive, $dest) = ('t/recursive.7z', 'dest_recursive');
clean($archive, $dest, 'b.7z');

my $unpacker = Unpack::Custom::Recursive->new();

my $sha = 'Digest::SHA'->new(256)->addfile('README.md', 'b')->hexdigest();

run_7z('a', 'b.7z', 'META.json', 'README.md');
run_7z('a', $archive, 'b.7z', 'LICENSE');
unlink 'b.7z';

$unpacker->extract([$archive], $dest);

is(scalar(dat_files($dest)), 3, 'Three files extracted');
is_deeply([corrupt_dat_files($dest)], [], 'content matches file names');

my $name_of = read_names($dest);
is(scalar(keys %$name_of), 5, 'There are five records in names.txt');
is($name_of->{$sha}, "$archive/b.7z/README.md", 'Recursive name is correct');

clean($archive, $dest);

done_testing;
