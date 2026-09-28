requires 'perl', '5.010';
# not on CPAN, install from https://github.com/tynovsky/unpack-sevenzip
requires 'Unpack::SevenZip';
requires 'Path::Tiny';
requires 'Digest::SHA';
requires 'File::Copy';
requires 'File::Path';
requires 'Carp';

on 'build' => sub {
    requires 'ExtUtils::Config';
    requires 'ExtUtils::Helpers';
    requires 'ExtUtils::Helpers::Unix';
    requires 'ExtUtils::InstallPaths';
    requires 'Module::Build::Tiny';
};

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Exception';
    requires 'IO::Compress::Zip';
    requires 'IO::Uncompress::Gunzip';
    requires 'File::Find';
};
