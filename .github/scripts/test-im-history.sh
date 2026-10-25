#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYIMHistoryReader.m Tests/DYYYIMHistoryReaderTests.m -o "$test_dir/im-history-tests"
"$test_dir/im-history-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYIMShareParser.m DYYYFriendShareHistory.m Tests/DYYYIMShareParserTests.m -o "$test_dir/im-share-parser-tests"
"$test_dir/im-share-parser-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYFriendShareHistory.m DYYYIMShareParser.m Tests/DYYYFriendShareHistoryTests.m -o "$test_dir/share-history-tests"
"$test_dir/share-history-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYFriendShareDelivery.m Tests/DYYYFriendShareDeliveryTests.m -o "$test_dir/share-delivery-tests"
"$test_dir/share-delivery-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYAutoMessageBatch.m Tests/DYYYAutoMessageBatchTests.m -o "$test_dir/auto-message-batch-tests"
"$test_dir/auto-message-batch-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYCommentMenuItems.m Tests/DYYYCommentMenuItemsTests.m -o "$test_dir/comment-menu-items-tests"
"$test_dir/comment-menu-items-tests"
