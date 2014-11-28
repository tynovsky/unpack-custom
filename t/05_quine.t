use strict;
use Test::More 0.98;
use Unpack::Recursive;
use IO::Select;
use File::Path qw(remove_tree);
use Try::Tiny;
use Data::Dumper;

my $unpacker = Unpack::Recursive->new();

`cp t/r.zip t/quine.zip`;

my @files = qw(t/quine.zip);

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

ok(1);


my @result = glob('dest/*.dat');
#note `ls dest`;
is(@result, 0, 'Nothing was extracted. It\'s a trap!');
#note `cat dest/names.txt`;

remove_tree('dest');
done_testing;

