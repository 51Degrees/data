#!/bin/bash

# Base URL for all data files
BASE_URL="https://51ddatafiles.blob.core.windows.net/enterpriseipi/"

# Known files: "remote basename|local .ipi name"
LITE_FILE="51Degrees-IPIV4LiteIpiV41.ipi.gz|51Degrees-LiteV41.ipi"
ASN_FILE="51Degrees-IPIV4AsnIpiV41.ipi.gz|51Degrees-IPIV4AsnIpiV41.ipi"

# Default values
FORCE=false
WANT_LITE=false
WANT_ASN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -force|-Force|-f)
            FORCE=true
            shift
            ;;
        -lite|-Lite)
            WANT_LITE=true
            shift
            ;;
        -asn|-Asn)
            WANT_ASN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Selection: if neither -lite nor -asn is passed, do all known files.
# Otherwise only the ones explicitly opted in.
SELECTED=()
[ "$WANT_LITE" = true ] && SELECTED+=("$LITE_FILE")
[ "$WANT_ASN" = true ]  && SELECTED+=("$ASN_FILE")

# None explicitly requested => do all known files
if [ ${#SELECTED[@]} -eq 0 ]; then
    SELECTED=("$LITE_FILE" "$ASN_FILE")
fi

process_file() {
    local remote="$1"
    local archived_name="$2"
    local archive_url="${BASE_URL}${remote}"
    local archive_name="${archived_name}.gz"

    # Download if forced or archive doesn't exist
    if [ "$FORCE" = true ] || [ ! -f "$archive_name" ]; then
        curl -o "$archive_name" "$archive_url"
    else
        echo "Archive found. Download skipped."
    fi

    # Compute MD5 hash with cross-platform support
    local archive_hash
    if command -v md5sum >/dev/null 2>&1; then
        archive_hash=$(md5sum "$archive_name" | awk '{ print $1 }')  # Ubuntu (Linux)
    elif command -v md5 >/dev/null 2>&1; then
        archive_hash=$(md5 -q "$archive_name")  # macOS
    else
        echo "Error: No MD5 checksum tool found."
        exit 1
    fi

    echo "MD5 (fetched $archive_name) = $archive_hash"

    # Extract archive
    echo "Extracting $archive_name"
    echo "Extracting '$archive_name' to '$archived_name'..."

    # Use gunzip for decompression
    gunzip -c "$archive_name" > "$archived_name"
}

for entry in "${SELECTED[@]}"; do
    remote="${entry%%|*}"
    archived_name="${entry##*|}"
    process_file "$remote" "$archived_name"
done
