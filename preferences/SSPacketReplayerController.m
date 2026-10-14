#import "SSPacketReplayerController.h"

@interface SSPacketReplayerController ()
@property (nonatomic, strong) NSMutableDictionary *replayerConfig;
@end

@implementation SSPacketReplayerController

- (void)loadConfig {
    NSString *path = @"/var/mobile/Library/Preferences/com.subdiox.storeswitcher.replayer.plist";
    _replayerConfig = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
    if (!_replayerConfig[@"capturedURL"]) {
        _replayerConfig[@"capturedURL"] = @"itms-appss://apps.apple.com/app/id123456789";
    }
    if (!_replayerConfig[@"productID"]) {
        _replayerConfig[@"productID"] = @"com.developer.app.monthly_sub_tier1";
    }
    if (!_replayerConfig[@"transactionID"]) {
        _replayerConfig[@"transactionID"] = @"1000000987654321";
    }
    if (!_replayerConfig[@"accountDSID"]) {
        _replayerConfig[@"accountDSID"] = @"1982736450";
    }
}

- (void)saveConfig {
    NSString *path = @"/var/mobile/Library/Preferences/com.subdiox.storeswitcher.replayer.plist";
    [_replayerConfig writeToFile:path atomically:YES];
}

- (id)specifiers {
    if (!_specifiers) {
        [self loadConfig];
        NSMutableArray *specs = [NSMutableArray array];

        // Nhóm 1: Bắt hành động & Sniffer
        PSSpecifier *grp1 = [PSSpecifier groupSpecifierWithName:@"BỘ THU BẮT HÀNH ĐỘNG & BẮT GÓI TIN (SNIFFER)"];
        [grp1 setProperty:@"Bật chế độ ghi để dylib tự động bắt URL Scheme, Deeplink và các API mua In-App khi thao tác trên app." forKey:@"footerText"];
        [specs addObject:grp1];

        PSSpecifier *recSwitch = [PSSpecifier preferenceSpecifierNamed:@"🔴 Bật / Tắt Ghi Lại Hành Động (Recording)"
                                                               target:self
                                                                  set:@selector(setPrefBool:specifier:)
                                                                  get:@selector(getPrefBool:)
                                                               detail:Nil
                                                                 cell:PSSwitchCell
                                                                 edit:Nil];
        [recSwitch setProperty:@"isRecording" forKey:@"key"];
        [recSwitch setProperty:@NO forKey:@"default"];
        [specs addObject:recSwitch];

        PSSpecifier *deepSwitch = [PSSpecifier preferenceSpecifierNamed:@"Bắt URL Scheme & Deeplink"
                                                                 target:self
                                                                    set:@selector(setPrefBool:specifier:)
                                                                    get:@selector(getPrefBool:)
                                                                 detail:Nil
                                                                   cell:PSSwitchCell
                                                                   edit:Nil];
        [deepSwitch setProperty:@"sniffDeeplink" forKey:@"key"];
        [deepSwitch setProperty:@YES forKey:@"default"];
        [specs addObject:deepSwitch];

        PSSpecifier *iapSwitch = [PSSpecifier preferenceSpecifierNamed:@"Bắt API Mua In-App Thành Công"
                                                                target:self
                                                                   set:@selector(setPrefBool:specifier:)
                                                                   get:@selector(getPrefBool:)
                                                                detail:Nil
                                                                  cell:PSSwitchCell
                                                                  edit:Nil];
        [iapSwitch setProperty:@"sniffInApp" forKey:@"key"];
        [iapSwitch setProperty:@YES forKey:@"default"];
        [specs addObject:iapSwitch];

        // Nhóm 2: Packet gần nhất thu được (cho phép sửa giá trị)
        PSSpecifier *grp2 = [PSSpecifier groupSpecifierWithName:@"PACKET GẦN NHẤT THU ĐƯỢC (CHỈNH SỬA THAM SỐ)"];
        [grp2 setProperty:@"Có thể trực tiếp sửa các giá trị bên trong như Product ID, Transaction ID, DSID để gửi lại tùy biến." forKey:@"footerText"];
        [specs addObject:grp2];

        PSSpecifier *urlSpec = [PSSpecifier preferenceSpecifierNamed:@"URL Scheme / Deeplink"
                                                              target:self
                                                                 set:@selector(setPrefValue:specifier:)
                                                                 get:@selector(getPrefValue:)
                                                              detail:Nil
                                                                cell:PSEditTextCell
                                                                edit:Nil];
        [urlSpec setProperty:@"capturedURL" forKey:@"key"];
        [urlSpec setProperty:@"itms-appss://..." forKey:@"placeholder"];
        [specs addObject:urlSpec];

        PSSpecifier *prodSpec = [PSSpecifier preferenceSpecifierNamed:@"Product ID (Mã gói In-App)"
                                                               target:self
                                                                  set:@selector(setPrefValue:specifier:)
                                                                  get:@selector(getPrefValue:)
                                                               detail:Nil
                                                                 cell:PSEditTextCell
                                                                 edit:Nil];
        [prodSpec setProperty:@"productID" forKey:@"key"];
        [prodSpec setProperty:@"com.app.product_id" forKey:@"placeholder"];
        [specs addObject:prodSpec];

        PSSpecifier *transSpec = [PSSpecifier preferenceSpecifierNamed:@"Transaction ID (Mã GD)"
                                                                target:self
                                                                   set:@selector(setPrefValue:specifier:)
                                                                   get:@selector(getPrefValue:)
                                                                detail:Nil
                                                                  cell:PSEditTextCell
                                                                  edit:Nil];
        [transSpec setProperty:@"transactionID" forKey:@"key"];
        [transSpec setProperty:@"1000000..." forKey:@"placeholder"];
        [specs addObject:transSpec];

        PSSpecifier *dsidSpec = [PSSpecifier preferenceSpecifierNamed:@"Account / Apple ID DSID"
                                                               target:self
                                                                  set:@selector(setPrefValue:specifier:)
                                                                  get:@selector(getPrefValue:)
                                                               detail:Nil
                                                                 cell:PSEditTextCell
                                                                 edit:Nil];
        [dsidSpec setProperty:@"accountDSID" forKey:@"key"];
        [dsidSpec setProperty:@"DSID số" forKey:@"placeholder"];
        [specs addObject:dsidSpec];

        // Nhóm 3: Chế độ gửi lại Packet (Packet Replayer)
        PSSpecifier *grp3 = [PSSpecifier groupSpecifierWithName:@"CHẾ ĐỘ GỬI LẠI PACKET (PACKET REPLAYER)"];
        [grp3 setProperty:@"Tweak sẽ tiêm lại packet đã sửa trực tiếp vào ứng dụng thông qua dylib để kích hoạt xử lý." forKey:@"footerText"];
        [specs addObject:grp3];

        PSSpecifier *repCount = [PSSpecifier preferenceSpecifierNamed:@"Số Lần Gửi Lại (Repeat Count)"
                                                               target:self
                                                                  set:@selector(setPrefValue:specifier:)
                                                                  get:@selector(getPrefValue:)
                                                               detail:Nil
                                                                 cell:PSEditTextCell
                                                                 edit:Nil];
        [repCount setProperty:@"repeatCount" forKey:@"key"];
        [repCount setProperty:@"1" forKey:@"placeholder"];
        [specs addObject:repCount];

        PSSpecifier *repDelay = [PSSpecifier preferenceSpecifierNamed:@"Độ Trễ Giữa Các Lần Gửi (ms)"
                                                               target:self
                                                                  set:@selector(setPrefValue:specifier:)
                                                                  get:@selector(getPrefValue:)
                                                               detail:Nil
                                                                 cell:PSEditTextCell
                                                                 edit:Nil];
        [repDelay setProperty:@"replayDelayMs" forKey:@"key"];
        [repDelay setProperty:@"500" forKey:@"placeholder"];
        [specs addObject:repDelay];

        PSSpecifier *btnReplay = [PSSpecifier preferenceSpecifierNamed:@"🚀 GỬI LẠI PACKET QUA FILE .DYLIB"
                                                                target:self
                                                                   set:NULL
                                                                   get:NULL
                                                                detail:Nil
                                                                  cell:PSButtonCell
                                                                  edit:Nil];
        [btnReplay setButtonAction:@selector(actionReplayPacket:)];
        [specs addObject:btnReplay];

        PSSpecifier *btnCopy = [PSSpecifier preferenceSpecifierNamed:@"📋 Sao Chép Payload Packet (JSON)"
                                                              target:self
                                                                 set:NULL
                                                                 get:NULL
                                                              detail:Nil
                                                                cell:PSButtonCell
                                                                edit:Nil];
        [btnCopy setButtonAction:@selector(actionCopyJSON:)];
        [specs addObject:btnCopy];

        PSSpecifier *btnClear = [PSSpecifier preferenceSpecifierNamed:@"🗑 Xóa Lịch Sử Packet"
                                                               target:self
                                                                  set:NULL
                                                                  get:NULL
                                                               detail:Nil
                                                                 cell:PSButtonCell
                                                                 edit:Nil];
        [btnClear setButtonAction:@selector(actionClearHistory:)];
        [specs addObject:btnClear];

        _specifiers = specs;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = @"📡 Thu Bắt & Replay Packet";
}

#pragma mark - Getters / Setters

- (id)getPrefBool:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSNumber *val = self.replayerConfig[key];
    return val ?: [specifier propertyForKey:@"default"];
}

- (void)setPrefBool:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    [self.replayerConfig setObject:value forKey:key];
    [self saveConfig];
}

- (id)getPrefValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    return self.replayerConfig[key] ?: [specifier propertyForKey:@"placeholder"];
}

- (void)setPrefValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    [self.replayerConfig setObject:value forKey:key];
    [self saveConfig];
}

#pragma mark - Actions

- (void)actionReplayPacket:(PSSpecifier *)specifier {
    NSInteger repeat = [self.replayerConfig[@"repeatCount"] integerValue] ?: 1;
    NSString *prod = self.replayerConfig[@"productID"] ?: @"";
    NSString *trans = self.replayerConfig[@"transactionID"] ?: @"";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Replay Packet Thành Công"
                                                                   message:[NSString stringWithFormat:@"Đã phát lại %ld lần gói tin qua AppAgent.dylib:\nProduct: %@\nTransaction: %@", (long)repeat, prod, trans]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Tuyệt Vời" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)actionCopyJSON:(PSSpecifier *)specifier {
    NSDictionary *payload = @{
        @"action": @"replay_packet",
        @"url": self.replayerConfig[@"capturedURL"] ?: @"",
        @"product_id": self.replayerConfig[@"productID"] ?: @"",
        @"transaction_id": self.replayerConfig[@"transactionID"] ?: @"",
        @"dsid": self.replayerConfig[@"accountDSID"] ?: @""
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [UIPasteboard generalPasteboard].string = jsonStr;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đã Sao Chép"
                                                                   message:@"Payload JSON của packet đã được copy vào bộ nhớ tạm Clipboard."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)actionClearHistory:(PSSpecifier *)specifier {
    self.replayerConfig[@"capturedURL"] = @"";
    self.replayerConfig[@"productID"] = @"";
    self.replayerConfig[@"transactionID"] = @"";
    self.replayerConfig[@"accountDSID"] = @"";
    [self saveConfig];
    [self reloadSpecifiers];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đã Làm Sạch"
                                                                   message:@"Đã xóa toàn bộ dữ liệu packet đã ghi."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
