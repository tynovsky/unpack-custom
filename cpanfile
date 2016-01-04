requires 'perl', '5.010';
requires 'Unpack::SevenZip';
requires 'Clone';
requires 'Try::Tiny';

on 'build' => sub {
    requires 'ExtUtils::Config';
    requires 'ExtUtils::Helpers';
    requires 'ExtUtils::Helpers::Unix';
    requires 'ExtUtils::InstallPaths';
    requires 'Module::Build::Tiny';
};

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'List::MoreUtils';
    requires 'Test::Exception';
};

