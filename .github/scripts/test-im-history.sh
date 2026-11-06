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
    DYYYPlaybackCatalogStore.m Tests/DYYYPlaybackCatalogStoreTests.m -o "$test_dir/playback-catalog-tests"
"$test_dir/playback-catalog-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYFeedCardPolicy.m Tests/DYYYFeedCardPolicyTests.m -o "$test_dir/feed-card-tests"
"$test_dir/feed-card-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYTabBarMetrics.m Tests/DYYYTabBarMetricsTests.m -o "$test_dir/tabbar-metrics-tests"
"$test_dir/tabbar-metrics-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYChatEnhancementPolicy.m Tests/DYYYChatEnhancementPolicyTests.m -o "$test_dir/chat-enhancement-tests"
"$test_dir/chat-enhancement-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYFriendShareBadgeMetrics.m Tests/DYYYFriendShareBadgeMetricsTests.m -o "$test_dir/friend-share-badge-tests"
"$test_dir/friend-share-badge-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYRecallPolicy.m Tests/DYYYRecallPolicyTests.m -o "$test_dir/recall-policy-tests"
"$test_dir/recall-policy-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -framework ImageIO -framework CoreGraphics -framework AVFoundation -framework CoreMedia -lsqlite3 -I. \
    DYYYRecallPolicy.m DYYYRecallStore.m Tests/DYYYRecallStoreTests.m -o "$test_dir/recall-store-tests"
"$test_dir/recall-store-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYRecallMarkerMetrics.m Tests/DYYYRecallMarkerMetricsTests.m -o "$test_dir/recall-marker-tests"
"$test_dir/recall-marker-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYChatLifecycle.m Tests/DYYYChatLifecycleTests.m -o "$test_dir/chat-lifecycle-tests"
"$test_dir/chat-lifecycle-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYVideoPageMetrics.m Tests/DYYYVideoPageMetricsTests.m -o "$test_dir/video-page-metrics-tests"
"$test_dir/video-page-metrics-tests"
xcrun clang -fobjc-arc -fblocks -framework Foundation -I. \
    DYYYMessageListMetrics.m Tests/DYYYMessageListMetricsTests.m -o "$test_dir/message-list-metrics-tests"
"$test_dir/message-list-metrics-tests"
