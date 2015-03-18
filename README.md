[![Build Status](https://travis-ci.org/tynovsky/unpack-custom.svg?branch=master)](https://travis-ci.org/tynovsky/unpack-custom)
# NAME

Unpack::Custom - It's new $module

# SYNOPSIS

    use Unpack::Custom;

# DESCRIPTION

Unpack::Custom is a wrapper around Unpack::SevenZip which allows user to define
callback functions implementing behavior during extracting an archive. You can
specify what to do before unpacking starts, before and after unpacking a file,
and after unpacking finishes. Moreover you can also specify how to recognize
if a file is an archive we want to unpack. This general module is used in
Unpack::Custom::Recursive which extracts archives recursively.

# LICENSE

Copyright (C) Týnovský Miroslav.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Týnovský Miroslav <tynovsky@avast.com>
