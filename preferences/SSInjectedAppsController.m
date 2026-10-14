#import "SSInjectedAppsController.h"
#import "SSPrefsCommon.h"
#import <spawn.h>
#import <signal.h>

@interface SSInjectedAppsController ()
@property (nonatomic, copy) NSString *selectedBundleID;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *realInjectedApps;
@property (nonatomic, strong) NSMutableDictionary *appConfig;
@end

@implementation SSInjectedAppsController

- (NSString *)beaconsDirectory {
    NSArray *candidates = @[
        @"/var/jb/var/mobile/Library/Application Support/StoreSwitcher/injected_beacons",
        @"/var/mobile/Library/Application Support/StoreSwitcher/injected_beacons"
    ];
    for (NSString *p in candidates) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
            return p;
        }
    }
    NSString *base = @"/var/mobile/Library/Application Support/StoreSwitcher/injected_beacons";
    [[NSFileManager defaultManager] createDirectoryAtPath:base withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0755} error:nil];
    return base;
}

- (void)scanRealInjectedApps {
    _realInjectedApps = [NSMutableArray array];
    NSString *dir = [self beaconsDirectory];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:dir error:nil];

    for (NSString *file in files) {
        if ([file hasSuffix:@".json"]) {
            NSString *filePath = [dir stringByAppendingPathComponent:file];
            NSData *data = [NSData dataWithContentsOfFile:filePath];
            if (data) {
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([dict isKindOfClass:[NSDictionary class]] && dict[@"bundleID"]) {
                    NSMutableDictionary *mutableApp = [dict mutableCopy];
                    
                    // Kiểm tra PID thực tế
                    pid_t pid = [dict[@"pid"] intValue];
                    BOOL isAlive = (pid > 0 && kill(pid, 0) == 0);
                    mutableApp[@"isAlive"] = @(isAlive);
                    
                    [_realInjectedApps addObject:mutableApp];
                }
            }
        }
    }

    if (!_selectedBundleID && _realInjectedApps.count > 0) {
        _selectedBundleID = _realInjectedApps.firstObject[@"bundleID"];
    }
}

- (id)specifiers {
    if (!_specifiers) {
        [self scanRealInjectedApps];
        NSMutableArray *specs = [NSMutableArray array];

        // Nhóm 1: Danh sách app thực tế đã tiêm dylib
        PSSpecifier *grp1 = [PSSpecifier groupSpecifierWithName:@"DANH SÁCH APP ĐÃ TIÊM APPAGEENT.DYLIB (BÁO VỀ THẬT)"];
        [grp1 setProperty:@"Chỉ hiển thị các ứng dụng đã thực sự load AppAgent.dylib và gửi beacon xác nhận về tweak. Tuyệt đối không lấy danh sách bừa." forKey:@"footerText"];
        [specs addObject:grp1];

        if (_realInjectedApps.count == 0) {
            PSSpecifier *emptySpec = [PSSpecifier preferenceSpecifierNamed:@"⚠️ Chưa có app nào tiêm dylib báo về"
                                                                    target:self set:NULL get:NULL detail:Nil
                                                                      cell:PSTitleValueCell edit:Nil];
            [specs addObject:emptySpec];

            PSSpecifier *guideSpec = [PSSpecifier preferenceSpecifierNamed:@"(Hãy tiêm AppAgent.dylib qua TrollFools & mở app)"
                                                                    target:self set:NULL get:NULL detail:Nil
                                                                      cell:PSTitleValueCell edit:Nil];
            [specs addObject:guideSpec];
        } else {
            for (NSDictionary *app in _realInjectedApps) {
                BOOL isSel = [self.selectedBundleID isEqualToString:app[@"bundleID"]];
                BOOL isAlive = [app[@"isAlive"] boolValue];
                
                NSString *iconState = isAlive ? @"🟢" : @"⚪";
                NSString *title = [NSString stringWithFormat:@"%@%@ %@ (PID: %@)", 
                                   isSel ? @"✓ " : @"", 
                                   iconState, 
                                   app[@"displayName"] ?: app[@"bundleID"],
                                   app[@"pid"]];

                PSSpecifier *appSpec = [PSSpecifier preferenceSpecifierNamed:title
                                                                      target:self set:NULL get:NULL detail:Nil
                                                                        cell:PSButtonCell edit:Nil];
                [appSpec setProperty:app[@"bundleID"] forKey:@"bundleID"];
                [appSpec setButtonAction:@selector(selectAppFromList:)];
                [specs addObject:appSpec];
            }
        }

        // Nút quét lại
        PSSpecifier *btnRescan = [PSSpecifier preferenceSpecifierNamed:@"🔄 Quét Lại Danh Sách App Đang Chạy"
                                                                target:self set:NULL get:NULL detail:Nil
                                                                  cell:PSButtonCell edit:Nil];
        [btnRescan setButtonAction:@selector(rescanTapped:)];
        [specs addObject:btnRescan];

        // Nếu có app được chọn, hiển thị thông tin thực tế của app đó
        NSDictionary *selectedApp = nil;
        for (NSDictionary *a in _realInjectedApps) {
            if ([a[@"bundleID"] isEqualToString:self.selectedBundleID]) {
                selectedApp = a;
                break;
            }
        }

        if (selectedApp) {
            PSSpecifier *grpDetail = [PSSpecifier groupSpecifierWithName:[NSString stringWithFormat:@"THÔNG TIN THỰC TẾ: %@", selectedApp[@"displayName"]]];
            NSString *footer = [NSString stringWithFormat:@"Bundle ID: %@\nSandbox: %@\nReceipt: %@", 
                                selectedApp[@"bundleID"], 
                                selectedApp[@"sandboxPath"],
                                [selectedApp[@"hasStoreKitReceipt"] boolValue] ? @"Đã có receipt hợp lệ" : @"Chưa có receipt"];
            [grpDetail setProperty:footer forKey:@"footerText"];
            [specs addObject:grpDetail];

            PSSpecifier *specPID = [PSSpecifier preferenceSpecifierNamed:@"PID Tiến Trình Thật"
                                                                  target:self set:NULL get:@selector(getSelectedPID:) detail:Nil
                                                                    cell:PSTitleValueCell edit:Nil];
            [specs addObject:specPID];

            PSSpecifier *specVer = [PSSpecifier preferenceSpecifierNamed:@"Phiên Bản App"
                                                                  target:self set:NULL get:@selector(getSelectedVersion:) detail:Nil
                                                                    cell:PSTitleValueCell edit:Nil];
            [specs addObject:specVer];

            PSSpecifier *specIPC = [PSSpecifier preferenceSpecifierNamed:@"Cổng Điều Khiển IPC Ngầm"
                                                                  target:self set:NULL get:@selector(getSelectedIPC:) detail:Nil
                                                                    cell:PSTitleValueCell edit:Nil];
            [specs addObject:specIPC];

            // Nhóm 2: Các nút TEST kiểm tra lưu thông 2 chiều Tweak <-> Dylib
            PSSpecifier *grpTest = [PSSpecifier groupSpecifierWithName:@"KIỂM TRA LƯU THÔNG TWEAK <-> DYLIB (LIVE TEST)"];
            [grpTest setProperty:@"Bấm nút để gửi lệnh thực tế qua socket IPC vào AppAgent.dylib và theo dõi phản hồi trên Terminal Console." forKey:@"footerText"];
            [specs addObject:grpTest];

            PSSpecifier *btnPing = [PSSpecifier preferenceSpecifierNamed:@"▶︎ 1. Test Ping IPC Socket (GET /status)"
                                                                  target:self set:NULL get:NULL detail:Nil
                                                                    cell:PSButtonCell edit:Nil];
            [btnPing setButtonAction:@selector(testPingIPCAction:)];
            [specs addObject:btnPing];

            PSSpecifier *btnPackets = [PSSpecifier preferenceSpecifierNamed:@"▶︎ 2. Test Bắt Packet Mạng / StoreKit (/packets)"
                                                                     target:self set:NULL get:NULL detail:Nil
                                                                       cell:PSButtonCell edit:Nil];
            [btnPackets setButtonAction:@selector(testFetchPacketsAction:)];
            [specs addObject:btnPackets];

            PSSpecifier *btnDumpUI = [PSSpecifier preferenceSpecifierNamed:@"▶︎ 3. Test Trích Xuất Cây Giao Diện UI (/ui/dump)"
                                                                    target:self set:NULL get:NULL detail:Nil
                                                                      cell:PSButtonCell edit:Nil];
            [btnDumpUI setButtonAction:@selector(testDumpUIAction:)];
            [specs addObject:btnDumpUI];

            PSSpecifier *btnOpenURL = [PSSpecifier preferenceSpecifierNamed:@"▶︎ 4. Test Mở URL Scheme / Deeplink (/open-url)"
                                                                     target:self set:NULL get:NULL detail:Nil
                                                                       cell:PSButtonCell edit:Nil];
            [btnOpenURL setButtonAction:@selector(testOpenDeeplinkAction:)];
            [specs addObject:btnOpenURL];

            PSSpecifier *btnSimBuy = [PSSpecifier preferenceSpecifierNamed:@"▶︎ 5. Test Giả Lập Bấm Nút Mua In-App (/ui/click)"
                                                                    target:self set:NULL get:NULL detail:Nil
                                                                      cell:PSButtonCell edit:Nil];
            [btnSimBuy setButtonAction:@selector(testSimulatePurchaseAction:)];
            [specs addObject:btnSimBuy];

            PSSpecifier *btnRestart = [PSSpecifier preferenceSpecifierNamed:@"🔄 Khởi Động Lại App Mục Tiêu"
                                                                     target:self set:NULL get:NULL detail:Nil
                                                                       cell:PSButtonCell edit:Nil];
            [btnRestart setButtonAction:@selector(restartTargetApp:)];
            [specs addObject:btnRestart];
        }

        _specifiers = specs;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = @"🎯 App Tiêm Dylib (Thực Tế)";
    [SSTerminalConsole attachToViewController:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [SSTerminalConsole attachToViewController:self];
}

#pragma mark - Lựa chọn App & Thông tin

- (void)selectAppFromList:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:@"bundleID"];
    if (bundleID) {
        self.selectedBundleID = bundleID;
        [SSTerminalConsole logAction:@"Chọn App" status:@"OK" details:[NSString stringWithFormat:@"Đã chuyển sang: %@", bundleID]];
        [self reloadSpecifiers];
    }
}

- (void)rescanTapped:(PSSpecifier *)specifier {
    [SSTerminalConsole logAction:@"Quét App" status:@"SCAN" details:@"Đang kiểm tra các file beacon trong injected_beacons/..."];
    _specifiers = nil;
    [self reloadSpecifiers];
    [SSTerminalConsole logAction:@"Quét App" status:@"DONE" details:[NSString stringWithFormat:@"Tìm thấy %lu app đã tiêm dylib", (unsigned long)_realInjectedApps.count]];
}

- (NSDictionary *)currentSelectedAppDict {
    for (NSDictionary *a in _realInjectedApps) {
        if ([a[@"bundleID"] isEqualToString:self.selectedBundleID]) {
            return a;
        }
    }
    return _realInjectedApps.firstObject;
}

- (id)getSelectedPID:(PSSpecifier *)specifier {
    NSDictionary *app = [self currentSelectedAppDict];
    if (!app) return @"N/A";
    BOOL alive = [app[@"isAlive"] boolValue];
    return [NSString stringWithFormat:@"%@ (%@)", app[@"pid"] ?: @"0", alive ? @"Đang chạy" : @"Đã dừng"];
}

- (id)getSelectedVersion:(PSSpecifier *)specifier {
    NSDictionary *app = [self currentSelectedAppDict];
    return app[@"version"] ?: @"1.0";
}

- (id)getSelectedIPC:(PSSpecifier *)specifier {
    NSDictionary *app = [self currentSelectedAppDict];
    return [NSString stringWithFormat:@"127.0.0.1:%@", app[@"ipcPort"] ?: @"9090"];
}

#pragma mark - Các Lệnh Test Thực Tế Qua IPC

- (void)testPingIPCAction:(PSSpecifier *)specifier {
    NSDictionary *app = [self currentSelectedAppDict];
    uint16_t port = [app[@"ipcPort"] intValue] ?: 9090;
    
    [SSTerminalConsole logAction:@"Ping IPC" status:@"SEND" details:[NSString stringWithFormat:@"GET http://127.0.0.1:%u/status", port]];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%u/status", port]];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        if (err) {
            [SSTerminalConsole logAction:@"Ping IPC" status:@"ERROR" details:err.localizedDescription];
        } else {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            [SSTerminalConsole logAction:@"Ping IPC" status:@"200 OK" details:[NSString stringWithFormat:@"App: %@ (PID: %@, System: %@)", json[@"appName"], json[@"pid"], json[@"systemVersion"]]];
        }
    }];
    [task resume];
}

- (void)testFetchPacketsAction:(PSSpecifier *)specifier {
    NSDictionary *app = [self currentSelectedAppDict];
    uint16_t port = [app[@"ipcPort"] intValue] ?: 9090;

    [SSTerminalConsole logAction:@"Lấy Packets" status:@"SEND" details:[NSString stringWithFormat:@"GET http://127.0.0.1:%u/packets", port]];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%u/packets", port]];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        if (err) {
            [SSTerminalConsole logAction:@"Lấy Packets" status:@"ERROR" details:err.localizedDescription];
        } else {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *packets = json[@"packets"];
            [SSTerminalConsole logAction:@"Lấy Packets" status:@"200 OK" details:[NSString stringWithFormat:@"Đã thu được %lu gói tin từ AppAgent (StoreKit, HTTPS, Deeplink)", (unsigned long)packets.count]];
            if (packets.count > 0) {
                NSDictionary *first = packets.firstObject;
                [SSTerminalConsole logAction:@"Packet Gần Nhất" status:@"INFO" details:[NSString stringWithFormat:@"URL: %@ | Loại: %@", first[@"url"], first[@"type"]]];
            }
        }
    }];
    [task resume];
}

- (void)testDumpUIAction:(PSSpecifier *)specifier {
    NSDictionary *app = [self currentSelectedAppDict];
    uint16_t port = [app[@"ipcPort"] intValue] ?: 9090;

    [SSTerminalConsole logAction:@"Soi Giao Diện" status:@"SEND" details:[NSString stringWithFormat:@"GET http://127.0.0.1:%u/ui/dump", port]];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%u/ui/dump", port]];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        if (err) {
            [SSTerminalConsole logAction:@"Soi Giao Diện" status:@"ERROR" details:err.localizedDescription];
        } else {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSDictionary *ui = json[@"ui"];
            [SSTerminalConsole logAction:@"Soi Giao Diện" status:@"200 OK" details:[NSString stringWithFormat:@"Root Class: %@ | Số phần tử con: %lu", ui[@"className"], (unsigned long)[ui[@"subviews"] count]]];
        }
    }];
    [task resume];
}

- (void)testOpenDeeplinkAction:(PSSpecifier *)specifier {
    NSDictionary *app = [self currentSelectedAppDict];
    uint16_t port = [app[@"ipcPort"] intValue] ?: 9090;

    NSString *testURL = @"itms-apps://apps.apple.com/account/subscriptions";
    [SSTerminalConsole logAction:@"Mở Deeplink" status:@"SEND" details:[NSString stringWithFormat:@"POST http://127.0.0.1:%u/open-url -> %@", port, testURL]];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%u/open-url", port]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{@"url": testURL} options:0 error:nil];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        if (err) {
            [SSTerminalConsole logAction:@"Mở Deeplink" status:@"ERROR" details:err.localizedDescription];
        } else {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            [SSTerminalConsole logAction:@"Mở Deeplink" status:@"200 OK" details:json[@"message"] ?: @"Đã mở URL thành công"];
        }
    }];
    [task resume];
}

- (void)testSimulatePurchaseAction:(PSSpecifier *)specifier {
    NSDictionary *app = [self currentSelectedAppDict];
    uint16_t port = [app[@"ipcPort"] intValue] ?: 9090;

    [SSTerminalConsole logAction:@"Giả Lập Bấm Nút" status:@"SEND" details:[NSString stringWithFormat:@"POST http://127.0.0.1:%u/ui/click (Mua / Subscribe)", port]];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%u/ui/click", port]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{@"keyword": @"Mua"} options:0 error:nil];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        if (err) {
            [SSTerminalConsole logAction:@"Giả Lập Bấm Nút" status:@"ERROR" details:err.localizedDescription];
        } else {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            [SSTerminalConsole logAction:@"Giả Lập Bấm Nút" status:@"200 OK" details:json[@"message"] ?: @"Đã thực thi bấm nút"];
        }
    }];
    [task resume];
}

- (void)restartTargetApp:(PSSpecifier *)specifier {
    NSDictionary *app = [self currentSelectedAppDict];
    pid_t pid = [app[@"pid"] intValue];
    if (pid > 0) {
        kill(pid, SIGKILL);
        [SSTerminalConsole logAction:@"Khởi Động Lại" status:@"KILL" details:[NSString stringWithFormat:@"Đã dừng tiến trình PID: %d", pid]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self rescanTapped:nil];
        });
    }
}

@end
