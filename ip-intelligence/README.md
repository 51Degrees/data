# IP Intelligence data

This folder holds the IP Intelligence test evidence, the script that
generates it, and the country name translations. The Lite and Asn data
files are downloaded into this folder by the scripts at the root of the
repository.

See the [repository README](../README.md) for what each file is and how to
get it.

## Download scripts in this folder

`get-lite-file-from-azure.ps1` and `get-lite-file-from-azure.sh` are kept
so that existing scripts that call them keep working, with the same
options. They no longer use Azure storage. Each one runs the root script
for the Lite file, the Asn file or both, which downloads them from the
Distributor into this folder.
