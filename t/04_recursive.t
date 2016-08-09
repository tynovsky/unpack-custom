use strict;
use Test::More 0.98;
use Unpack::Custom::Recursive;
use IO::Select;
use File::Path qw(remove_tree);
use Try::Tiny;
use Data::Dumper;
use Digest::SHA;


my $sevenzip = $ENV{SEVENZIP} // '7z';

my $unpacker = Unpack::Custom::Recursive->new();

my $sha = 'Digest::SHA'->new(256)->addfile('README.md', 'b')->hexdigest();

`$sevenzip a b.7z META.json README.md`;
`$sevenzip a t/recursive.7z b.7z LICENSE`;
unlink 'b.7z';

my @files = qw(t/recursive.7z);

$unpacker->extract([@files], 'dest');

my @result = glob('dest/*.dat');
#note `ls dest`;
#note `cat dest/names.txt`;
is(@result, 3, 'Three files extracted');

open my $fh, '<', 'dest/names.txt';
my @lines = <$fh>;
close $fh;
is(@lines, 5, 'There are five records in names.txt');

my %hash = ();
for my $line (@lines) {
    chomp $line;
    %hash = (%hash, split /\t/, $line);
}

is($hash{$sha}, 't/recursive.7z/b.7z/README.md', 'Recursive name is correct');


remove_tree('dest');
unlink 't/recursive.7z';

done_testing;
