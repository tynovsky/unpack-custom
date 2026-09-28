package TestUtil;

use strict;
use warnings;

use Exporter ();
our @ISA = qw(Exporter);
use File::Path qw(remove_tree);
use Digest::SHA;
use Test::More;
use Unpack::SevenZip;

our @EXPORT_OK = qw(sevenzip run_7z clean dat_files corrupt_dat_files read_names);

sub sevenzip { $ENV{SEVENZIP} // '7z' }

# skip the whole test file when 7-Zip is not installed (e.g. CPAN testers)
sub import {
    my $ok = eval { Unpack::SevenZip->new({ sevenzip => sevenzip() }); 1 };
    plan skip_all => '7-Zip (7z) not found, set SEVENZIP to its path' if ! $ok;
    __PACKAGE__->export_to_level(1, @_);
}

# run 7z with a list of arguments (no shell), die on failure
sub run_7z {
    my @args = @_;

    open my $null, '>', '/dev/null' or die "Cannot open /dev/null: $!";
    open my $stdout, '>&', \*STDOUT or die "Cannot dup STDOUT: $!";
    open STDOUT, '>&', $null or die "Cannot redirect STDOUT: $!";
    my $rc = system sevenzip(), @args;
    open STDOUT, '>&', $stdout or die "Cannot restore STDOUT: $!";
    die "7z @args failed: $?" if $rc != 0;
}

sub clean { remove_tree($_) for @_; unlink grep { -f } @_ }

sub dat_files {
    my ($dir) = @_;
    my @files = sort glob("$dir/*.dat");
    return @files;
}

# .dat files whose name does not match the sha256 of their content
sub corrupt_dat_files {
    my ($dir) = @_;

    return grep {
        my ($sha) = m{([0-9a-f]{64})\.dat$};
        Digest::SHA->new(256)->addfile($_, 'b')->hexdigest ne $sha
    } dat_files($dir);
}

# names.txt as a hash sha => name
sub read_names {
    my ($dir) = @_;

    open my $fh, '<:raw', "$dir/names.txt" or die "Cannot read names.txt: $!";
    my %name_of;
    while (my $line = <$fh>) {
        chomp $line;
        my ($sha, $name) = split /\t/, $line, 2;
        $name_of{$sha} = $name;
    }
    close $fh;

    return \%name_of;
}

1;
