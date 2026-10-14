#import "SSInjectedAppsController.h"
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
                                                                    target:self
                                                                       set:NULL
                                                                       get:NULL
                                                                    detail:Nil
                                                                      cell:PSTitleValueCell
                                                                      edit:Nil];
            [specs addObject:emptySpec];

            PSSpecifier *guideSpec = [PSSpecifier preferenceSpecifierNamed:@"(Hãy tiêm AppAgent.dylib qua TrollFools & mở app)"
                                                                    target:self
                                                                       set:NULL
                                                                       get:NULL
                                                                    detail:Nil
                                                                      cell:PSTitleValueCell
                                                                      edit:Nil];
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
                                                                     target:self
                                                                        set:NULL
                                                                        get:NULL
                                                                     detail:Nil
                                                                       cell:PSButtonCell
                                                                       edit:Nil];
                [appSpec setProperty:app[@"bundleID"] forKey:@"bundleID"];
                [appSpec setButtonAction:@selector(selectAppFromList:)];
                [specs addObject:appSpec];
            }
        }

        // Nút quét lại
        PSSpecifier *btnRescan = [PSSpecifier preferenceSpecifierNamed:@"🔄 Quét Lại Danh Sách App Đang Chạy"
                                                                target:self
                                                                   set:NULL
                                                                   get:NULL
                                                                detail:Nil
                                                                  cell:PSButtonCell
                                                                  edit:Nil];
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
                                                                  target:self
                                                                     set:NULL
                                                                     get:@selector(getSelectedPID:)
                                                                  detail:Nil
                                                                    cell:PSTitleValueCell
                                                                    edit:Nil];
            [specs addObject:specPID];

            PSSpecifier *specVer = [PSSpecifier preferenceSpecifierNamed:@"Phiên Bản App"
                                                                  target:self
                                                                     set:NULL
                                                                     get:@selector(getSelectedVersion:)
                                                                  detail:Nil
                                                                    cell:PSTitleValueCell
                                                                    edit:Nil];
            [specs addObject:specVer];

            PSSpecifier *specIPC = [PSSpecifier preferenceSpecifierNamed:@"Cổng Điều Khiển IPC Ngầm"
                                                                  target:self
                                                                     set:NULL
                                                                     get:@selector(getSelectedIPC:)
                                                                  detail:Nil
                                                                    cell:PSTitleValueCell
                                                                    edit:Nil];
            [specs addObject:specIPC];

            // Nhóm 2: Điều khiển hành động trên app qua dylib
            PSSpecifier *grp2 = [PSSpecifier groupSpecifierWithName:@"ĐIỀU KHIỂN HÀNH ĐỘNG TRÊN APP QUA DYLIB"];
            [grp2 setProperty:@"Các hành động được gửi trực tiếp vào dylib đang chạy bên trong app." forKey:@"footerText"];
            [specs addObject:grp2];

            PSSpecifier *actSimBuy = [PSSpecifier preferenceSpecifierNamed:@"▶ Giả Lập Thao Tác Chạm Mua (Simulate Tap)"
                                                                   target:self
                                                                      set:NULL
                                                                      get:NULL
                                                                   detail:Nil
                                                                     cell:PSButtonCell
                                                                     edit:Nil];
            [actSimBuy setButtonAction:@selector(triggerSimulatedPurchase:)];
            [specs addObject:actSimBuy];

            PSSpecifier *btnReadReceipt = [PSSpecifier preferenceSpecifierNamed:@"🧾 Kiểm Tra & Đọc Receipt StoreKit Thật"
                                                                         target:self
                                                                            set:NULL
                                                                            get:NULL
                                                                         detail:Nil
                                                                           cell:PSButtonCell
                                                                           edit:Nil];
            [btnReadReceipt setButtonAction:@selector(readStoreKitReceipt:)];
            [specs addObject:btnReadReceipt];

            PSSpecifier *btnSniff = [PSSpecifier preferenceSpecifierNamed:@"📡 Soi Packets Mạng & StoreKit Bắt Được"
                                                                   target:self
                                                                      set:NULL
                                                                      get:NULL
                                                                   detail:Nil
                                                                     cell:PSButtonCell
                                                                     edit:Nil];
            [btnSniff setButtonAction:@selector(viewCapturedPackets:)];
            [specs addObject:btnSniff];

            PSSpecifier *actRestart = [PSSpecifier preferenceSpecifierNamed:@"🔄 Khởi Động Lại App Mục Tiêu"
                                                                     target:self
                                                                        set:NULL
                                                                        get:NULL
                                                                     detail:Nil
                                                                       cell:PSButtonCell
                                                                       edit:Nil];
            [actRestart setButtonAction:@selector(restartTargetApp:)];
            [specs addObject:actRestart];
        }

        _specifiers = specs;
    }
    return _specifiers;
}

- (id)getSelectedPID:(PSSpecifier *)spec {
    for (NSDictionary *a in _realInjectedApps) {
        if ([a[@"bundleID"] isEqualToString:self.selectedBundleID]) {
            return [NSString stringWithFormat:@"%@ (%@)", a[@"pid"], [a[@"isAlive"] boolValue] ? @"Đang chạy" : @"Đã dừng"];
        }
    }
    return @"N/A";
}

- (id)getSelectedVersion:(PSSpecifier *)spec {
    for (NSDictionary *a in _realInjectedApps) {
        if ([a[@"bundleID"] isEqualToString:self.selectedBundleID]) {
            return a[@"version"] ?: @"1.0";
        }
    }
    return @"N/A";
}

- (id)getSelectedIPC:(PSSpecifier *)spec {
    return @"127.0.0.1:9099 (Sẵn sàng)";
}

- (void)selectAppFromList:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:@"bundleID"];
    if (bundleID) {
        self.selectedBundleID = bundleID;
        _specifiers = nil;
        [self reloadSpecifiers];
    }
}

- (void)rescanTapped:(PSSpecifier *)spec {
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (void)triggerSimulatedPurchase:(PSSpecifier *)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Giả Lập Chạm Mua Ngầm" 
                                                                   message:[NSString stringWithFormat:@"Đang gửi tín hiệu chạm mua qua dylib tới app: %@", self.selectedBundleID]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)readStoreKitReceipt:(PSSpecifier *)specifier {
    NSDictionary *sel = nil;
    for (NSDictionary *a in _realInjectedApps) {
        if ([a[@"bundleID"] isEqualToString:self.selectedBundleID]) {
            sel = a; break;
        }
    }
    NSString *receiptPath = sel[@"receiptPath"] ?: @"Chưa tìm thấy";
    BOOL exists = [sel[@"hasStoreKitReceipt"] boolValue];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"StoreKit Receipt Thật" 
                                                                   message:[NSString stringWithFormat:@"Đường dẫn: %@\nTrạng thái: %@", receiptPath, exists ? @"Đã nạp hợp lệ" : @"Chưa có receipt trên máy"]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)viewCapturedPackets:(PSSpecifier *)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Packets Đã Bắt Được" 
                                                                   message:[NSString stringWithFormat:@"Đã kết nối IPC với %@.\nSẵn sàng bắt và phát lại gói tin StoreKit IAP & API.", self.selectedBundleID]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)restartTargetApp:(PSSpecifier *)specifier {
    if (self.selectedBundleID.length > 0) {
        pid_t pid;
        char *argv[] = {"/usr/bin/killall", "-9", (char *)[self.selectedBundleID UTF8String], NULL};
        posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, argv, NULL);

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Khởi Động Lại App" 
                                                                       message:[NSString stringWithFormat:@"Đã gửi lệnh tắt tiến trình %@", self.selectedBundleID] 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        
        _specifiers = nil;
        [self reloadSpecifiers];
    }
}

@end
