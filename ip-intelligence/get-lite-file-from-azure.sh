#!/bin/sh
# Kept so that scripts that call it keep working. Downloads the IP
# Intelligence Lite and Asn files with ../get-data-files.sh, which gets them
# from the Distributor and saves them in this folder.
#
#   ./get-lite-file-from-azure.sh [-f] [-lite] [-asn]
set -eu

here=$(cd "$(dirname "$0")" && pwd)
force=
lite=0
asn=0
for arg in ${1+"$@"}; do
    case $arg in
        -force|-Force|-f) force=-f ;;
        -lite|-Lite) lite=1 ;;
        -asn|-Asn) asn=1 ;;
        *)
            echo "Unknown option: $arg" >&2
            exit 1 ;;
    esac
done

# Both files unless one is asked for.
set --
if [ "$lite" -eq 1 ] || [ "$asn" -eq 0 ]; then
    set -- ${1+"$@"} 51Degrees-LiteV41.ipi
fi
if [ "$asn" -eq 1 ] || [ "$lite" -eq 0 ]; then
    set -- ${1+"$@"} 51Degrees-IPIV4AsnIpiV41.ipi
fi
exec sh "$here/../get-data-files.sh" $force "$@"
