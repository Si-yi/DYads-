#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

if [[ "$#" -eq 0 ]]; then
    echo "Usage: $0 <Deb package> [...]" >&2
    exit 2
fi
work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
for deb in "$@"; do
    case "$deb" in
        /*) deb_path=$deb ;;
        *) deb_path=$PWD/$deb ;;
    esac
    package_dir=$(mktemp -d "$work_dir/package.XXXXXX")
    (cd "$package_dir" && ar -x "$deb_path")
    data_archives=("$package_dir"/data.tar*)
    if [[ "${#data_archives[@]}" -ne 1 || ! -f "${data_archives[0]}" ]]; then
        echo "Expected one data archive in $deb" >&2
        printf 'Extracted archive entry: %s\n' "$package_dir"/* >&2
        exit 1
    fi
    listing=$(tar -tf "${data_archives[0]}")
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
