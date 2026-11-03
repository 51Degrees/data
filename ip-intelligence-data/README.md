# IP Intelligence data

This folder holds the IP Intelligence test evidence, the script that
generates it, and the country name translations. The Lite and Asn data
files are downloaded into this folder by the scripts at the root of the
repository.

See the [repository README](../README.md) for what each file is and how to
get it.

## Download scripts in this folder

`get-lite-file-from-azure.ps1` and `get-lite-file-from-azure.sh` are kept
so that existing scripts that call them keep working. They download the
same files as the root scripts.

## Tests

`ci/run-unit-tests.ps1` runs the Pester tests in `tests/`. Each test
downloads a file into a temporary folder and checks that it unpacks.
