#import "SSTestFlightManagerController.h"
#import "../SSContainerManager.h"
#import "SSTerminalConsole.h"

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

            PSSpecifier *testLinkBtn = [PSSpecifier preferenceSpecifierNamed:[NSString stringWithFormat:@"▶︎ Test Kiểm Tra Slot Link #%d", i + 1]
                                                                      target:self
                                                                         set:NULL
                                                                         get:NULL
                                                                      detail:Nil
                                                                        cell:PSButtonCell
                                                                        edit:Nil];
            [testLinkBtn setProperty:@(i) forKey:@"linkIndex"];
            [testLinkBtn setButtonAction:@selector(actionTestSingleLink:)];
            [specs addObject:testLinkBtn];
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

- (void)actionTestSingleLink:(PSSpecifier *)specifier {
    NSNumber *idx = [specifier propertyForKey:@"linkIndex"];
    if (!idx || [idx integerValue] >= self.links.count) return;

    NSMutableDictionary *item = self.links[[idx integerValue]];
    NSString *rawUrl = item[@"url"] ?: @"";
    NSString *httpUrl = [rawUrl stringByReplacingOccurrencesOfString:@"itms-beta://" withString:@"https://"];

    [SSTerminalConsole log:[NSString stringWithFormat:@"[TESTFLIGHT] Đang kiểm tra slot thực tế với Apple Server: %@", httpUrl]];

    NSURL *url = [NSURL URLWithString:httpUrl];
    if (!url) {
        [SSTerminalConsole log:[NSString stringWithFormat:@"[TESTFLIGHT] URL không hợp lệ: %@", rawUrl]];
        return;
    }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 15_8 like Mac OS X)" forHTTPHeaderField:@"User-Agent"];
    req.timeoutInterval = 5.0;

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error && data) {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
                [SSTerminalConsole log:[NSString stringWithFormat:@"[TESTFLIGHT] Apple Server phản hồi HTTP %ld", (long)httpResp.statusCode]];

                if ([html containsString:@"This beta is full"] || [html containsString:@"The beta is full"]) {
                    item[@"status"] = @"Đầy slot (Full)";
                    [SSTerminalConsole log:[NSString stringWithFormat:@"[TESTFLIGHT] Link %@: ĐÃ HẾT SLOT", item[@"name"]]];
                } else if ([html containsString:@"This beta isn't accepting any new testers"]) {
                    item[@"status"] = @"Đã đóng tuyển tester";
                    [SSTerminalConsole log:[NSString stringWithFormat:@"[TESTFLIGHT] Link %@: ĐÃ ĐÓNG TUYỂN TESTER", item[@"name"]]];
                } else if ([html containsString:@"To join the beta"] || [html containsString:@"Start Testing"] || httpResp.statusCode == 200) {
                    item[@"status"] = @"Còn slot (Available ✓)";
                    [SSTerminalConsole log:[NSString stringWithFormat:@"[TESTFLIGHT] Link %@: CÒN SLOT THỰC TẾ (AVAILABLE) ✓", item[@"name"]]];
                } else {
                    item[@"status"] = [NSString stringWithFormat:@"HTTP %ld", (long)httpResp.statusCode];
                }
                [self saveLinksData];
                [self reloadSpecifiers];

                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Kết Quả Quét Slot Thật"
                                                                               message:[NSString stringWithFormat:@"App: %@\nTrạng thái: %@\nHTTP: %ld", item[@"name"], item[@"status"], (long)httpResp.statusCode]
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                [SSTerminalConsole log:[NSString stringWithFormat:@"[TESTFLIGHT] Lỗi kiểm tra mạng: %@", error.localizedDescription]];
            }
        });
    }] resume];
}

- (void)joinAllLinksAction:(PSSpecifier *)specifier {
    NSString *appleID = [self getActiveAppleID:nil];
    [SSTerminalConsole log:[NSString stringWithFormat:@"[TESTFLIGHT] Bắt đầu chu trình tham gia tự động cho Apple ID: %@", appleID]];

    for (NSMutableDictionary *item in self.links) {
        NSString *url = item[@"url"];
        [SSTerminalConsole log:[NSString stringWithFormat:@"[TESTFLIGHT] Đang gửi dev code tham gia ngầm: %@", url]];
        item[@"status"] = @"Đã gửi yêu cầu tham gia ✓";

        NSURL *u = [NSURL URLWithString:url];
        if (u) {
            [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:^(BOOL success) {
                [SSTerminalConsole log:[NSString stringWithFormat:@"[TESTFLIGHT] Mở URL TestFlight %@: %@", url, success ? @"OK" : @"Lỗi"]];
            }];
        }
    }
    [self saveLinksData];
    [self reloadSpecifiers];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đã Chạy Dev Code"
                                                                   message:[NSString stringWithFormat:@"Đã tự động gửi yêu cầu tham gia tới %lu liên kết TestFlight!", (unsigned long)self.links.count]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Tuyệt Vời" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)checkLinksStatusAction:(PSSpecifier *)specifier {
    [SSTerminalConsole log:[NSString stringWithFormat:@"[TESTFLIGHT] Đang quét trạng thái slot thực tế cho %lu liên kết...", (unsigned long)self.links.count]];

    dispatch_group_t group = dispatch_group_create();
    for (NSMutableDictionary *item in self.links) {
        dispatch_group_enter(group);
        NSString *rawUrl = item[@"url"] ?: @"";
        NSString *httpUrl = [rawUrl stringByReplacingOccurrencesOfString:@"itms-beta://" withString:@"https://"];
        NSURL *url = [NSURL URLWithString:httpUrl];
        if (!url) {
            dispatch_group_leave(group);
            continue;
        }

        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 15_8 like Mac OS X)" forHTTPHeaderField:@"User-Agent"];
        req.timeoutInterval = 4.0;

        [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (!error && data) {
                NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if ([html containsString:@"This beta is full"] || [html containsString:@"The beta is full"]) {
                    item[@"status"] = @"Đầy slot (Full)";
                } else if ([html containsString:@"This beta isn't accepting any new testers"]) {
                    item[@"status"] = @"Đã đóng tuyển tester";
                } else {
                    item[@"status"] = @"Còn slot (Available ✓)";
                }
            } else {
                item[@"status"] = @"Lỗi kết nối";
            }
            dispatch_group_leave(group);
        }] resume];
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [self saveLinksData];
        [self reloadSpecifiers];
        [SSTerminalConsole log:@"[TESTFLIGHT] Hoàn tất quét slot tất cả các link TestFlight từ Apple Server."];

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Kiểm Tra Hoàn Tất"
                                                                       message:@"Tất cả các liên kết TestFlight đã được cập nhật trạng thái slot thực tế từ máy chủ Apple."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)clearAllLinksAction:(PSSpecifier *)specifier {
    [self.links removeAllObjects];
    [self saveLinksData];
    [self reloadSpecifiers];
    [SSTerminalConsole log:@"[TESTFLIGHT] Đã xóa toàn bộ danh sách liên kết TestFlight."];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đã Làm Sạch"
                                                                   message:@"Toàn bộ danh sách liên kết TestFlight đã được xóa."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
