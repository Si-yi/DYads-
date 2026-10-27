#import "DYYYBackupTools.h"
#import "DYYYConstants.h"
#import <objc/runtime.h>

static NSString * const DYYYBackupFormat = @"com.dyyy.settings.backup";
static NSString * const DYYYBackupUndoName = @"DYYY_LastRestoreUndo.json";
static const NSUInteger DYYYBackupMaxBytes = 20 * 1024 * 1024;
static const NSUInteger DYYYBackupMaxIconBytes = 8 * 1024 * 1024;
static char kDYYYBackupPickerDelegateKey;

static NSSet<NSString *> *DYYYBackupExcludedKeys(void) {
    static NSSet *keys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      keys = [NSSet setWithArray:@[
          @"DYYYDebugInspectorEnabled",
          @"DYYYEnableFloatSpeedButton", @"DYYYAutoRestoreSpeed", @"DYYYSpeedButtonShowX", @"DYYYSpeedButtonSize", @"DYYYSpeedSettings",
          @"DYYYEnableFloatClearButton", @"DYYYEnableFloatClearButtonSize", @"DYYYClearButtonIcon", @"DYYYRemoveTimeProgress", @"DYYYHideTimeProgress",
          @"DYYYHideDanmaku", @"DYYYHideSlider", @"DYYYHideTabBar", @"DYYYHideSpeed", @"DYYYHideClearButtonOnTap", @"DYYYHideChapter",
          @"DYYYHidePauseVideoIcon", @"DYYYHideStatusBarOnClear", @"DYYYHideButtonCenterXPercent", @"DYYYHideButtonCenterYPercent", @"DYYYHideUIButtonLockState"
      ]];
    });
    return keys;
}

static NSArray<NSString *> *DYYYBackupIconNames(void) {
    return @[ @"like_before.png", @"like_after.png", @"comment.png", @"unfavorite.png", @"favorite.png", @"share.png", @"tab_plus.png" ];
}

static NSString *DYYYBackupDirectory(void) {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject ?: NSTemporaryDirectory();
    return [documents stringByAppendingPathComponent:@"DYYY"];
}

static NSString *DYYYBackupUndoPath(void) {
    return [DYYYBackupDirectory() stringByAppendingPathComponent:DYYYBackupUndoName];
}

static id DYYYBackupJSONSafeObject(id value) {
    if (!value || value == [NSNull null]) return [NSNull null];
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSData class]]) return @{ @"__dyyyDataBase64" : [(NSData *)value base64EncodedStringWithOptions:0] };
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *items = [NSMutableArray array];
        for (id item in value) [items addObject:DYYYBackupJSONSafeObject(item) ?: [NSNull null]];
        return items;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *items = [NSMutableDictionary dictionary];
        [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id key, id item, BOOL *stop) {
          if ([key isKindOfClass:[NSString class]]) items[key] = DYYYBackupJSONSafeObject(item) ?: [NSNull null];
        }];
        return items;
    }
    return nil;
}

static id DYYYBackupRestoreJSONSafeObject(id value) {
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        NSString *encoded = dictionary[@"__dyyyDataBase64"];
        if ([encoded isKindOfClass:[NSString class]] && dictionary.count == 1) {
            return [[NSData alloc] initWithBase64EncodedString:encoded options:0];
        }
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        [dictionary enumerateKeysAndObjectsUsingBlock:^(id key, id item, BOOL *stop) {
          if ([key isKindOfClass:[NSString class]]) {
              id restored = DYYYBackupRestoreJSONSafeObject(item);
              if (restored) result[key] = restored;
          }
        }];
        return result;
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *result = [NSMutableArray array];
        for (id item in value) [result addObject:DYYYBackupRestoreJSONSafeObject(item) ?: [NSNull null]];
        return result;
    }
    return value;
}

static NSDictionary *DYYYBackupCurrentPayload(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSMutableDictionary *settings = [NSMutableDictionary dictionary];
    [[defaults dictionaryRepresentation] enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
      if ([key hasPrefix:@"DYYY"] && ![DYYYBackupExcludedKeys() containsObject:key]) {
          id safeValue = DYYYBackupJSONSafeObject(value);
          if (safeValue) settings[key] = safeValue;
      }
    }];

    NSMutableDictionary *icons = [NSMutableDictionary dictionary];
    NSFileManager *manager = NSFileManager.defaultManager;
    NSString *directory = DYYYBackupDirectory();
    NSUInteger totalBytes = 0;
    for (NSString *name in DYYYBackupIconNames()) {
        NSString *path = [directory stringByAppendingPathComponent:name];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data.length == 0 || totalBytes + data.length > DYYYBackupMaxIconBytes) continue;
        totalBytes += data.length;
        icons[name] = [data base64EncodedStringWithOptions:0];
    }
    (void)manager;
    return @{
        @"format" : DYYYBackupFormat,
        @"version" : @1,
        @"createdAt" : [[NSISO8601DateFormatter new] stringFromDate:NSDate.date],
        @"settings" : settings,
        @"icons" : icons
    };
}

static BOOL DYYYBackupWritePayload(NSDictionary *payload, NSString *path, NSError **error) {
    if (![NSJSONSerialization isValidJSONObject:payload]) {
        if (error) *error = [NSError errorWithDomain:@"DYYYBackup" code:1 userInfo:@{NSLocalizedDescriptionKey:@"设置包含无法备份的数据"}];
        return NO;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:error];
    if (data.length == 0 || data.length > DYYYBackupMaxBytes) {
        if (error && !*error) *error = [NSError errorWithDomain:@"DYYYBackup" code:2 userInfo:@{NSLocalizedDescriptionKey:@"备份文件超过大小限制"}];
        return NO;
    }
    return [data writeToFile:path options:NSDataWritingAtomic error:error];
}

static NSDictionary *DYYYBackupReadPayload(NSURL *url, NSError **error) {
    if (!url || ![url isFileURL]) return nil;
    NSNumber *size = nil;
    [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    if (size.unsignedLongLongValue > DYYYBackupMaxBytes) {
        if (error) *error = [NSError errorWithDomain:@"DYYYBackup" code:3 userInfo:@{NSLocalizedDescriptionKey:@"备份文件超过 20 MB"}];
        return nil;
    }
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:error];
    if (scoped) [url stopAccessingSecurityScopedResource];
    if (!data || data.length == 0 || data.length > DYYYBackupMaxBytes) return nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:error];
    return [object isKindOfClass:[NSDictionary class]] ? object : nil;
}

static BOOL DYYYBackupIsLegacyKeyExcluded(NSString *key) {
    return [DYYYBackupExcludedKeys() containsObject:key];
}

static NSDictionary *DYYYBackupNormalizedPayload(NSDictionary *input, NSError **error) {
    NSDictionary *settings = input[@"settings"];
    NSDictionary *icons = input[@"icons"];
    if ([input[@"format"] isEqualToString:DYYYBackupFormat]) {
        if (![settings isKindOfClass:[NSDictionary class]] || (icons && ![icons isKindOfClass:[NSDictionary class]])) {
            if (error) *error = [NSError errorWithDomain:@"DYYYBackup" code:4 userInfo:@{NSLocalizedDescriptionKey:@"备份文件字段无效"}];
            return nil;
        }
    } else {
        // 兼容旧版 DYYY 导出的平铺 JSON。
        NSMutableDictionary *legacySettings = [NSMutableDictionary dictionary];
        [input enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
          if ([key isKindOfClass:[NSString class]] && [key hasPrefix:@"DYYY"] && ![key isEqualToString:@"DYYYIconsBase64"]) legacySettings[key] = value;
        }];
        settings = legacySettings;
        icons = input[@"DYYYIconsBase64"];
    }
    NSMutableDictionary *filteredSettings = [NSMutableDictionary dictionary];
    [settings enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
      if ([key isKindOfClass:[NSString class]] && [key hasPrefix:@"DYYY"] && !DYYYBackupIsLegacyKeyExcluded(key)) filteredSettings[key] = value;
    }];
    NSMutableDictionary *filteredIcons = [NSMutableDictionary dictionary];
    if ([icons isKindOfClass:[NSDictionary class]]) {
        for (NSString *name in DYYYBackupIconNames()) {
            id encoded = icons[name];
            if ([encoded isKindOfClass:[NSString class]]) filteredIcons[name] = encoded;
        }
    }
    return @{ @"settings" : filteredSettings, @"icons" : filteredIcons };
}

static BOOL DYYYBackupApplyNormalizedPayload(NSDictionary *payload, BOOL saveUndo, NSError **error) {
    NSDictionary *settings = payload[@"settings"];
    NSDictionary *icons = payload[@"icons"];
    NSUInteger validatedIconBytes = 0;
    for (NSString *name in DYYYBackupIconNames()) {
        NSString *encoded = [icons isKindOfClass:[NSDictionary class]] ? icons[name] : nil;
        if (!encoded) continue;
        NSData *image = [[NSData alloc] initWithBase64EncodedString:encoded options:0];
        if (!image || image.length == 0 || validatedIconBytes + image.length > DYYYBackupMaxIconBytes) {
            if (error) *error = [NSError errorWithDomain:@"DYYYBackup" code:6 userInfo:@{NSLocalizedDescriptionKey:@"图标备份数据无效或过大"}];
            return NO;
        }
        validatedIconBytes += image.length;
    }
    if (saveUndo) {
        NSError *snapshotError = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:DYYYBackupDirectory() withIntermediateDirectories:YES attributes:nil error:nil];
        if (!DYYYBackupWritePayload(DYYYBackupCurrentPayload(), DYYYBackupUndoPath(), &snapshotError)) {
            if (error) *error = snapshotError;
            return NO;
        }
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSDictionary *all = defaults.dictionaryRepresentation;
    for (NSString *key in all) {
        if ([key hasPrefix:@"DYYY"] && ![DYYYBackupExcludedKeys() containsObject:key]) [defaults removeObjectForKey:key];
    }
    // Never allow a legacy backup to turn the retired floating controls back on.
    for (NSString *key in DYYYBackupExcludedKeys()) {
        if (![key isEqualToString:@"DYYYDebugInspectorEnabled"]) [defaults removeObjectForKey:key];
    }
    [settings enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
      id restored = DYYYBackupRestoreJSONSafeObject(value);
      if ([key hasPrefix:@"DYYY"] && !DYYYBackupIsLegacyKeyExcluded(key) && restored && restored != [NSNull null]) [defaults setObject:restored forKey:key];
    }];

    NSString *directory = DYYYBackupDirectory();
    NSFileManager *fileManager = NSFileManager.defaultManager;
    [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:error];
    for (NSString *name in DYYYBackupIconNames()) [fileManager removeItemAtPath:[directory stringByAppendingPathComponent:name] error:nil];
    __block NSUInteger iconTotal = 0;
    __block NSError *iconError = nil;
    [icons enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *encoded, BOOL *stop) {
      if (![DYYYBackupIconNames() containsObject:name] || ![encoded isKindOfClass:[NSString class]]) return;
      NSData *data = [[NSData alloc] initWithBase64EncodedString:encoded options:0];
      if (!data || data.length == 0 || iconTotal + data.length > DYYYBackupMaxIconBytes) { iconError = [NSError errorWithDomain:@"DYYYBackup" code:5 userInfo:@{NSLocalizedDescriptionKey:@"图标数据无效或过大"}]; *stop = YES; return; }
      iconTotal += data.length;
      [data writeToFile:[directory stringByAppendingPathComponent:name] options:NSDataWritingAtomic error:&iconError];
      if (iconError) *stop = YES;
    }];
    if (iconError) { if (error) *error = iconError; return NO; }
    [defaults synchronize];
    return YES;
}

@interface DYYYBackupToolsPickerDelegate : NSObject <UIDocumentPickerDelegate>
@property (nonatomic, copy) void (^completion)(NSURL *url);
@end

@implementation DYYYBackupToolsPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (self.completion) self.completion(urls.firstObject);
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    if (self.completion) self.completion(nil);
}
@end

static void DYYYBackupPresentPicker(UIViewController *presenter, UIDocumentPickerViewController *picker, void (^completion)(NSURL *url)) {
    DYYYBackupToolsPickerDelegate *delegate = [DYYYBackupToolsPickerDelegate new];
    delegate.completion = completion;
    picker.delegate = delegate;
    objc_setAssociatedObject(picker, &kDYYYBackupPickerDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [presenter presentViewController:picker animated:YES completion:nil];
}

static void DYYYBackupShowToast(UIViewController *presenter, NSString *message) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static void DYYYBackupImportURL(UIViewController *presenter, NSURL *url) {
    NSError *readError = nil;
    NSDictionary *input = DYYYBackupReadPayload(url, &readError);
    NSDictionary *normalized = input ? DYYYBackupNormalizedPayload(input, &readError) : nil;
    if (!normalized) {
        DYYYBackupShowToast(presenter, readError.localizedDescription ?: @"无法读取备份文件");
        return;
    }
    NSUInteger settingCount = [normalized[@"settings"] count];
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"恢复设置" message:[NSString stringWithFormat:@"将导入 %lu 项设置并覆盖当前设置。恢复前会自动保存当前状态，可使用“撤销上次恢复”还原。", (unsigned long)settingCount] preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"恢复" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
      NSError *applyError = nil;
      BOOL success = DYYYBackupApplyNormalizedPayload(normalized, YES, &applyError);
      DYYYBackupShowToast(presenter, success ? @"设置已恢复，请重启抖音使全部更改生效" : (applyError.localizedDescription ?: @"恢复失败"));
    }]];
    [presenter presentViewController:confirm animated:YES completion:nil];
}

void DYYYBackupExportSettings(UIViewController *presenter) {
    if (!presenter) return;
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:DYYYBackupDirectory() withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *file = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_Backup_%@.json", DYYY_NAME, @((long long)(NSDate.date.timeIntervalSince1970))]];
    if (!DYYYBackupWritePayload(DYYYBackupCurrentPayload(), file, &error)) { DYYYBackupShowToast(presenter, error.localizedDescription ?: @"备份失败"); return; }
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[[NSURL fileURLWithPath:file]] asCopy:YES];
    DYYYBackupPresentPicker(presenter, picker, ^(__unused NSURL *url) { DYYYBackupShowToast(presenter, @"备份已导出"); });
}

void DYYYBackupImportSettings(UIViewController *presenter) {
    if (!presenter) return;
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.json", @"public.text"] inMode:UIDocumentPickerModeImport];
    picker.allowsMultipleSelection = NO;
    DYYYBackupPresentPicker(presenter, picker, ^(NSURL *url) { if (url) DYYYBackupImportURL(presenter, url); });
}

void DYYYBackupUndoRestore(UIViewController *presenter) {
    if (!presenter) return;
    NSURL *url = [NSURL fileURLWithPath:DYYYBackupUndoPath()];
    NSError *error = nil;
    NSDictionary *payload = DYYYBackupReadPayload(url, &error);
    NSDictionary *normalized = payload ? DYYYBackupNormalizedPayload(payload, &error) : nil;
    if (!normalized) { DYYYBackupShowToast(presenter, @"没有可撤销的恢复记录"); return; }
    BOOL success = DYYYBackupApplyNormalizedPayload(normalized, NO, &error);
    DYYYBackupShowToast(presenter, success ? @"已撤销上次恢复，请重启抖音使全部更改生效" : (error.localizedDescription ?: @"撤销失败"));
}

void DYYYBackupResetSettings(UIViewController *presenter) {
    if (!presenter) return;
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"恢复默认设置" message:[NSString stringWithFormat:@"将清除 %@ 插件设置和自定义图标；操作前会创建撤销备份。", DYYY_NAME] preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"恢复默认" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
      NSDictionary *empty = @{ @"settings" : @{}, @"icons" : @{} };
      NSError *error = nil;
      BOOL success = DYYYBackupApplyNormalizedPayload(empty, YES, &error);
      DYYYBackupShowToast(presenter, success ? @"已恢复默认设置，请重启抖音" : (error.localizedDescription ?: @"恢复失败"));
    }]];
    [presenter presentViewController:confirm animated:YES completion:nil];
}
