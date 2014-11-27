use strict;
use Test::More 0.98;
use Unpack::Recursive;
use IO::Select;
use File::Path qw(remove_tree);
use Try::Tiny;
use Data::Dumper;

my $unpacker = Unpack::Recursive->new();

`7z a b.7z META.json README.md`;
`7z a t/recursive.7z b.7z LICENSE`;
`rm b.7z`;

my @files = qw(t/recursive.7z);

while (my $f = shift @files) {
    #note "Processing file: $f\n";
    try {
        my $extracted = $unpacker->extract_sha($f, 'dest');
        if (@$extracted) {
            unlink $f; #the file was archive, now it is extracted
        }
        #note Dumper $extracted;
        push @files, @$extracted;
    }
    catch {
        note 'failed to unpack (not an archive?)';
    }
}

my @result = glob('dest/*.dat');
#note `ls dest`;
is(@result, 3, 'Three files extracted');

remove_tree('dest');

done_testing;
