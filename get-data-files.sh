#!/bin/sh
# Downloads the data files that this repository links to.
#
#   ./get-data-files.sh [-u] [-f] [-s source] [name ...]
#
# Each data file is listed as a .link file, in the folder where the examples
# and tests look for it, holding the address the file is downloaded from.
# The file is saved beside its link, under the link's name without .link,
# and is unpacked when it arrives gzip-compressed. A file that is already
# there is kept, unless -u or -f is given.
#
#   name  the files to download, by file or folder name, for example
#         51Degrees-LiteV4.1.hash or ip-intelligence. Every linked
#         file when none is given.
#   -u    asks again for each file that is already there, and replaces it
#         only when a newer one is available
#   -f    downloads every file again
#   -s    sent with each download from the Distributor, so that downloads
#         can be counted by where they come from. Defaults to
#         ci-<repository> in GitHub Actions and to data elsewhere.
#
# Needs curl and gzip.
set -eu

DISTRIBUTOR_HOST=distributor.51degrees.com
CONNECT_TIMEOUT_SECONDS=30
USER_AGENT='get-data-files/1.0 (sh; +https://github.com/51Degrees/data)'

usage() {
    sed -n '4,22p' "$0" | sed 's/^# \{0,1\}//' >&2
    exit 2
}

update=0
force=0
source=
while getopts ufs: opt; do
    case $opt in
        u) update=1 ;;
        f) force=1 ;;
        s) source=$OPTARG ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

case $source in
    *[!A-Za-z0-9._-]*)
        echo "-s takes letters, digits, dots, dashes and underscores" >&2
        exit 2 ;;
esac
if [ -z "$source" ]; then
    source=data
    if [ "${GITHUB_ACTIONS:-}" = true ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
        source=ci-${GITHUB_REPOSITORY##*/}
    fi
fi

# True when no names follow the link, or one of them is the link's file or
# folder name.
wanted() {
    _file=$(basename "$1" .link)
    _folder=$(basename "$(dirname "$1")")
    shift
    [ $# -eq 0 ] && return 0
    for _n in "$@"; do
        if [ "$_n" = "$_file" ] || [ "$_n" = "$_folder" ]; then
            return 0
        fi
    done
    return 1
}

# The last value of a header in the response, without its name.
header() {
    grep -i "^$1:" "$_headers" | tail -n 1 |
        sed 's/^[^:]*:[[:space:]]*//; s/[[:space:]]*$//'
}

md5_of() {
    if command -v md5sum >/dev/null 2>&1; then
        md5sum < "$1" | cut -d ' ' -f 1
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q "$1"
    fi
}

# True unless a hex Content-MD5 header matches none of the files given,
# which are the bytes received and the bytes unpacked from them.
md5_matches() {
    _expected=$(header Content-MD5 | tr 'A-F' 'a-f')
    case $_expected in
        *[!0-9a-f]*|'') return 0 ;;
    esac
    [ ${#_expected} -eq 32 ] || return 0
    [ -n "$(md5_of "$1")" ] || return 0
    for _f in "$@"; do
        [ "$(md5_of "$_f")" = "$_expected" ] && return 0
    done
    return 1
}

cleanup() {
    rm -f "$_part" "$_unpacked" "$_headers"
}

# Downloads $1 to $2, reported as $3. Fails with a message on any error.
fetch() {
    _url=$1
    _target=$2
    _label=$3
    _part=$_target.part
    _unpacked=$_target.unpacked
    _headers=$_target.headers
    if [ -e "$_target" ] && [ "$force" -eq 0 ]; then
        echo "Checking $_label"
        set -- -z "$_target"
    else
        echo "Downloading $_label"
        set --
    fi
    # Over HTTP/2 the Distributor answers If-Modified-Since with a 304 that
    # has content, which curl rejects, so ask over HTTP/1.1.
    _code=$(curl -sS -L --http1.1 --connect-timeout "$CONNECT_TIMEOUT_SECONDS" \
        -A "$USER_AGENT" -R -D "$_headers" -o "$_part" -w '%{http_code}' \
        ${1+"$@"} "$_url") || _code=000
    case $_code in
        200) ;;
        304)
            echo "$_label is up to date"
            cleanup
            return 0 ;;
        429)
            _wait=$(header Retry-After)
            case $_wait in
                '') _when=later ;;
                *[!0-9]*) _when="after $_wait" ;;
                *) _when="in $(( (_wait + 59) / 60 )) minutes" ;;
            esac
            echo "$_label was not saved. Each file can only be downloaded" \
                "a few times an hour from one address. Try again $_when." >&2
            cleanup
            return 1 ;;
        000)
            echo "$_label was not saved, because the download from" \
                "$_url did not complete." >&2
            cleanup
            return 1 ;;
        *)
            echo "$_label was not saved. The server answered HTTP $_code." >&2
            cleanup
            return 1 ;;
    esac
    if [ ! -s "$_part" ]; then
        echo "$_label was not saved. The server sent an empty file." >&2
        cleanup
        return 1
    fi
    _saved=$_part
    if [ "$(head -c 2 "$_part" | od -An -tx1 | tr -d ' \n')" = 1f8b ]; then
        if ! gzip -dc < "$_part" > "$_unpacked"; then
            echo "$_label was not saved, because it did not unpack." >&2
            cleanup
            return 1
        fi
        touch -r "$_part" "$_unpacked"
        _saved=$_unpacked
    fi
    if ! md5_matches "$_part" "$_saved"; then
        echo "$_label was not saved. The file received does not match its" \
            "Content-MD5 header." >&2
        cleanup
        return 1
    fi
    mv -f "$_saved" "$_target"
    cleanup
    echo "Saved $_label, $(( $(wc -c < "$_target") / 1048576 )) MB"
}

root=$(cd "$(dirname "$0")" && pwd)
links=$(mktemp)
trap 'rm -f "$links"' EXIT
find "$root" -name .git -prune -o -type f -name '*.link' -print > "$links"

for name in ${1+"$@"}; do
    found=0
    while IFS= read -r link <&3; do
        if wanted "$link" "$name"; then
            found=1
            break
        fi
    done 3< "$links"
    if [ "$found" -eq 0 ]; then
        echo "No data file or folder is called $name" >&2
        exit 2
    fi
done

failed=0
while IFS= read -r link <&3; do
    wanted "$link" ${1+"$@"} || continue
    target=${link%.link}
    label=$(basename "$(dirname "$link")")/$(basename "$target")
    if [ -e "$target" ] && [ "$update" -eq 0 ] && [ "$force" -eq 0 ]; then
        echo "$label is already there"
        continue
    fi
    url=$(head -n 1 "$link" | tr -d '\r')
    case $url in
        "https://$DISTRIBUTOR_HOST/"*)
            case $url in
                *\?*) url="$url&source=$source" ;;
                *) url="$url?source=$source" ;;
            esac ;;
    esac
    fetch "$url" "$target" "$label" || failed=$((failed + 1))
done 3< "$links"
[ "$failed" -eq 0 ]
