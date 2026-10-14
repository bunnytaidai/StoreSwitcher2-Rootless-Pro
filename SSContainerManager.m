#import "SSContainerManager.h"
#import "SSHeader.h"
#import <objc/runtime.h>
#import <spawn.h>

@implementation SSContainer

- (instancetype)init {
    self = [super init];
    if (self) {
        _identifier = [[NSUUID UUID] UUIDString];
        _name = @"Vùng chứa mới";
        _appleID = @"";
        _password = @"";
        _dsid = @"";
        _storeFrontID = @"";
        _isDefault = NO;
        _isolateSystemAccounts = YES;
        _preserveSandbox = YES;
        _isolatedKeychain = YES;
        _isolatedNotifications = YES;
        _lastUsedDate = [NSDate date];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"identifier": _identifier ?: @"",
        @"name": _name ?: @"",
        @"appleID": _appleID ?: @"",
        @"password": _password ?: @"",
        @"dsid": _dsid ?: @"",
        @"storeFrontID": _storeFrontID ?: @"",
        @"isDefault": @(_isDefault),
        @"isolateSystemAccounts": @(_isolateSystemAccounts),
        @"preserveSandbox": @(_preserveSandbox),
        @"isolatedKeychain": @(_isolatedKeychain),
        @"isolatedNotifications": @(_isolatedNotifications),
        @"lastUsedDate": @([_lastUsedDate timeIntervalSince1970])
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    SSContainer *c = [[SSContainer alloc] init];
    c.identifier = dict[@"identifier"] ?: [[NSUUID UUID] UUIDString];
    c.name = dict[@"name"] ?: @"Vùng chứa";
    c.appleID = dict[@"appleID"] ?: @"";
    c.password = dict[@"password"] ?: @"";
    c.dsid = dict[@"dsid"] ?: @"";
    c.storeFrontID = dict[@"storeFrontID"] ?: @"";
    c.isDefault = [dict[@"isDefault"] boolValue];
    c.isolateSystemAccounts = dict[@"isolateSystemAccounts"] ? [dict[@"isolateSystemAccounts"] boolValue] : YES;
    c.preserveSandbox = dict[@"preserveSandbox"] ? [dict[@"preserveSandbox"] boolValue] : YES;
    c.isolatedKeychain = dict[@"isolatedKeychain"] ? [dict[@"isolatedKeychain"] boolValue] : YES;
    c.isolatedNotifications = dict[@"isolatedNotifications"] ? [dict[@"isolatedNotifications"] boolValue] : YES;
    double ts = [dict[@"lastUsedDate"] doubleValue];
    if (ts > 0) {
        c.lastUsedDate = [NSDate dateWithTimeIntervalSince1970:ts];
    }
    return c;
}

@end

@implementation SSSavedAccount

- (instancetype)init {
    self = [super init];
    if (self) {
        _appleID = @"";
        _dsid = @"";
        _altDSID = @"";
        _storeFrontID = @"";
        _countryCode = @"VN";
        _lastUsedDate = [NSDate date];
        _isTrusted = YES;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"appleID": _appleID ?: @"",
        @"dsid": _dsid ?: @"",
        @"altDSID": _altDSID ?: @"",
        @"storeFrontID": _storeFrontID ?: @"",
        @"countryCode": _countryCode ?: @"",
        @"lastUsedDate": @([_lastUsedDate timeIntervalSince1970]),
        @"isTrusted": @(_isTrusted)
    };
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    SSSavedAccount *acc = [[SSSavedAccount alloc] init];
    acc.appleID = dict[@"appleID"] ?: @"";
    acc.dsid = dict[@"dsid"] ?: @"";
    acc.altDSID = dict[@"altDSID"] ?: @"";
    acc.storeFrontID = dict[@"storeFrontID"] ?: @"";
    acc.countryCode = dict[@"countryCode"] ?: @"VN";
    acc.isTrusted = dict[@"isTrusted"] ? [dict[@"isTrusted"] boolValue] : YES;
    double ts = [dict[@"lastUsedDate"] doubleValue];
    if (ts > 0) {
        acc.lastUsedDate = [NSDate dateWithTimeIntervalSince1970:ts];
    }
    return acc;
}

@end

@implementation SSContainerManager

+ (instancetype)sharedManager {
    static SSContainerManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SSContainerManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _enabled = YES;
        _isolateSystemAccounts = YES;
        _preserveSandboxData = YES;
        _isolateKeychain = YES;
        _isolateNotifications = YES;
        _killDaemonsOnSwitch = NO; // MẶC ĐỊNH LÀ NO ĐỂ KHÔNG PHÁ HỎNG TOKEN VÀ SESSION
        _wipeCachesOnSwitch = NO;
        _enable3DTouchShortcut = YES;
        _trustAccountsNoPrompt = YES;
        _containers = [NSMutableArray array];
        _savedAccounts = [NSMutableArray array];
        [self loadSettings];
        [self syncAccountsFromSystem];
    }
    return self;
}

- (NSString *)configDirectoryPath {
    NSArray *candidates = @[
        @"/var/jb/var/mobile/Library/Application Support/StoreSwitcher",
        @"/var/mobile/Library/Application Support/StoreSwitcher"
    ];
    for (NSString *p in candidates) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
            return p;
        }
    }
    NSString *basePath = @"/var/mobile/Library/Application Support/StoreSwitcher";
    [[NSFileManager defaultManager] createDirectoryAtPath:basePath withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0755} error:nil];
    return basePath;
}

- (NSString *)configFilePath {
    return [[self configDirectoryPath] stringByAppendingPathComponent:@"containers.plist"];
}

- (NSString *)vaultFilePath {
    return [[self configDirectoryPath] stringByAppendingPathComponent:@"accounts_vault.json"];
}

- (void)logActivity:(NSString *)message {
    NSString *logPath = [[self configDirectoryPath] stringByAppendingPathComponent:@"activity.log"];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    NSString *entry = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
    
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (handle) {
        [handle seekToEndOfFile];
        [handle writeData:[entry dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    } else {
        [entry writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

- (void)loadSettings {
    NSString *path = [self configFilePath];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    if (!dict) {
        NSString *rootlessPath = @"/var/jb/var/mobile/Library/Application Support/StoreSwitcher/containers.plist";
        dict = [NSDictionary dictionaryWithContentsOfFile:rootlessPath];
    }

    if (dict) {
        _enabled = dict[@"enabled"] ? [dict[@"enabled"] boolValue] : YES;
        _isolateSystemAccounts = dict[@"isolateSystemAccounts"] ? [dict[@"isolateSystemAccounts"] boolValue] : YES;
        _preserveSandboxData = dict[@"preserveSandboxData"] ? [dict[@"preserveSandboxData"] boolValue] : YES;
        _isolateKeychain = dict[@"isolateKeychain"] ? [dict[@"isolateKeychain"] boolValue] : YES;
        _isolateNotifications = dict[@"isolateNotifications"] ? [dict[@"isolateNotifications"] boolValue] : YES;
        _killDaemonsOnSwitch = dict[@"killDaemonsOnSwitch"] ? [dict[@"killDaemonsOnSwitch"] boolValue] : NO;
        _wipeCachesOnSwitch = dict[@"wipeCachesOnSwitch"] ? [dict[@"wipeCachesOnSwitch"] boolValue] : NO;
        _enable3DTouchShortcut = dict[@"enable3DTouchShortcut"] ? [dict[@"enable3DTouchShortcut"] boolValue] : YES;
        _trustAccountsNoPrompt = dict[@"trustAccountsNoPrompt"] ? [dict[@"trustAccountsNoPrompt"] boolValue] : YES;
        _activeContainerID = dict[@"activeContainerID"];
        _activeAppleID = dict[@"activeAppleID"];

        NSArray *arr = dict[@"containers"];
        [_containers removeAllObjects];
        if ([arr isKindOfClass:[NSArray class]]) {
            for (NSDictionary *d in arr) {
                [_containers addObject:[SSContainer fromDictionary:d]];
            }
        }
    }

    // Nạp Accounts Vault từ JSON
    NSString *vaultPath = [self vaultFilePath];
    NSData *vaultData = [NSData dataWithContentsOfFile:vaultPath];
    if (vaultData) {
        NSArray *jsonArr = [NSJSONSerialization JSONObjectWithData:vaultData options:0 error:nil];
        if ([jsonArr isKindOfClass:[NSArray class]]) {
            [_savedAccounts removeAllObjects];
            for (NSDictionary *d in jsonArr) {
                [_savedAccounts addObject:[SSSavedAccount fromDictionary:d]];
            }
        }
    }

    if (_containers.count == 0) {
        SSContainer *defaultContainer = [[SSContainer alloc] init];
        defaultContainer.identifier = @"default-container";
        defaultContainer.name = @"Vùng chứa mặc định";
        defaultContainer.isDefault = YES;
        [_containers addObject:defaultContainer];
        _activeContainerID = defaultContainer.identifier;
        [self saveSettings];
    }
}

- (void)saveSettings {
    NSMutableArray *arr = [NSMutableArray array];
    for (SSContainer *c in _containers) {
        [arr addObject:[c toDictionary]];
    }

    NSDictionary *dict = @{
        @"enabled": @(_enabled),
        @"isolateSystemAccounts": @(_isolateSystemAccounts),
        @"preserveSandboxData": @(_preserveSandboxData),
        @"isolateKeychain": @(_isolateKeychain),
        @"isolateNotifications": @(_isolateNotifications),
        @"killDaemonsOnSwitch": @(_killDaemonsOnSwitch),
        @"wipeCachesOnSwitch": @(_wipeCachesOnSwitch),
        @"enable3DTouchShortcut": @(_enable3DTouchShortcut),
        @"trustAccountsNoPrompt": @(_trustAccountsNoPrompt),
        @"activeContainerID": _activeContainerID ?: @"",
        @"activeAppleID": _activeAppleID ?: @"",
        @"containers": arr
    };

    [dict writeToFile:[self configFilePath] atomically:YES];

    // Lưu Accounts Vault
    NSMutableArray *vaultArr = [NSMutableArray array];
    for (SSSavedAccount *acc in _savedAccounts) {
        [vaultArr addObject:[acc toDictionary]];
    }
    NSData *vaultData = [NSJSONSerialization dataWithJSONObject:vaultArr options:NSJSONWritingPrettyPrinted error:nil];
    if (vaultData) {
        [vaultData writeToFile:[self vaultFilePath] atomically:YES];
    }
}

- (SSContainer *)activeContainer {
    for (SSContainer *c in _containers) {
        if ([c.identifier isEqualToString:_activeContainerID]) {
            return c;
        }
    }
    return _containers.firstObject;
}

- (SSContainer *)containerWithIdentifier:(NSString *)identifier {
    for (SSContainer *c in _containers) {
        if ([c.identifier isEqualToString:identifier]) {
            return c;
        }
    }
    return nil;
}

- (SSContainer *)createNewCleanContainerWithName:(NSString *)name {
    SSContainer *container = [[SSContainer alloc] init];
    if (name.length > 0) {
        container.name = name;
    } else {
        container.name = [NSString stringWithFormat:@"Vùng chứa #%lu", (unsigned long)(_containers.count + 1)];
    }
    container.appleID = @""; // Sạch sẽ, chưa gán nick nào
    container.preserveSandbox = _preserveSandboxData;
    container.isolatedKeychain = _isolateKeychain;
    container.isolatedNotifications = _isolateNotifications;

    [_containers addObject:container];
    [self saveSettings];
    [self logActivity:[NSString stringWithFormat:@"Đã tạo vùng chứa mới: %@", container.name]];
    return container;
}

- (void)deleteContainer:(SSContainer *)container {
    if (container.isDefault) {
        return;
    }
    [_containers removeObject:container];
    if ([_activeContainerID isEqualToString:container.identifier]) {
        _activeContainerID = _containers.firstObject.identifier;
    }
    [self saveSettings];
    [self logActivity:[NSString stringWithFormat:@"Đã xóa vùng chứa: %@", container.name]];
}

#pragma mark - Quản lý Kho Lưu Trữ Tài Khoản (Accounts Vault)

- (void)syncAccountsFromSystem {
    [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/StoreServices.framework"] load];
    Class storeClass = objc_getClass("SSAccountStore");
    if (!storeClass) return;

    SSAccountStore *store = [storeClass defaultStore];
    if (!store) return;

    NSArray *systemAccounts = [store accounts];
    BOOL hasChanges = NO;

    for (SSAccount *acc in systemAccounts) {
        if ([acc isLocalAccount]) continue;

        NSString *email = [acc accountName];
        if (email.length == 0) continue;

        NSString *dsid = [NSString stringWithFormat:@"%@", [acc uniqueIdentifier]];
        NSString *altDSID = [acc respondsToSelector:@selector(altDSID)] ? [acc altDSID] : @"";
        NSString *storeFront = [acc storeFrontIdentifier] ?: @"";

        // Kiểm tra xem đã có trong Vault chưa
        SSSavedAccount *found = nil;
        for (SSSavedAccount *saved in _savedAccounts) {
            if ([saved.appleID isEqualToString:email] || (dsid.length > 0 && [saved.dsid isEqualToString:dsid])) {
                found = saved;
                break;
            }
        }

        if (!found) {
            found = [[SSSavedAccount alloc] init];
            found.appleID = email;
            found.dsid = dsid;
            found.altDSID = altDSID;
            found.storeFrontID = storeFront;
            found.lastUsedDate = [NSDate date];
            [_savedAccounts addObject:found];
            hasChanges = YES;
            [self logActivity:[NSString stringWithFormat:@"[Vault] Đồng bộ tài khoản mới từ hệ thống: %@", email]];
        } else {
            if (storeFront.length > 0 && ![found.storeFrontID isEqualToString:storeFront]) {
                found.storeFrontID = storeFront;
                hasChanges = YES;
            }
        }

        if ([acc isActive]) {
            _activeAppleID = email;
            found.lastUsedDate = [NSDate date];
            SSContainer *activeC = [self activeContainer];
            if (activeC && activeC.appleID.length == 0) {
                activeC.appleID = email;
                activeC.dsid = dsid;
                activeC.storeFrontID = storeFront;
            }
        }
    }

    if (hasChanges) {
        [self saveSettings];
    }
}

- (void)saveAccountToVault:(NSString *)appleID dsid:(NSString *)dsid altDSID:(NSString *)altDSID storeFront:(NSString *)storeFront {
    if (appleID.length == 0) return;

    SSSavedAccount *found = nil;
    for (SSSavedAccount *saved in _savedAccounts) {
        if ([saved.appleID isEqualToString:appleID]) {
            found = saved;
            break;
        }
    }

    if (!found) {
        found = [[SSSavedAccount alloc] init];
        found.appleID = appleID;
        [_savedAccounts addObject:found];
    }

    found.dsid = dsid ?: found.dsid;
    found.altDSID = altDSID ?: found.altDSID;
    found.storeFrontID = storeFront ?: found.storeFrontID;
    found.lastUsedDate = [NSDate date];
    found.isTrusted = YES;

    [self saveSettings];
    [self logActivity:[NSString stringWithFormat:@"[Vault] Đã lưu thông tin tài khoản: %@", appleID]];
}

- (void)deleteAccountFromVault:(NSString *)appleID {
    SSSavedAccount *target = nil;
    for (SSSavedAccount *acc in _savedAccounts) {
        if ([acc.appleID isEqualToString:appleID]) {
            target = acc;
            break;
        }
    }
    if (target) {
        [_savedAccounts removeObject:target];
        [self saveSettings];
        [self logActivity:[NSString stringWithFormat:@"[Vault] Đã xóa tài khoản khỏi kho: %@", appleID]];
    }
}

#pragma mark - Chuyển đổi Tài khoản 1 chạm (Core StoreSwitcher Logic)

- (BOOL)switchToAccountWithAppleID:(NSString *)appleID error:(NSError **)error {
    if (appleID.length == 0) return NO;

    NSLog(@"[StoreSwitcher] >>> BẮT ĐẦU CHUYỂN ĐỔI SANG APPLE ID: %@", appleID);
    [self logActivity:[NSString stringWithFormat:@"Bắt đầu chuyển sang Apple ID: %@", appleID]];

    [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/StoreServices.framework"] load];
    Class storeClass = objc_getClass("SSAccountStore");
    if (!storeClass) return NO;

    SSAccountStore *store = [storeClass defaultStore];
    if (!store) return NO;

    NSArray *accounts = [store accounts];
    SSAccount *targetAccount = nil;

    for (SSAccount *acc in accounts) {
        if ([[acc accountName] isEqualToString:appleID]) {
            targetAccount = acc;
            break;
        }
    }

    if (targetAccount) {
        // Core Logic StoreSwitcher gốc:
        // Đặt tài khoản đích làm active mà KHÔNG xoá hoặc vô hiệu hoá các tài khoản khác
        [targetAccount setActive:YES];
        [targetAccount setAuthenticated:YES];

        if ([store respondsToSelector:@selector(setDefaultAccount:completionBlock:)]) {
            [store setDefaultAccount:targetAccount completionBlock:^(id resp, NSError *err) {
                if (err) {
                    NSLog(@"[StoreSwitcher] Lỗi setDefaultAccount: %@", err);
                }
            }];
        }

        [store saveAccount:targetAccount verifyCredentials:NO error:nil];

        // Cập nhật lại device storefront
        Class devClass = objc_getClass("SSDevice");
        if (devClass) {
            SSDevice *dev = [devClass currentDevice];
            if (dev && [dev respondsToSelector:@selector(reloadStoreFrontIdentifier)]) {
                [dev reloadStoreFrontIdentifier];
            }
        }

        self.activeAppleID = appleID;
        SSContainer *activeC = [self activeContainer];
        if (activeC) {
            activeC.appleID = appleID;
            activeC.dsid = [NSString stringWithFormat:@"%@", [targetAccount uniqueIdentifier]];
            activeC.storeFrontID = [targetAccount storeFrontIdentifier] ?: @"";
        }

        [self saveAccountToVault:appleID 
                            dsid:[NSString stringWithFormat:@"%@", [targetAccount uniqueIdentifier]]
                         altDSID:[targetAccount respondsToSelector:@selector(altDSID)] ? [targetAccount altDSID] : @""
                      storeFront:[targetAccount storeFrontIdentifier]];

        [self logActivity:[NSString stringWithFormat:@"Đã chuyển thành công sang Apple ID: %@", appleID]];
        return YES;
    } else {
        [self logActivity:[NSString stringWithFormat:@"Cảnh báo: Apple ID '%@' chưa có trong SSAccountStore (cần đăng nhập)", appleID]];
        return NO;
    }
}

#pragma mark - Chuyển đổi Vùng chứa (Containers)

- (BOOL)switchToContainer:(SSContainer *)targetContainer error:(NSError **)error {
    if (!targetContainer) return NO;

    [self logActivity:[NSString stringWithFormat:@"Chuyển đổi sang vùng chứa: %@", targetContainer.name]];

    targetContainer.lastUsedDate = [NSDate date];
    self.activeContainerID = targetContainer.identifier;
    [self saveSettings];

    // Chỉ thực hiện dọn dẹp nếu người dùng bật cấu hình
    if (self.killDaemonsOnSwitch) {
        [self terminateBackgroundDaemons];
    }
    if (self.wipeCachesOnSwitch) {
        [self wipeAppCaches];
    }

    // Nếu vùng chứa này có gắn Apple ID, kích hoạt Apple ID đó
    if (targetContainer.appleID.length > 0) {
        [self switchToAccountWithAppleID:targetContainer.appleID error:error];
    }

    return YES;
}

- (void)terminateBackgroundDaemons {
    // Chỉ restart AppStore nếu cần, không kill akd hay storeaccountd để tránh mất token
    NSLog(@"[StoreSwitcher] Tắt tiến trình AppStore để làm mới...");
    pid_t pid;
    char *argv[] = {"/usr/bin/killall", "-9", "AppStore", NULL};
    posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, argv, NULL);
}

- (void)wipeAppCaches {
    NSString *appStoreData = @"/var/mobile/Containers/Data/Application";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirs = [fm contentsOfDirectoryAtPath:appStoreData error:nil];
    for (NSString *dir in dirs) {
        NSString *tmpPath = [appStoreData stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/tmp", dir]];
        if ([fm fileExistsAtPath:tmpPath]) {
            NSArray *files = [fm contentsOfDirectoryAtPath:tmpPath error:nil];
            for (NSString *f in files) {
                [fm removeItemAtPath:[tmpPath stringByAppendingPathComponent:f] error:nil];
            }
        }
    }
}

@end
