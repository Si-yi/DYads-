#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYIMHistoryReader.m Tests/DYYYIMHistoryReaderTests.m -o "$test_dir/im-history-tests"
"$test_dir/im-history-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYFriendShareHistory.m Tests/DYYYFriendShareHistoryTests.m -o "$test_dir/share-history-tests"
"$test_dir/share-history-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYFriendShareDelivery.m Tests/DYYYFriendShareDeliveryTests.m -o "$test_dir/share-delivery-tests"
"$test_dir/share-delivery-tests"
