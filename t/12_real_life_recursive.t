#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Unpack::Custom::Recursive;
use File::Path qw(remove_tree);
use Data::Dumper;
use Digest::SHA;
use List::MoreUtils qw(uniq);

my $unpacker = Unpack::Custom::Recursive->new();

my $dir = 'apache-abdera-1.1-src';
#$dir = 'core';
#$dir = 'test';
#$dir = 'util';
my $archive = "t/$dir.tar.gz";

`tar xzf $archive`;
`mv $dir/dependencies/i18n/src/main/resources/org/apache/abdera/i18n/unicode/data/ucd.res $dir/dependencies/i18n/src/main/resources/org/apache/abdera/i18n/unicode/data/ucd.res.gz`;
`gunzip $dir/dependencies/i18n/src/main/resources/org/apache/abdera/i18n/unicode/data/ucd.res.gz`;
my $hashes = `for f in \$(find $dir -type f); do sha256sum \$f; done`;
#print $hashes;
my @hashes = uniq sort map { s/ .*//; $_ } (split /\n/, $hashes);
`rm -rf $dir`;

#print Dumper \@hashes;

$unpacker->extract([$archive], 'dest');

my @result = map { s/dest\/(.*)\.dat/$1/; $_ } glob('dest/*.dat');

is(scalar(@result), scalar(@hashes), 'same number of elements');
is_deeply(\@result, \@hashes);

remove_tree('dest');

done_testing();
