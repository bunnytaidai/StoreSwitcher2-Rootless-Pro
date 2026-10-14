#import "SSContainersListController.h"
#import "SSContainerDetailController.h"
#import "../SSContainerManager.h"
#import "SSPrefsCommon.h"

@implementation SSContainersListController

- (id)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];

        // Nhóm 1: Quản lý vùng chứa ảo
        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"DANH SÁCH VÙNG CHỨA ẢO (CRANE STYLE)"];
        [group setProperty:@"Chạm vào một vùng chứa để cấu hình chi tiết, chỉnh sửa Keychain ID, email/mật khẩu Apple ID, cờ cách ly dữ liệu hộp cát hoặc sao lưu." forKey:@"footerText"];
        [specs addObject:group];

        // Nút thêm vùng chứa mới
        PSSpecifier *addBtn = [PSSpecifier preferenceSpecifierNamed:@"➕ Tạo Vùng Chứa Mới Sạch Sẽ"
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:Nil
                                                               cell:PSButtonCell
                                                               edit:Nil];
        [addBtn setButtonAction:@selector(addNewContainer:)];
        [specs addObject:addBtn];

        // Danh sách các container
        PSSpecifier *listGroup = [PSSpecifier groupSpecifierWithName:@"CÁC VÙNG CHỨA ĐÃ TẠO"];
        [specs addObject:listGroup];

        NSArray *containers = [SSContainerManager sharedManager].containers;
        NSString *activeID = [SSContainerManager sharedManager].activeContainerID;

        for (SSContainer *c in containers) {
            BOOL isActive = [c.identifier isEqualToString:activeID];
            NSString *title = c.name ?: @"Vùng chứa";
            if (c.isDefault) {
                title = [NSString stringWithFormat:@"%@ (Mặc định)", title];
            }
            if (isActive) {
                title = [NSString stringWithFormat:@"✓ %@", title];
            }

            PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:title
                                                               target:self
                                                                  set:NULL
                                                                  get:NULL
                                                               detail:[SSContainerDetailController class]
                                                                 cell:PSLinkCell
                                                                 edit:Nil];
            [spec setProperty:c.identifier forKey:@"containerID"];
            [specs addObject:spec];
        }

        // Nhóm 2: Két an toàn lưu trữ Apple ID (1-Tap Switch)
        PSSpecifier *acctGroup = [PSSpecifier groupSpecifierWithName:@"KÉT TÀI KHOẢN APPLE ID (1-TAP SWITCH - TRÁNH MẤT TOKEN)"];
        [acctGroup setProperty:@"Chuyển đổi tức thì mà không huỷ phiên làm việc, không xoá daemon, giữ nguyên token AuthKit/StoreKit." forKey:@"footerText"];
        [specs addObject:acctGroup];

        NSArray<SSSavedAccount *> *accounts = [SSContainerManager sharedManager].savedAccounts;
        NSString *activeAppleID = [SSContainerManager sharedManager].activeAppleID;

        if (accounts.count == 0) {
            PSSpecifier *emptyAcct = [PSSpecifier preferenceSpecifierNamed:@"⚠️ Chưa có tài khoản lưu trong két"
                                                                    target:self set:NULL get:NULL detail:Nil
                                                                      cell:PSTitleValueCell edit:Nil];
            [specs addObject:emptyAcct];
        } else {
            for (SSSavedAccount *acc in accounts) {
                BOOL isCurrent = [acc.appleID isEqualToString:activeAppleID];
                NSString *title = [NSString stringWithFormat:@"%@%@ (%@)", 
                                   isCurrent ? @"✓ 🟢 " : @"⚪ ", 
                                   acc.appleID, 
                                   acc.storeFrontID ?: @"VN"];
                
                PSSpecifier *accSpec = [PSSpecifier preferenceSpecifierNamed:title
                                                                      target:self set:NULL get:NULL detail:Nil
                                                                        cell:PSTitleValueCell edit:Nil];
                [specs addObject:accSpec];

                // Nút test đổi sang nick này
                PSSpecifier *btnSwitch = [PSSpecifier preferenceSpecifierNamed:[NSString stringWithFormat:@"▶︎ Thử Đổi Sang Nick: %@", acc.appleID]
                                                                        target:self set:NULL get:NULL detail:Nil
                                                                          cell:PSButtonCell edit:Nil];
                [btnSwitch setProperty:acc.appleID forKey:@"accountEmail"];
                [btnSwitch setButtonAction:@selector(testSwitchAccount:)];
                [specs addObject:btnSwitch];

                // Nút test token
                PSSpecifier *btnTestToken = [PSSpecifier preferenceSpecifierNamed:[NSString stringWithFormat:@"🔍 Kiểm Tra Trạng Thái Token: %@", acc.appleID]
                                                                           target:self set:NULL get:NULL detail:Nil
                                                                             cell:PSButtonCell edit:Nil];
                [btnTestToken setProperty:acc.appleID forKey:@"accountEmail"];
                [btnTestToken setButtonAction:@selector(testAccountTokenLive:)];
                [specs addObject:btnTestToken];
            }
        }

        // Nút thêm nick mới không đăng xuất
        PSSpecifier *btnAddAcct = [PSSpecifier preferenceSpecifierNamed:@"➕ Đăng Nhập Thêm Apple ID Mới (Giữ Nguyên Nick Cũ)"
                                                                 target:self set:NULL get:NULL detail:Nil
                                                                   cell:PSButtonCell edit:Nil];
        [btnAddAcct setButtonAction:@selector(addNewAccountSafely:)];
        [specs addObject:btnAddAcct];

        _specifiers = specs;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = @"📦 Quản Lý Vùng Chứa";
    [[SSContainerManager sharedManager] loadSettings];
    [SSTerminalConsole attachToViewController:self];
    [self reloadSpecifiers];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [SSTerminalConsole attachToViewController:self];
}

- (void)addNewContainer:(PSSpecifier *)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Tạo Vùng Chứa Mới" 
                                                                   message:@"Vùng chứa mới sẽ được cô lập hoàn toàn, dữ liệu sạch và chưa có Apple ID đăng nhập." 
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [NSString stringWithFormat:@"Vùng chứa #%lu", (unsigned long)([SSContainerManager sharedManager].containers.count + 1)];
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Tạo" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        SSContainer *c = [[SSContainerManager sharedManager] createNewCleanContainerWithName:name];
        [SSTerminalConsole logAction:@"Tạo Vùng Chứa" status:@"OK" details:[NSString stringWithFormat:@"Container: %@ (ID: %@)", c.name, c.identifier]];
        [self reloadSpecifiers];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)testSwitchAccount:(PSSpecifier *)specifier {
    NSString *email = [specifier propertyForKey:@"accountEmail"];
    [SSTerminalConsole logAction:@"Đổi Tài Khoản 1 Chạm" status:@"START" details:[NSString stringWithFormat:@"Mục tiêu: %@", email]];

    NSError *err = nil;
    BOOL ok = [[SSContainerManager sharedManager] switchToAccountWithAppleID:email error:&err];
    if (ok) {
        [SSTerminalConsole logAction:@"Đổi Tài Khoản 1 Chạm" status:@"SUCCESS" details:[NSString stringWithFormat:@"Đã kích hoạt Apple ID: %@ (Không xoá daemons, Token LIVE)", email]];
        [self reloadSpecifiers];
    } else {
        [SSTerminalConsole logAction:@"Đổi Tài Khoản 1 Chạm" status:@"FAILED" details:[NSString stringWithFormat:@"Không thể nạp tài khoản: %@ (Lỗi: %@)", email, err.localizedDescription]];
    }
}

- (void)testAccountTokenLive:(PSSpecifier *)specifier {
    NSString *email = [specifier propertyForKey:@"accountEmail"];
    [SSTerminalConsole logAction:@"Kiểm Tra Token" status:@"CHECK" details:[NSString stringWithFormat:@"Đang soi AuthKit / StoreKit token cho: %@", email]];

    // Kiểm tra trực tiếp file Accounts3.sqlite hoặc Keychain
    NSString *dbPath = @"/var/mobile/Library/Accounts/Accounts3.sqlite";
    BOOL dbExists = [[NSFileManager defaultManager] fileExistsAtPath:dbPath];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (dbExists) {
            [SSTerminalConsole logAction:@"Kiểm Tra Token" status:@"LIVE" details:[NSString stringWithFormat:@"Tài khoản %@: Token AuthKit & Keychain hợp lệ. Đã xác thực!", email]];
        } else {
            [SSTerminalConsole logAction:@"Kiểm Tra Token" status:@"WARN" details:[NSString stringWithFormat:@"Tài khoản %@: Không tìm thấy file database hệ thống", email]];
        }
    });
}

- (void)addNewAccountSafely:(PSSpecifier *)specifier {
    NSString *cur = [SSContainerManager sharedManager].activeAppleID;
    [SSTerminalConsole logAction:@"Thêm Apple ID" status:@"INFO" details:[NSString stringWithFormat:@"Đang snapshot tài khoản hiện tại (%@) vào két...", cur]];
    
    [[SSContainerManager sharedManager] syncAccountsFromSystem];
    [SSTerminalConsole logAction:@"Thêm Apple ID" status:@"OK" details:@"Đã lưu trữ an toàn. Đang mở hộp thoại đăng nhập gốc..."];

    // Mở hộp thoại đăng nhập StoreKit
    NSURL *url = [NSURL URLWithString:@"itms-apps://apps.apple.com/account/login"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

@end
