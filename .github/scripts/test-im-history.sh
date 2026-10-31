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
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYCommentMenuMetrics.m Tests/DYYYCommentMenuMetricsTests.m -o "$test_dir/comment-menu-metrics-tests"
"$test_dir/comment-menu-metrics-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYFriendShareReturnState.m Tests/DYYYFriendShareReturnStateTests.m -o "$test_dir/share-return-tests"
"$test_dir/share-return-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYDetailCaptionMetrics.m Tests/DYYYDetailCaptionMetricsTests.m -o "$test_dir/detail-caption-tests"
"$test_dir/detail-caption-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYChatInputMetrics.m Tests/DYYYChatInputMetricsTests.m -o "$test_dir/chat-input-tests"
"$test_dir/chat-input-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYIMConversationStore.m Tests/DYYYIMConversationStoreTests.m -o "$test_dir/im-conversation-store-tests"
"$test_dir/im-conversation-store-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYIMSendLedger.m Tests/DYYYIMSendLedgerTests.m -o "$test_dir/im-send-ledger-tests"
"$test_dir/im-send-ledger-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYHomeDailyFilter.m Tests/DYYYHomeDailyFilterTests.m -o "$test_dir/home-daily-filter-tests"
"$test_dir/home-daily-filter-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYUnreadProbe.m Tests/DYYYUnreadProbeTests.m -o "$test_dir/unread-probe-tests"
"$test_dir/unread-probe-tests"
