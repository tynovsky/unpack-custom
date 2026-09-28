[![Actions Status](https://github.com/tynovsky/unpack-custom/actions/workflows/test.yml/badge.svg)](https://github.com/tynovsky/unpack-custom/actions)
# NAME

Unpack::Custom - extract archives with 7-Zip using user-defined callbacks

# SYNOPSIS

    use Unpack::Custom;

    my $unpacker = Unpack::Custom->new(
        initialize    => sub { my ($self) = @_; ... },
        want_unpack   => sub { my ($self, $file) = @_; return 1 },
        before_unpack => sub { my ($self, $file) = @_; ... },
        save          => sub {
            my ($self, $contents, $file_info) = @_;
            # $file_info->{path}, $file_info->{size}
            ...
            return $saved_filename;
        },
        after_unpack  => sub {
            my ($self, $file, $extracted_files, $corrupted_paths) = @_;
            ...
        },
        finalize      => sub { my ($self) = @_; return $result },

        sevenzip_params => ['-pPASSWORD'],   # optional
        sevenzip        => '/usr/bin/7z',    # optional, path to 7z binary
    );

    my $result = $unpacker->extract(\@archives, $destination, \@sevenzip_params);

# DESCRIPTION

Unpack::Custom is a wrapper around [Unpack::SevenZip](https://metacpan.org/pod/Unpack%3A%3ASevenZip) which allows user to
define callback functions implementing behavior during extracting an archive.
You can specify what to do before unpacking starts, before and after unpacking
a file, and after unpacking finishes. Moreover you can also specify how to
recognize if a file is an archive we want to unpack. This general module is
used in [Unpack::Custom::Ordinary](https://metacpan.org/pod/Unpack%3A%3ACustom%3A%3AOrdinary) and [Unpack::Custom::Recursive](https://metacpan.org/pod/Unpack%3A%3ACustom%3A%3ARecursive).

# METHODS

## new(%args) or new(\\%args)

All six callbacks (`initialize`, `finalize`, `before_unpack`,
`after_unpack`, `want_unpack`, `save`) are required. Each callback gets the
unpacker object as its first argument. Optional arguments:

- sevenzip\_params

    Default ARRAY reference of switches passed to 7z (e.g. `['-pPASSWORD']`).

- sevenzip

    Path to the 7z binary (default `7z`).

## extract(\\@files, $destination, \\@sevenzip\_params)

Processes the queue of `@files` and returns whatever `finalize` returns.
Neither `@files` nor `@sevenzip_params` are modified. The optional
`@sevenzip_params` override the defaults given to `new` for this call only.
Dies if any of the files does not exist.

The state of the current run is kept in `$self->{var}` (which is reset
at the start of each `extract` call) and callbacks may use it:

- files

    The queue of files to process. Callbacks may push more files to it (this is
    how recursive extraction works).

- destination

    The destination given to `extract`.

- sevenzip\_params

    The 7z switches used for this run.

- list

    Reset before each file. If `want_unpack` or `before_unpack` sets it to the
    list of files in the archive (as returned by `$self->{szip}->info`), the
    archive does not have to be listed again.

- extra\_params

    Reset to an empty ARRAY before each file. Additional 7z switches used only for
    the current file.

## password\_params

Returns an ARRAY reference with the first password switch (`-p...`) of the
current run, or an empty ARRAY reference. Useful for listing archives with
`$self->{szip}->info($file, $self->password_params)`.

# LICENSE

Copyright (C) Týnovský Miroslav.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Týnovský Miroslav <tynovsky@avast.com>
