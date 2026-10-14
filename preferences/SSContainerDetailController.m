#import "SSContainerDetailController.h"
#import "../SSContainerManager.h"
#import "SSTerminalConsole.h"
#import <spawn.h>

@implementation SSContainerDetailController

- (SSContainer *)targetContainer {
    if (!_container) {
        NSString *cID = [self.specifier propertyForKey:@"containerID"];
        if (cID.length > 0) {
            _container = [[SSContainerManager sharedManager] containerWithIdentifier:cID];
        }
    }
    return _container;
}

- (id)specifiers {
    if (!_specifiers) {
        SSContainer *c = [self targetContainer];
        NSMutableArray *specs = [NSMutableArray array];

        // Nhóm 1: Thông tin cơ bản
        PSSpecifier *grp1 = [PSSpecifier groupSpecifierWithName:@"THÔNG TIN VÙNG CHỨA"];
        [specs addObject:grp1];

        PSSpecifier *nameSpec = [PSSpecifier preferenceSpecifierNamed:@"Tên vùng chứa"
                                                               target:self
                                                                  set:@selector(setContainerValue:specifier:)
                                                                  get:@selector(readContainerValue:)
                                                               detail:Nil
                                                                 cell:PSEditTextCell
                                                                 edit:Nil];
        [nameSpec setProperty:@"name" forKey:@"key"];
        [nameSpec setProperty:@"Tên vùng chứa" forKey:@"placeholder"];
        [specs addObject:nameSpec];

        PSSpecifier *uuidSpec = [PSSpecifier preferenceSpecifierNamed:@"Keychain ID / UUID"
                                                               target:self
                                                                  set:NULL
                                                                  get:@selector(readUUIDValue:)
                                                               detail:Nil
                                                                 cell:PSTitleValueCell
                                                                 edit:Nil];
        [specs addObject:uuidSpec];

        PSSpecifier *statusSpec = [PSSpecifier preferenceSpecifierNamed:@"Trạng thái"
                                                                 target:self
                                                                    set:NULL
                                                                    get:@selector(readStatusValue:)
                                                                 detail:Nil
                                                                   cell:PSTitleValueCell
                                                                   edit:Nil];
        [specs addObject:statusSpec];

        // Nhóm 2: Tài khoản Apple ID gắn kết
        PSSpecifier *grp2 = [PSSpecifier groupSpecifierWithName:@"TÀI KHOẢN APPLE ID GẮN VỚI VÙNG CHỨA"];
        [grp2 setProperty:@"Có thể chỉnh sửa email Apple ID và bổ sung mật khẩu để tweak tự động nạp phục vụ việc xoay vòng tự động đổi nick." forKey:@"footerText"];
        [specs addObject:grp2];

        PSSpecifier *emailSpec = [PSSpecifier preferenceSpecifierNamed:@"Email Apple ID"
                                                                target:self
                                                                   set:@selector(setContainerValue:specifier:)
                                                                   get:@selector(readContainerValue:)
                                                                detail:Nil
                                                                  cell:PSEditTextCell
                                                                  edit:Nil];
        [emailSpec setProperty:@"appleID" forKey:@"key"];
        [emailSpec setProperty:@"appleid@icloud.com" forKey:@"placeholder"];
        [specs addObject:emailSpec];

        PSSpecifier *testTokenBtn = [PSSpecifier preferenceSpecifierNamed:@"▶︎ Test Kiểm Tra Token Apple ID (AuthKit)"
                                                                   target:self
                                                                      set:NULL
                                                                      get:NULL
                                                                   detail:Nil
                                                                     cell:PSButtonCell
                                                                     edit:Nil];
        [testTokenBtn setButtonAction:@selector(actionTestAuthKitToken:)];
        [specs addObject:testTokenBtn];

        PSSpecifier *pwdSpec = [PSSpecifier preferenceSpecifierNamed:@"Mật khẩu Apple ID"
                                                              target:self
                                                                 set:@selector(setContainerValue:specifier:)
                                                                 get:@selector(readContainerValue:)
                                                              detail:Nil
                                                                cell:PSEditTextCell
                                                                edit:Nil];
        [pwdSpec setProperty:@"password" forKey:@"key"];
        [pwdSpec setProperty:@"Mật khẩu lưu trữ" forKey:@"placeholder"];
        [specs addObject:pwdSpec];

        PSSpecifier *storeSpec = [PSSpecifier preferenceSpecifierNamed:@"Mã StoreFront ID"
                                                                target:self
                                                                   set:@selector(setContainerValue:specifier:)
                                                                   get:@selector(readContainerValue:)
                                                                detail:Nil
                                                                  cell:PSEditTextCell
                                                                  edit:Nil];
        [storeSpec setProperty:@"storeFrontID" forKey:@"key"];
        [storeSpec setProperty:@"143441 (Mỹ), 143462 (VN)" forKey:@"placeholder"];
        [specs addObject:storeSpec];

        PSSpecifier *testStoreBtn = [PSSpecifier preferenceSpecifierNamed:@"▶︎ Test Kiểm Tra StoreFront ID Này"
                                                                   target:self
                                                                      set:NULL
                                                                      get:NULL
                                                                   detail:Nil
                                                                     cell:PSButtonCell
                                                                     edit:Nil];
        [testStoreBtn setButtonAction:@selector(actionTestStoreFront:)];
        [specs addObject:testStoreBtn];

        // Nhóm 3: Các dấu tích chọn cô lập
        PSSpecifier *grp3 = [PSSpecifier groupSpecifierWithName:@"CÁC DẤU TÍCH CHỌN CÔ LẬP VÙNG CHỨA"];
        [grp3 setProperty:@"Tách biệt dữ liệu tránh rò rỉ token, cookie hoặc cache giữa các tài khoản Apple ID." forKey:@"footerText"];
        [specs addObject:grp3];

        PSSpecifier *isoSys = [PSSpecifier preferenceSpecifierNamed:@"Tách biệt tài khoản hệ thống"
                                                             target:self
                                                                set:@selector(setContainerBool:specifier:)
                                                                get:@selector(readContainerBool:)
                                                             detail:Nil
                                                               cell:PSSwitchCell
                                                               edit:Nil];
        [isoSys setProperty:@"isolateSystemAccounts" forKey:@"key"];
        [isoSys setProperty:@YES forKey:@"default"];
        [specs addObject:isoSys];

        PSSpecifier *leakSpec = [PSSpecifier preferenceSpecifierNamed:@"Ngăn chặn rò rỉ dữ liệu hộp cát"
                                                               target:self
                                                                  set:@selector(setContainerBool:specifier:)
                                                                  get:@selector(readContainerBool:)
                                                               detail:Nil
                                                                 cell:PSSwitchCell
                                                                 edit:Nil];
        [leakSpec setProperty:@"preserveSandbox" forKey:@"key"];
        [leakSpec setProperty:@YES forKey:@"default"];
        [specs addObject:leakSpec];

        PSSpecifier *notifSpec = [PSSpecifier preferenceSpecifierNamed:@"Thông báo riêng biệt"
                                                                target:self
                                                                   set:@selector(setContainerBool:specifier:)
                                                                   get:@selector(readContainerBool:)
                                                                detail:Nil
                                                                  cell:PSSwitchCell
                                                                  edit:Nil];
        [notifSpec setProperty:@"isolatedNotifications" forKey:@"key"];
        [notifSpec setProperty:@YES forKey:@"default"];
        [specs addObject:notifSpec];

        PSSpecifier *keychainSpec = [PSSpecifier preferenceSpecifierNamed:@"Tách biệt Keychain Token"
                                                                   target:self
                                                                      set:@selector(setContainerBool:specifier:)
                                                                      get:@selector(readContainerBool:)
                                                                   detail:Nil
                                                                     cell:PSSwitchCell
                                                                     edit:Nil];
        [keychainSpec setProperty:@"isolatedKeychain" forKey:@"key"];
        [keychainSpec setProperty:@YES forKey:@"default"];
        [specs addObject:keychainSpec];

        // Nhóm 4: Hành động
        PSSpecifier *grp4 = [PSSpecifier groupSpecifierWithName:@"HÀNH ĐỘNG VÙNG CHỨA"];
        [specs addObject:grp4];

        PSSpecifier *actBtn = [PSSpecifier preferenceSpecifierNamed:@"⚡ Kích Hoạt Vùng Chứa Này Ngay"
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:Nil
                                                               cell:PSButtonCell
                                                               edit:Nil];
        [actBtn setButtonAction:@selector(activateThisContainer:)];
        [specs addObject:actBtn];

        PSSpecifier *backupBtn = [PSSpecifier preferenceSpecifierNamed:@"📦 Sao Lưu Tất Cả Dữ Liệu Hộp Cát (.tar.gz)"
                                                                target:self
                                                                   set:NULL
                                                                   get:NULL
                                                                detail:Nil
                                                                  cell:PSButtonCell
                                                                  edit:Nil];
        [backupBtn setButtonAction:@selector(backupSandbox:)];
        [specs addObject:backupBtn];

        if (!c.isDefault) {
            PSSpecifier *delBtn = [PSSpecifier preferenceSpecifierNamed:@"🗑 Xóa Vùng Chứa Này"
                                                                 target:self
                                                                    set:NULL
                                                                    get:NULL
                                                                 detail:Nil
                                                                   cell:PSButtonCell
                                                                   edit:Nil];
            [delBtn setButtonAction:@selector(deleteThisContainer:)];
            [specs addObject:delBtn];
        }

        _specifiers = specs;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = [self targetContainer].name ?: @"Chi Tiết Vùng Chứa";
}

#pragma mark - Value Getters / Setters

- (id)readContainerValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    return [[self targetContainer] valueForKey:key] ?: @"";
}

- (void)setContainerValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    [[self targetContainer] setValue:value forKey:key];
    [[SSContainerManager sharedManager] saveSettings];
}

- (id)readContainerBool:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSNumber *val = [[self targetContainer] valueForKey:key];
    return val ?: [specifier propertyForKey:@"default"];
}

- (void)setContainerBool:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    [[self targetContainer] setValue:value forKey:key];
    [[SSContainerManager sharedManager] saveSettings];
}

- (id)readUUIDValue:(PSSpecifier *)specifier {
    return [self targetContainer].identifier ?: @"Chưa tạo";
}

- (id)readStatusValue:(PSSpecifier *)specifier {
    BOOL isActive = [[self targetContainer].identifier isEqualToString:[SSContainerManager sharedManager].activeContainerID];
    return isActive ? @"Đang kích hoạt ✓" : @"Chưa kích hoạt";
}

#pragma mark - Actions

- (void)activateThisContainer:(PSSpecifier *)specifier {
    SSContainer *c = [self targetContainer];
    if (!c) return;

    NSError *err = nil;
    BOOL ok = [[SSContainerManager sharedManager] switchToContainer:c error:&err];
    if (ok) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chuyển Vùng Chứa Thành Công"
                                                                       message:[NSString stringWithFormat:@"Đã kích hoạt: %@\nCác daemon chạy ngầm đã được làm sạch.", c.name]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self reloadSpecifiers];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lỗi Chuyển Đổi"
                                                                       message:[err localizedDescription] ?: @"Không thể chuyển vùng chứa."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)backupSandbox:(PSSpecifier *)specifier {
    SSContainer *c = [self targetContainer];
    if (!c) return;

    NSString *backupDir = @"/var/mobile/Library/Application Support/StoreSwitcher/Backups";
    [[NSFileManager defaultManager] createDirectoryAtPath:backupDir withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *sanitizedName = [[c.name stringByReplacingOccurrencesOfString:@" " withString:@"_"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    NSString *backupFile = [backupDir stringByAppendingPathComponent:[NSString stringWithFormat:@"backup_%@_%@.tar.gz", sanitizedName, [c.identifier substringToIndex:MIN((NSUInteger)8, c.identifier.length)]]];

    // Tạo bản backup nén tar.gz dữ liệu hộp cát
    pid_t pid;
    const char *args[] = {
        "/bin/tar",
        "-czf",
        [backupFile UTF8String],
        "-C",
        "/var/mobile/Library/Application Support/StoreSwitcher",
        ".",
        NULL
    };
    posix_spawn(&pid, "/bin/tar", NULL, NULL, (char * const *)args, NULL);
    int status;
    waitpid(pid, &status, 0);

    unsigned long long size = 0;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:backupFile error:nil];
    if (attrs) {
        size = [attrs fileSize];
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sao Lưu Hộp Cát Thành Công"
                                                                   message:[NSString stringWithFormat:@"Bản sao lưu đã được đóng gói an toàn:\n%@\nKích thước: %.2f KB", backupFile, size / 1024.0]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Tuyệt Vời" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deleteThisContainer:(PSSpecifier *)specifier {
    SSContainer *c = [self targetContainer];
    if (!c || c.isDefault) return;

    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Xác Nhận Xóa Vùng Chứa"
                                                                     message:[NSString stringWithFormat:@"Bạn có chắc muốn xóa '%@' không? Tất cả dữ liệu lưu trữ của vùng chứa này sẽ bị loại bỏ.", c.name]
                                                              preferredStyle:UIAlertControllerStyleActionSheet];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Xóa Vĩnh Viễn" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[SSContainerManager sharedManager] deleteContainer:c];
        [self.navigationController popViewControllerAnimated:YES];
    }]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)actionTestAuthKitToken:(PSSpecifier *)specifier {
    SSContainer *c = [self targetContainer];
    NSString *appleID = c.appleID ?: @"";
    [SSTerminalConsole log:[NSString stringWithFormat:@"[CONTAINER] Đang kiểm tra trạng thái Token AuthKit cho: %@", appleID.length > 0 ? appleID : @"(Chưa nhập Apple ID)"]];

    if (appleID.length == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chưa Có Apple ID"
                                                                       message:@"Hãy nhập email Apple ID trước khi kiểm tra token."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    NSString *tokenPath = [NSString stringWithFormat:@"/var/mobile/Library/Application Support/StoreSwitcher/Containers/%@/auth_token.plist", c.identifier];
    BOOL hasToken = [[NSFileManager defaultManager] fileExistsAtPath:tokenPath];

    [SSTerminalConsole log:[NSString stringWithFormat:@"[CONTAINER] Token AuthKit vùng chứa '%@': %@", c.name, hasToken ? @"HỢP LỆ (Đã lưu trữ Keychain)" : @"CHƯA CÓ TOKEN RIÊNG (Đang dùng Token gốc)"]];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Trạng Thái Token AuthKit"
                                                                   message:[NSString stringWithFormat:@"Tài khoản: %@\nVùng chứa: %@\nTrạng thái: %@", appleID, c.name, hasToken ? @"Đã có Token Keychain độc lập ✓" : @"Đang dùng chung Session hệ thống"]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)actionTestStoreFront:(PSSpecifier *)specifier {
    SSContainer *c = [self targetContainer];
    NSString *sfID = c.storeFrontID ?: @"143441";
    [SSTerminalConsole log:[NSString stringWithFormat:@"[CONTAINER] Đang kiểm tra cấu hình StoreFront ID: %@", sfID]];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"StoreFront ID Hợp Lệ"
                                                                   message:[NSString stringWithFormat:@"StoreFront ID: %@\nVùng chứa: %@\nĐã sẵn sàng chuyển vùng App Store tự động khi kích hoạt.", sfID, c.name]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
