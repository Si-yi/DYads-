#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -eq 0 ]]; then
    echo "Usage: $0 <Deb package> [...]" >&2
    exit 2
fi
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
for deb in "$@"; do
    data_archive=$(ar -t "$deb" | awk '/^data\.tar(\.|$)/ { print }')
    if [[ -z "$data_archive" || "$data_archive" == *$'\n'* ]]; then
        echo "Expected one data archive in $deb" >&2
        exit 1
    fi
    case "$data_archive" in
        data.tar|data.tar.gz|data.tar.xz|data.tar.zst|data.tar.bz2|data.tar.lzma) ;;
        *) echo "Unsupported data archive in $deb: $data_archive" >&2; exit 1 ;;
    esac
    ar -p "$deb" "$data_archive" > "$work_dir/$data_archive"
    listing=$(tar -tf "$work_dir/$data_archive")
    dylib_count=$(awk '/(^|\/)DYads-\.dylib$/ { n++ } END { print n+0 }' <<< "$listing")
    filter_count=$(awk '/(^|\/)DYads-\.plist$/ { n++ } END { print n+0 }' <<< "$listing")
    if [[ "$dylib_count" -ne 1 || "$filter_count" -ne 1 ]]; then
        echo "Expected DYads-.dylib and DYads-.plist exactly once in $deb" >&2
        exit 1
    fi
    if grep -Eq '(^|/)DYYY\.(dylib|plist)$' <<< "$listing"; then
        echo "Legacy DYYY injection files remain in $deb" >&2
        exit 1
    fi
    echo "Verified DYads- injection identity: $deb"
done
