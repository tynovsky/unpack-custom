[![Actions Status](https://github.com/tynovsky/unpack-custom/actions/workflows/test.yml/badge.svg?branch=master)](https://github.com/tynovsky/unpack-custom/actions?workflow=test)
# NAME

Unpack::Custom - extract archives with 7-Zip using user-defined callbacks

# SYNOPSIS

    use Unpack::Custom;

    # total size of the files in the archives by extension, nothing is
    # written to the disk
    my %size_of;
    my $unpacker = Unpack::Custom->new(
        initialize    => sub { %size_of = () },
        want_unpack   => sub {
            my ($self, $file) = @_;
            return $file =~ /\.(?:zip|7z|tar)$/;
        },
        before_unpack => sub { },
        save          => sub {
            my ($self, $contents, $file) = @_;
            my ($extension) = $file->{path} =~ /\.(\w+)$/;
            $size_of{ lc($extension // '') } += length $contents;
            return $file->{path};
        },
        after_unpack  => sub {
            my ($self, $archive, $extracted, $corrupted) = @_;
            warn "$archive: corrupted @$corrupted\n" if @$corrupted;
        },
        finalize      => sub { return { %size_of } },
    );

    my $size_of = $unpacker->extract(['a.zip', 'b.7z'], 'unused');

# DESCRIPTION

Unpack::Custom extracts archives of any format 7-Zip can read (zip, 7z,
rar, tar, gzip, bzip2, xz, iso, cab, but also e.g. executables, see
["REQUIREMENTS"](#requirements)) and lets
you decide what happens with the extracted files. The files are extracted
into memory and handed to your `save` callback; nothing is written to the
disk unless the callback does it.

`extract` processes a queue of files. For each file it asks `want_unpack`
whether to extract it, then calls `before_unpack`, `save` for every file
in the archive and `after_unpack`. Callbacks may add files to the queue,
which is how [Unpack::Custom::Recursive](https://metacpan.org/pod/Unpack%3A%3ACustom%3A%3ARecursive) extracts nested archives.

Two ready-made unpackers are built on this module:

- [Unpack::Custom::Ordinary](https://metacpan.org/pod/Unpack%3A%3ACustom%3A%3AOrdinary)

    extracts archives into a directory tree, like `7z x`

- [Unpack::Custom::Recursive](https://metacpan.org/pod/Unpack%3A%3ACustom%3A%3ARecursive)

    extracts archives recursively (archives in archives) into files named by
    the SHA-256 of their content, so each content is stored once

# CALLBACKS

All six callbacks are required (use `sub { }` for the ones you don't
need). Each callback gets the unpacker object as its first argument; any
other arguments given to `new` (e.g. your own options) are available in it
as `$self->{name}`. An exception thrown by a callback stops `extract`
and is propagated to its caller.

## initialize($self)

Called once at the start of `extract`, after the state of the run
(["THE STATE OF A RUN"](#the-state-of-a-run)) is set up. It may change the queue in
`$self->{var}{files}`, e.g. copy the input files somewhere.

## want\_unpack($self, $file)

Called for each file taken from the queue. Return true to extract the
file; if it returns false, the file is skipped and no other callback is
called for it. A typical implementation asks 7-Zip whether the file is an
archive; it may store the listing in `$self->{var}{list}`, so the
archive is not listed twice:

    want_unpack => sub {
        my ($self, $file) = @_;
        my ($list) = $self->{szip}->info($file, $self->password_params);
        $self->{var}{list} = $list;
        return @$list > 0;
    },

## before\_unpack($self, $file)

Called before the file is extracted. It may set `$self->{var}{list}`
(see ["THE STATE OF A RUN"](#the-state-of-a-run)) and add switches for this file only to
`$self->{var}{extra_params}`.

## save($self, $contents, $file)

Called for each file extracted from the archive (directories are skipped).
`$contents` is the whole content of the file as a byte string, `$file` is
a HASH reference with the keys `path` (the path inside the archive) and
`size` (missing when 7-Zip does not know it, e.g. for `bzip2`). Return
a value describing the saved file (e.g. its new name); the values are
passed to `after_unpack`. Return an empty list for a file you don't want
to count as extracted.

## after\_unpack($self, $file, \\@extracted, \\@corrupted)

Called after the file was extracted. `@extracted` are the values returned
by `save`, `@corrupted` are the paths (inside the archive) of the files
7-Zip reported as corrupted (CRC error, data error, wrong password, ...);
their content may already have been passed to `save`. Push files to
`$self->{var}{files}` to process them too.

## finalize($self)

Called once at the end. Its return value is the return value of
`extract`.

# METHODS

## new(%args) or new(\\%args)

Takes the six callbacks and these optional arguments:

- sevenzip\_params

    Default ARRAY reference of switches passed to 7-Zip, e.g.
    `['-pPASSWORD']`. All `-p` switches are tried as passwords (and the
    empty password), see ["extract" in Unpack::SevenZip](https://metacpan.org/pod/Unpack%3A%3ASevenZip#extract).

- sevenzip

    Path to the 7-Zip binary (default `7z`).

Dies if a callback is missing or if the 7-Zip binary can't be run.

## extract(\\@files, $destination, \\@sevenzip\_params)

Processes the queue of `@files` and returns whatever `finalize` returns.
`$destination` is required, but used only by the callbacks. The optional
`@sevenzip_params` are used instead of the ones given to `new` for this
call only. Neither `@files` nor `@sevenzip_params` are modified.

Dies if `@files` is not an ARRAY reference, if a file does not exist or
if `$destination` is missing.

## password\_params

Returns an ARRAY reference with the first password switch (`-p...`) of the
current run, or an empty ARRAY reference. Use it to list encrypted
archives: `$self->{szip}->info($file, $self->password_params)`.

## $self->{szip}

The [Unpack::SevenZip](https://metacpan.org/pod/Unpack%3A%3ASevenZip) object, use it to list archives in the callbacks.

# THE STATE OF A RUN

`$self->{var}` is a HASH reference reset at the start of each
`extract` call. Callbacks may keep their own data in it too.

- files

    The queue of files to process. Callbacks may push more files to it.

- destination

    The destination given to `extract`.

- sevenzip\_params

    The 7-Zip switches used for this run.

- list

    Reset before each file. When `want_unpack` or `before_unpack` sets it to
    the list of files in the archive (as returned by
    ["info" in Unpack::SevenZip](https://metacpan.org/pod/Unpack%3A%3ASevenZip#info)), the archive is not listed again. The list is
    used to split the output of 7-Zip into files, so it must contain exactly
    the files 7-Zip extracts, in the same order (exclude the others with `-x!`
    switches in `extra_params`).

- extra\_params

    Reset to an empty ARRAY reference before each file. Additional 7-Zip
    switches used only for the current file.

# REQUIREMENTS

The 7-Zip command line program `7z`, e.g. the `7zip` package (or the
older `p7zip-full`) on Debian and Ubuntu; RAR archives need the `7zip-rar`
package there. Use the `sevenzip` argument when `7z` is not in the
`PATH`.

# LIMITATIONS

Each extracted file is kept in memory while it is passed to `save`, so
the largest file in an archive has to fit into memory.

# SEE ALSO

[Unpack::Custom::Ordinary](https://metacpan.org/pod/Unpack%3A%3ACustom%3A%3AOrdinary), [Unpack::Custom::Recursive](https://metacpan.org/pod/Unpack%3A%3ACustom%3A%3ARecursive),
[Unpack::SevenZip](https://metacpan.org/pod/Unpack%3A%3ASevenZip)

# LICENSE

Copyright (C) Týnovský Miroslav.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Týnovský Miroslav <tynovsky@seznam.cz>
