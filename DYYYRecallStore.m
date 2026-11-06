#import "DYYYRecallStore.h"
#import "DYYYRecallPolicy.h"
#import <sqlite3.h>
#import <TargetConditionals.h>
#import <ImageIO/ImageIO.h>
#import <AVFoundation/AVFoundation.h>

@interface DYYYRecallStore ()
@property (nonatomic, strong) NSURL *directory;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) sqlite3 *database;
@property (nonatomic, copy) NSString *failure;
@end
@implementation DYYYRecallStore
- (instancetype)initWithDirectory:(NSURL *)directory {
    if ((self = [super init])) {
        _directory = directory; _queue = dispatch_queue_create("com.dyads.recall.store", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
- (BOOL)open {
    if (self.database) return YES;
    NSError *error = nil;
    if (!self.directory.isFileURL || ![NSFileManager.defaultManager createDirectoryAtURL:self.directory withIntermediateDirectories:YES attributes:nil error:&error]) { self.failure = @"无法创建留存目录"; return NO; }
    [self.directory setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
#if TARGET_OS_IPHONE
    [NSFileManager.defaultManager setAttributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} ofItemAtPath:self.directory.path error:nil];
#endif
    sqlite3 *database = NULL;
    if (sqlite3_open_v2([[self.directory URLByAppendingPathComponent:@"records.sqlite"] fileSystemRepresentation], &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, NULL) != SQLITE_OK) {
        if (database) sqlite3_close(database); self.failure = @"无法打开本地留存库"; return NO;
    }
    self.database = database; sqlite3_busy_timeout(database, 1500);
    const char *sql = "PRAGMA journal_mode=WAL; CREATE TABLE IF NOT EXISTS records (key TEXT PRIMARY KEY, account TEXT NOT NULL, conversation TEXT NOT NULL, message TEXT NOT NULL, server TEXT NOT NULL DEFAULT '', recalled INTEGER NOT NULL DEFAULT 0, payload BLOB NOT NULL); CREATE INDEX IF NOT EXISTS recall_lookup ON records(account,conversation,server); CREATE TABLE IF NOT EXISTS media (key TEXT NOT NULL, source TEXT NOT NULL, relative TEXT NOT NULL, bytes INTEGER NOT NULL, PRIMARY KEY(key,source)); CREATE TABLE IF NOT EXISTS forgotten (key TEXT PRIMARY KEY);";
    if (sqlite3_exec(database, sql, NULL, NULL, NULL) != SQLITE_OK) { self.failure = @"留存库初始化失败"; sqlite3_close(database); self.database = NULL; return NO; }
    return YES;
}
- (void)bind:(NSString *)text at:(int)index statement:(sqlite3_stmt *)statement { sqlite3_bind_text(statement, index, (text ?: @"").UTF8String, -1, SQLITE_TRANSIENT); }
- (NSDictionary *)readAccount:(NSString *)account conversation:(NSString *)conversation message:(NSString *)message server:(NSString *)server {
    if (![self open]) return nil;
    if(![server isKindOfClass:NSString.class] || [server isEqual:@"0"])server=@"";
    sqlite3_stmt *statement = NULL;
    const char *sql = "SELECT payload FROM records WHERE account=? AND conversation=? AND (message=? OR (server<>'' AND server=?)) ORDER BY recalled DESC LIMIT 1";
    if (sqlite3_prepare_v2(self.database, sql, -1, &statement, NULL) != SQLITE_OK) return nil;
    [self bind:account at:1 statement:statement]; [self bind:conversation at:2 statement:statement]; [self bind:message at:3 statement:statement]; [self bind:server at:4 statement:statement];
    NSDictionary *record = nil;
    if (sqlite3_step(statement) == SQLITE_ROW) {
        const void *bytes = sqlite3_column_blob(statement, 0); int size = sqlite3_column_bytes(statement, 0);
        if (bytes && size > 0 && size <= 300 * 1024) {
            id value = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:bytes length:size] options:0 error:nil];
            if ([value isKindOfClass:NSDictionary.class]) record = value;
        }
    }
    sqlite3_finalize(statement);
    if (record) {
        NSString *key = [DYYYRecallPolicy keyForAccount:account conversation:conversation message:record[@"message"]];
        NSMutableDictionary *paths = [NSMutableDictionary dictionary];
        statement = NULL;
        if (sqlite3_prepare_v2(self.database, "SELECT source,relative,bytes FROM media WHERE key=? LIMIT 8", -1, &statement, NULL) == SQLITE_OK) {
            [self bind:key at:1 statement:statement];
            while (sqlite3_step(statement) == SQLITE_ROW) {
                const char *source = (const char *)sqlite3_column_text(statement,0), *relative = (const char *)sqlite3_column_text(statement,1);
                if (!source || !relative) continue;
                NSString *name = [NSString stringWithUTF8String:relative];
                if (![name hasPrefix:@"Media/"] || [name.pathComponents containsObject:@".."]) continue;
                NSString *path = [self.directory.path stringByAppendingPathComponent:name];
                unsigned long long size = [[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil] fileSize];
                if (size && size == (unsigned long long)sqlite3_column_int64(statement,2)) paths[[NSString stringWithUTF8String:source]] = path;
            }
            sqlite3_finalize(statement);
        }
        NSMutableDictionary *result = [record mutableCopy]; result[@"media"] = paths; record = result;
    }
    return record;
}
- (void)saveRecord:(NSDictionary *)record completion:(void (^)(NSDictionary *, NSString *))completion {
    dispatch_async(self.queue, ^{
        NSString *account = record[@"account"], *conversation = record[@"conversation"], *message = record[@"message"];
        NSString *key = [DYYYRecallPolicy keyForAccount:account conversation:conversation message:message];
        if (!key || ![self open]) { if (completion) completion(nil, self.failure ?: @"消息身份不完整"); return; }
        NSDictionary *old = [self readAccount:account conversation:conversation message:message server:record[@"server"]];
        NSMutableDictionary *saved = old ? [old mutableCopy] : [record mutableCopy];
        [saved removeObjectForKey:@"media"];
        for (NSString *field in @[@"server", @"kind", @"uiClass"])
            if ([record[field] isKindOfClass:NSString.class] && [record[field] length]) saved[field] = record[field];
        sqlite3_stmt *forgotten = NULL;
        BOOL wasCleared = NO;
        if (sqlite3_prepare_v2(self.database, "SELECT 1 FROM forgotten WHERE key=? OR key=? LIMIT 1", -1, &forgotten, NULL) == SQLITE_OK) {
            [self bind:key at:1 statement:forgotten];
            [self bind:[DYYYRecallPolicy keyForAccount:account conversation:conversation message:record[@"server"]] at:2 statement:forgotten];
            wasCleared = sqlite3_step(forgotten) == SQLITE_ROW; sqlite3_finalize(forgotten);
        }
        if (wasCleared) { if (completion) completion(nil,@"该消息留存已由你清理，不重新归档"); return; }
        NSDictionary *content = [DYYYRecallPolicy contentSnapshot:record[@"content"]];
        if (old && ([old[@"recalled"] boolValue] || !content)) {
            saved = [old mutableCopy];
            for (NSString *field in @[@"server", @"kind", @"uiClass"]) if ([record[field] isKindOfClass:NSString.class] && [record[field] length]) saved[field] = record[field];
        } else if (content) saved[@"content"] = content;
        if (![DYYYRecallPolicy contentSnapshot:saved[@"content"]]) { if (completion) completion(nil, @"未取得原内容"); return; }
        saved[@"recalled"] = @([old[@"recalled"] boolValue] || [record[@"recalled"] boolValue]);
        if (old[@"recalledAt"]) saved[@"recalledAt"] = old[@"recalledAt"];
        else if (record[@"recalledAt"]) saved[@"recalledAt"] = record[@"recalledAt"];
        if (old[@"message"]) saved[@"message"] = old[@"message"];
        key = [DYYYRecallPolicy keyForAccount:account conversation:conversation message:saved[@"message"]];
        sqlite3_stmt *statement = NULL;
        sqlite3_int64 count = 0;
        if (!old && sqlite3_prepare_v2(self.database, "SELECT COUNT(*) FROM records WHERE account=?", -1, &statement, NULL) == SQLITE_OK) {
            [self bind:account at:1 statement:statement]; if (sqlite3_step(statement) == SQLITE_ROW) count = sqlite3_column_int64(statement, 0); sqlite3_finalize(statement); statement = NULL;
        }
        if (!old && count >= 5000) { if (completion) completion(nil, @"本账号已达5000条留存上限，原记录保留"); return; }
        [saved removeObjectForKey:@"media"];
        NSData *data = [NSJSONSerialization dataWithJSONObject:saved options:0 error:nil];
        if (!data.length || data.length > 300 * 1024 || sqlite3_prepare_v2(self.database, "INSERT INTO records(key,account,conversation,message,server,recalled,payload) VALUES(?,?,?,?,?,?,?) ON CONFLICT(key) DO UPDATE SET server=excluded.server,recalled=excluded.recalled,payload=excluded.payload", -1, &statement, NULL) != SQLITE_OK) {
            if (completion) completion(nil, @"留存写入准备失败"); return;
        }
        [self bind:key at:1 statement:statement]; [self bind:account at:2 statement:statement]; [self bind:conversation at:3 statement:statement]; [self bind:saved[@"message"] at:4 statement:statement]; [self bind:saved[@"server"] at:5 statement:statement];
        sqlite3_bind_int(statement, 6, [saved[@"recalled"] boolValue]); sqlite3_bind_blob(statement, 7, data.bytes, (int)data.length, SQLITE_TRANSIENT);
        BOOL success = sqlite3_step(statement) == SQLITE_DONE; sqlite3_finalize(statement);
        if (completion) completion(success ? saved : nil, success ? nil : @"本地留存写入失败");
    });
}
- (void)recordForAccount:(NSString *)account conversation:(NSString *)conversation message:(NSString *)message server:(NSString *)server completion:(void (^)(NSDictionary *))completion {
    dispatch_async(self.queue, ^{ NSDictionary *record = [self readAccount:account conversation:conversation message:message server:server]; if (completion) completion(record); });
}
- (NSString *)validatedMediaExtension:(NSString *)path {
    NSURL *url=[NSURL fileURLWithPath:path];
    CGImageSourceRef image=CGImageSourceCreateWithURL((__bridge CFURLRef)url,NULL);
    if(image){
        BOOL complete=CGImageSourceGetStatus(image)==kCGImageStatusComplete && CGImageSourceGetCount(image)>0;
        NSString *type=(__bridge NSString *)CGImageSourceGetType(image);
        CGImageRef preview=complete?CGImageSourceCreateThumbnailAtIndex(image,0,(__bridge CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways:@YES,(__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize:@32}):NULL;
        CFRelease(image);
        if(!preview)return nil;CGImageRelease(preview);
        if([type containsString:@"jpeg"])return @"jpg";
        if([type containsString:@"gif"])return @"gif";
        if([type containsString:@"heic"] || [type containsString:@"heif"])return @"heic";
        if([type containsString:@"webp"])return @"webp";
        return @"png";
    }
    AVURLAsset *asset=[AVURLAsset URLAssetWithURL:url options:@{AVURLAssetPreferPreciseDurationAndTimingKey:@NO}];
    if(!asset.playable || !asset.tracks.count || !CMTIME_IS_NUMERIC(asset.duration) || CMTimeGetSeconds(asset.duration)<=0)return nil;
    if([asset tracksWithMediaType:AVMediaTypeVideo].count)return [path.pathExtension.lowercaseString isEqual:@"mov"]?@"mov":@"mp4";
    if([asset tracksWithMediaType:AVMediaTypeAudio].count){NSString *ext=path.pathExtension.lowercaseString;return [@[@"mp3",@"aac",@"amr",@"wav",@"caf",@"m4a"] containsObject:ext]?ext:@"m4a";}
    return nil;
}
- (void)copyMediaAtPath:(NSString *)source record:(NSDictionary *)record completion:(void (^)(NSDictionary *, NSString *))completion {
    dispatch_async(self.queue, ^{
        NSString *key = [DYYYRecallPolicy keyForAccount:record[@"account"] conversation:record[@"conversation"] message:record[@"message"]];
        if (!key || ![self open]) { if (completion) completion(nil, @"消息身份未就绪"); return; }
        NSDictionary *storedRecord = [self readAccount:record[@"account"] conversation:record[@"conversation"] message:record[@"message"] server:record[@"server"]];
        if (!storedRecord) { if (completion) completion(nil,@"原消息记录未保存，不单独复制媒体"); return; }
        key = [DYYYRecallPolicy keyForAccount:storedRecord[@"account"] conversation:storedRecord[@"conversation"] message:storedRecord[@"message"]];
        NSString *path = source.stringByStandardizingPath.stringByResolvingSymlinksInPath;
        NSString *home = NSHomeDirectory().stringByResolvingSymlinksInPath;
        NSString *sourceKey=source.stringByStandardizingPath;
        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
        unsigned long long size = [attributes fileSize];
        if (![path hasPrefix:[home stringByAppendingString:@"/"]] || [path hasPrefix:self.directory.path] || ![attributes[NSFileType] isEqual:NSFileTypeRegular] ||
            !size || size > 64 * 1024 * 1024) { if (completion) completion(nil, @"未取得完整的本机媒体文件"); return; }
        NSString *extension=[self validatedMediaExtension:path];
        if(!extension){if(completion)completion(nil,@"媒体尚不能解码，未标记为已保存");return;}
        sqlite3_stmt *statement = NULL;
        if (sqlite3_prepare_v2(self.database, "SELECT relative,bytes FROM media WHERE key=? AND source=?", -1, &statement, NULL) == SQLITE_OK) {
            [self bind:key at:1 statement:statement]; [self bind:sourceKey at:2 statement:statement];
            if (sqlite3_step(statement) == SQLITE_ROW) {
                const unsigned char *text = sqlite3_column_text(statement, 0);
                NSString *relative = text ? [NSString stringWithUTF8String:(const char *)text] : nil;
                NSString *existing = relative ? [[self.directory URLByAppendingPathComponent:relative] path] : nil;
                unsigned long long storedSize=(unsigned long long)sqlite3_column_int64(statement,1);
                if (existing && storedSize && [[NSFileManager.defaultManager attributesOfItemAtPath:existing error:nil] fileSize] == storedSize) {
                    sqlite3_finalize(statement); if (completion) completion(@{@"source":sourceKey,@"path":existing,@"bytes":@(storedSize)},nil); return;
                }
            }
            sqlite3_finalize(statement); statement = NULL;
        }
        sqlite3_int64 total = 0;
        if (sqlite3_prepare_v2(self.database, "SELECT COALESCE(SUM(bytes),0) FROM media", -1, &statement, NULL) == SQLITE_OK) {
            if (sqlite3_step(statement) == SQLITE_ROW) total = sqlite3_column_int64(statement, 0); sqlite3_finalize(statement); statement = NULL;
        }
        if (total + size > 512 * 1024 * 1024) { if (completion) completion(nil, @"媒体留存已达512MB上限，原副本保留"); return; }
        NSString *relative = [@"Media" stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:extension]];
        NSURL *destination = [self.directory URLByAppendingPathComponent:relative];
        [NSFileManager.defaultManager createDirectoryAtURL:destination.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *temporary = [destination URLByAppendingPathExtension:@"part"];
        NSError *error = nil;
        BOOL copied = [NSFileManager.defaultManager copyItemAtPath:path toPath:temporary.path error:&error];
        unsigned long long after = [[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil] fileSize];
        unsigned long long actual = [[NSFileManager.defaultManager attributesOfItemAtPath:temporary.path error:nil] fileSize];
        if (!copied || after != size || actual != size || ![self validatedMediaExtension:temporary.path] || ![NSFileManager.defaultManager moveItemAtURL:temporary toURL:destination error:&error]) {
            [NSFileManager.defaultManager removeItemAtURL:temporary error:nil]; if (completion) completion(nil, @"文件未复制完整，未标记为已保存"); return;
        }
        BOOL stored = sqlite3_prepare_v2(self.database, "INSERT OR REPLACE INTO media(key,source,relative,bytes) VALUES(?,?,?,?)", -1, &statement, NULL) == SQLITE_OK;
        if (stored) {
            [self bind:key at:1 statement:statement]; [self bind:sourceKey at:2 statement:statement]; [self bind:relative at:3 statement:statement]; sqlite3_bind_int64(statement,4,(sqlite3_int64)size);
            stored = sqlite3_step(statement) == SQLITE_DONE; sqlite3_finalize(statement);
        }
        if (!stored) { [NSFileManager.defaultManager removeItemAtURL:destination error:nil]; if (completion) completion(nil,@"媒体索引写入失败"); return; }
        if (completion) completion(@{@"source":sourceKey,@"path":destination.path,@"bytes":@(size)},nil);
    });
}
- (void)clearAccount:(NSString *)account completion:(void (^)(BOOL))completion {
    dispatch_async(self.queue, ^{
        if (![self open] || !account.length) { if (completion) completion(NO); return; }
        sqlite3_stmt *statement = NULL;
        NSMutableArray *files = [NSMutableArray array];
        if (sqlite3_prepare_v2(self.database,"SELECT relative FROM media WHERE key IN (SELECT key FROM records WHERE account=?)",-1,&statement,NULL)==SQLITE_OK) {
            [self bind:account at:1 statement:statement]; while(sqlite3_step(statement)==SQLITE_ROW) { const char *p=(const char *)sqlite3_column_text(statement,0); if(p)[files addObject:[NSString stringWithUTF8String:p]]; } sqlite3_finalize(statement);
        }
        BOOL success = sqlite3_exec(self.database,"BEGIN IMMEDIATE",NULL,NULL,NULL)==SQLITE_OK;
        for (NSString *sql in @[@"INSERT OR IGNORE INTO forgotten(key) SELECT key FROM records WHERE account=?",@"DELETE FROM media WHERE key IN (SELECT key FROM records WHERE account=?)",@"DELETE FROM records WHERE account=?"]) {
            statement=NULL;
            if (success && sqlite3_prepare_v2(self.database,sql.UTF8String,-1,&statement,NULL)==SQLITE_OK) {
                [self bind:account at:1 statement:statement]; success=sqlite3_step(statement)==SQLITE_DONE; sqlite3_finalize(statement);
            } else success=NO;
        }
        int finalResult=sqlite3_exec(self.database,success?"COMMIT":"ROLLBACK",NULL,NULL,NULL);
        if(success && finalResult!=SQLITE_OK){success=NO;sqlite3_exec(self.database,"ROLLBACK",NULL,NULL,NULL);}
        if(success)for(NSString *relative in files)[NSFileManager.defaultManager removeItemAtURL:[self.directory URLByAppendingPathComponent:relative] error:nil];
        if(completion)completion(success);
    });
}
- (void)statisticsForAccount:(NSString *)account completion:(void (^)(NSDictionary *))completion {
    dispatch_async(self.queue, ^{
        if(![self open]){if(completion)completion(@{@"error":self.failure?:@"打开失败"});return;}
        sqlite3_stmt *statement=NULL; sqlite3_int64 count=0,recalled=0,bytes=0;
        if(sqlite3_prepare_v2(self.database,"SELECT COUNT(*),COALESCE(SUM(recalled),0) FROM records WHERE account=?",-1,&statement,NULL)==SQLITE_OK){[self bind:account at:1 statement:statement];if(sqlite3_step(statement)==SQLITE_ROW){count=sqlite3_column_int64(statement,0);recalled=sqlite3_column_int64(statement,1);}sqlite3_finalize(statement);}
        if(sqlite3_prepare_v2(self.database,"SELECT COALESCE(SUM(bytes),0) FROM media WHERE key IN (SELECT key FROM records WHERE account=?)",-1,&statement,NULL)==SQLITE_OK){[self bind:account at:1 statement:statement];if(sqlite3_step(statement)==SQLITE_ROW)bytes=sqlite3_column_int64(statement,0);sqlite3_finalize(statement);}
        if(completion)completion(@{@"records":@(count),@"recalled":@(recalled),@"mediaBytes":@(bytes)});
    });
}
- (void)dealloc { if(_database)sqlite3_close(_database); }
@end
