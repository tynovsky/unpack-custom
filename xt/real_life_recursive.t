#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use lib 't/lib';
use TestUtil qw(clean dat_files);
use Unpack::Custom::Recursive;
use Digest::SHA;
use File::Find;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);

my $dir     = 'apache-abdera-1.1-src';
my $archive = "xt/data/$dir.tar.gz";
my $dest    = 'dest_real_life';
plan skip_all => "$archive not available (not part of the distribution)" if ! -e $archive;
clean($dir, $dest);

system('tar', 'xzf', $archive) == 0 or die "tar xzf $archive failed: $?";

# this file is gzipped, the unpacker will unpack it as well
my $ucd = "$dir/dependencies/i18n/src/main/resources/org/apache/abdera/i18n/unicode/data/ucd.res";
gunzip($ucd => "$ucd.tmp") or die "gunzip failed: $GunzipError";
rename "$ucd.tmp", $ucd or die "rename failed: $!";

my %hashes;
find({ no_chdir => 1, wanted => sub {
    return if ! -f $_;
    $hashes{ Digest::SHA->new(256)->addfile($_, 'b')->hexdigest } = 1;
} }, $dir);
my @hashes = sort keys %hashes;
clean($dir);

my $unpacker = Unpack::Custom::Recursive->new();
$unpacker->extract([$archive], $dest);

my @result = map { m{([0-9a-f]{64})\.dat$} } dat_files($dest);

is(scalar(@result), scalar(@hashes), 'same number of elements');
is_deeply(\@result, \@hashes, 'same contents');

clean($dest);

done_testing();
