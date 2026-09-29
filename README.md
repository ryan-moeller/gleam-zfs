# zfs

[![FreeBSD 15.1](https://github.com/ryan-moeller/gleam-zfs/workflows/FreeBSD%2015.1/badge.svg)](https://github.com/ryan-moeller/gleam-zfs/actions/workflows/test.yml)

This project is an experimental proof of concept.  It does nothing useful at the
moment other than running some tests.

## Development

```sh
# build
pkg install erlang-runtime29 gleam mold
make
# test
pkg install erlang git
gleam test  # Run the tests (must be run as root)
```
