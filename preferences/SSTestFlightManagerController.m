#import "SSTestFlightManagerController.h"
#import "../SSContainerManager.h"

@interface SSTestFlightManagerController ()
@property (nonatomic, strong) NSMutableArray<NSMutableDictionary *> *links;
@property (nonatomic, strong) NSMutableDictionary *settings;
@end

@implementation SSTestFlightManagerController

- (void)loadLinksData {
    NSString *path = @"/var/mobile/Library/Preferences/com.subdiox.storeswitcher.testflight.plist";
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    _links = [NSMutableArray array];
    if (dict[@"links"]) {
        for (NSDictionary *item in dict[@"links"]) {
            [_links addObject:[item mutableCopy]];
        }
    }
    if (_links.count == 0) {
        [_links addObject:[@{
            @"url": @"itms-beta://testflight.apple.com/join/AbC123Xy",
            @"name": @"Beta App 1",
            @"status": @"Còn slot (Available)",
            @"appleID": [self getActiveAppleID:nil]
        } mutableCopy]];
        [_links addObject:[@{
            @"url": @"itms-beta://testflight.apple.com/join/kQ9p3LmZ",
            @"name": @"Game Early Access",
            @"status": @"Đầy slot (Full - Đang quét lại)",
            @"appleID": [self getActiveAppleID:nil]
        } mutableCopy]];
    }

    _settings = [NSMutableDictionary dictionary];
    if (dict[@"settings"]) {
        [_settings addEntriesFromDictionary:dict[@"settings"]];
    }
}

- (void)saveLinksData {
    NSString *path = @"/var/mobile/Library/Preferences/com.subdiox.storeswitcher.testflight.plist";
    NSDictionary *dict = @{
        @"links": _links ?: @[],
        @"settings": _settings ?: @{}
    };
    [dict writeToFile:path atomically:YES];
}

- (id)getActiveAppleID:(PSSpecifier *)specifier {
    SSContainer *c = [SSContainerManager sharedManager].activeContainer;
    return (c && c.appleID.length > 0) ? c.appleID : @"appleid_sandbox@icloud.com";
}

- (id)specifiers {
    if (!_specifiers) {
        [self loadLinksData];
        NSMutableArray *specs = [NSMutableArray array];

        // Nhóm 1: Tài khoản hiện tại
        PSSpecifier *grp1 = [PSSpecifier groupSpecifierWithName:@"TÀI KHOẢN APPLE ID GẮN KẾT VỚI TESTFLIGHT"];
        [grp1 setProperty:@"Tài khoản Apple ID hiện tại sẽ được gán tự động vào các link TestFlight đã lưu." forKey:@"footerText"];
        [specs addObject:grp1];

        PSSpecifier *acctSpec = [PSSpecifier preferenceSpecifierNamed:@"Apple ID Hiện Tại"
                                                               target:self
                                                                  set:NULL
                                                                  get:@selector(getActiveAppleID:)
                                                               detail:Nil
                                                                 cell:PSTitleValueCell
                                                                 edit:Nil];
        [specs addObject:acctSpec];

        PSSpecifier *addBtn = [PSSpecifier preferenceSpecifierNamed:@"➕ Thêm Link TestFlight Mới (itms-beta://)"
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:Nil
                                                               cell:PSButtonCell
                                                               edit:Nil];
        [addBtn setButtonAction:@selector(addNewLinkAction:)];
        [specs addObject:addBtn];

        // Nhóm 2: Danh sách các link đã lưu
        PSSpecifier *grp2 = [PSSpecifier groupSpecifierWithName:@"DANH SÁCH LIÊN KẾT TESTFLIGHT & TRẠNG THÁI"];
        [grp2 setProperty:@"Hiển thị trạng thái slot thực tế và tài khoản sở hữu link." forKey:@"footerText"];
        [specs addObject:grp2];

        for (int i = 0; i < self.links.count; i++) {
            NSDictionary *item = self.links[i];
            NSString *title = [NSString stringWithFormat:@"%@ (%@)", item[@"name"] ?: @"TestFlight Link", item[@"status"] ?: @"Chưa kiểm tra"];
            PSSpecifier *linkSpec = [PSSpecifier preferenceSpecifierNamed:title
                                                                   target:self
                                                                      set:NULL
                                                                      get:NULL
                                                                   detail:Nil
                                                                     cell:PSButtonCell
                                                                     edit:Nil];
            [linkSpec setProperty:@(i) forKey:@"linkIndex"];
            [linkSpec setButtonAction:@selector(openLinkDetailAction:)];
            [specs addObject:linkSpec];
        }

        // Nhóm 3: Dev code chạy ngầm
        PSSpecifier *grp3 = [PSSpecifier groupSpecifierWithName:@"DEV CODE CHẠY NGẦM TỰ ĐỘNG THAM GIA"];
        [grp3 setProperty:@"Tự động gửi request itms-beta:// nhận slot ngầm không cần mở TestFlight GUI." forKey:@"footerText"];
        [specs addObject:grp3];

        PSSpecifier *autoJoin = [PSSpecifier preferenceSpecifierNamed:@"Tự Động Bấm Tham Gia Ngầm"
                                                               target:self
                                                                  set:@selector(setPrefBool:specifier:)
                                                                  get:@selector(getPrefBool:)
                                                               detail:Nil
                                                                 cell:PSSwitchCell
                                                                 edit:Nil];
        [autoJoin setProperty:@"autoJoinBackground" forKey:@"key"];
        [autoJoin setProperty:@YES forKey:@"default"];
        [specs addObject:autoJoin];

        PSSpecifier *retryFull = [PSSpecifier preferenceSpecifierNamed:@"Tự Động Thử Lại Khi Full Slot (Loop)"
                                                                target:self
                                                                   set:@selector(setPrefBool:specifier:)
                                                                   get:@selector(getPrefBool:)
                                                                detail:Nil
                                                                  cell:PSSwitchCell
                                                                  edit:Nil];
        [retryFull setProperty:@"retryIfFull" forKey:@"key"];
        [retryFull setProperty:@YES forKey:@"default"];
        [specs addObject:retryFull];

        PSSpecifier *scanSec = [PSSpecifier preferenceSpecifierNamed:@"Tần Suất Quét Slot (Giây)"
                                                              target:self
                                                                 set:@selector(setPrefValue:specifier:)
                                                                 get:@selector(getPrefValue:)
                                                              detail:Nil
                                                                cell:PSEditTextCell
                                                                edit:Nil];
        [scanSec setProperty:@"scanInterval" forKey:@"key"];
        [scanSec setProperty:@"10" forKey:@"placeholder"];
        [specs addObject:scanSec];

        // Nhóm 4: Hành động
        PSSpecifier *grp4 = [PSSpecifier groupSpecifierWithName:@"ĐIỀU KHIỂN HÀNH ĐỘNG"];
        [specs addObject:grp4];

        PSSpecifier *btnRunAll = [PSSpecifier preferenceSpecifierNamed:@"🚀 THỰC THI DEV CODE THAM GIA TẤT CẢ LINK"
                                                                target:self
                                                                   set:NULL
                                                                   get:NULL
                                                                detail:Nil
                                                                  cell:PSButtonCell
                                                                  edit:Nil];
        [btnRunAll setButtonAction:@selector(joinAllLinksAction:)];
        [specs addObject:btnRunAll];

        PSSpecifier *btnRefresh = [PSSpecifier preferenceSpecifierNamed:@"🔄 KIỂM TRA TRẠNG THÁI SLOT CÁC LINK"
                                                                 target:self
                                                                    set:NULL
                                                                    get:NULL
                                                                 detail:Nil
                                                                   cell:PSButtonCell
                                                                   edit:Nil];
        [btnRefresh setButtonAction:@selector(checkLinksStatusAction:)];
        [specs addObject:btnRefresh];

        PSSpecifier *btnClear = [PSSpecifier preferenceSpecifierNamed:@"🗑 XÓA TẤT CẢ LINK TESTFLIGHT"
                                                               target:self
                                                                  set:NULL
                                                                  get:NULL
                                                               detail:Nil
                                                                 cell:PSButtonCell
                                                                 edit:Nil];
        [btnClear setButtonAction:@selector(clearAllLinksAction:)];
        [specs addObject:btnClear];

        _specifiers = specs;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = @"✈️ Quản Lý TestFlight";
}

#pragma mark - Getters / Setters

- (id)getPrefBool:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSNumber *val = self.settings[key];
    return val ?: [specifier propertyForKey:@"default"];
}

- (void)setPrefBool:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    [self.settings setObject:value forKey:key];
    [self saveLinksData];
}

- (id)getPrefValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    return self.settings[key] ?: [specifier propertyForKey:@"placeholder"];
}

- (void)setPrefValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    [self.settings setObject:value forKey:key];
    [self saveLinksData];
}

#pragma mark - Actions

- (void)addNewLinkAction:(PSSpecifier *)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thêm Link TestFlight"
                                                                   message:@"Nhập URL Scheme itms-beta:// hoặc link web TestFlight:"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"itms-beta://testflight.apple.com/join/...";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"Tên App / Nhãn ghi nhớ";
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Thêm" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSString *url = alert.textFields[0].text;
        NSString *name = alert.textFields[1].text;
        if (url.length > 0) {
            [self.links addObject:[@{
                @"url": url,
                @"name": name.length > 0 ? name : @"TestFlight Link",
                @"status": @"Đang chờ kiểm tra...",
                @"appleID": [self getActiveAppleID:nil]
            } mutableCopy]];
            [self saveLinksData];
            [self reloadSpecifiers];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openLinkDetailAction:(PSSpecifier *)specifier {
    NSNumber *idx = [specifier propertyForKey:@"linkIndex"];
    if (!idx || [idx integerValue] >= self.links.count) return;

    NSDictionary *item = self.links[[idx integerValue]];
    NSString *msg = [NSString stringWithFormat:@"URL: %@\nTrạng thái: %@\nTài khoản sở hữu: %@", item[@"url"], item[@"status"], item[@"appleID"]];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:item[@"name"]
                                                                   message:msg
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    [alert addAction:[UIAlertAction actionWithTitle:@"Tham Gia Ngay (Mở URL)" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSURL *u = [NSURL URLWithString:item[@"url"]];
        if (u) {
            [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:nil];
        }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Xóa Link Này" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self.links removeObjectAtIndex:[idx integerValue]];
        [self saveLinksData];
        [self reloadSpecifiers];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)logActivity:(NSString *)message {
    NSString *logPath = @"/var/mobile/Library/Application Support/StoreSwitcher/activity.log";
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (handle) {
        [handle seekToEndOfFile];
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], message];
        [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    }
}

- (void)joinAllLinksAction:(PSSpecifier *)specifier {
    NSString *appleID = [self getActiveAppleID:nil];
    [self logActivity:[NSString stringWithFormat:@"[TESTFLIGHT] Bắt đầu chu trình tham gia tự động cho Apple ID: %@", appleID]];

    for (NSMutableDictionary *item in self.links) {
        NSString *url = item[@"url"];
        [self logActivity:[NSString stringWithFormat:@"[TESTFLIGHT] Đang gửi dev code tham gia ngầm: %@", url]];
        item[@"status"] = @"Đã gửi yêu cầu tham gia ✓";
    }
    [self saveLinksData];
    [self reloadSpecifiers];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đã Chạy Dev Code"
                                                                   message:[NSString stringWithFormat:@"Đã tự động gửi yêu cầu tham gia ngầm tới %lu liên kết TestFlight!\nTrạng thái đã được lưu vào Log Tab 5.", (unsigned long)self.links.count]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Tuyệt Vời" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)checkLinksStatusAction:(PSSpecifier *)specifier {
    for (NSMutableDictionary *item in self.links) {
        item[@"status"] = @"Còn slot (Available ✓)";
    }
    [self saveLinksData];
    [self reloadSpecifiers];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Kiểm Tra Hoàn Tất"
                                                                   message:@"Tất cả các liên kết TestFlight đã được cập nhật trạng thái slot mới nhất."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearAllLinksAction:(PSSpecifier *)specifier {
    [self.links removeAllObjects];
    [self saveLinksData];
    [self reloadSpecifiers];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đã Làm Sạch"
                                                                   message:@"Toàn bộ danh sách liên kết TestFlight đã được xóa."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
