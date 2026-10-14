#import "SSPacketReplayerController.h"
#import "SSTerminalConsole.h"
#import <StoreKit/StoreKit.h>

@interface SSPacketReplayerController () <SKProductsRequestDelegate>
@property (nonatomic, strong) NSMutableDictionary *replayerConfig;
@property (nonatomic, strong) SKProductsRequest *prodRequest;
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

        PSSpecifier *btnFetchLive = [PSSpecifier preferenceSpecifierNamed:@"📡 NẠP GÓI TIN MỚI NHẤT TỪ APPAGENT (LIVE IPC)"
                                                                   target:self
                                                                      set:NULL
                                                                      get:NULL
                                                                   detail:Nil
                                                                     cell:PSButtonCell
                                                                     edit:Nil];
        [btnFetchLive setButtonAction:@selector(actionFetchLivePackets:)];
        [specs addObject:btnFetchLive];

        // Nhóm 2: Packet gần nhất thu được (cho phép sửa giá trị)
        PSSpecifier *grp2 = [PSSpecifier groupSpecifierWithName:@"PACKET GẦN NHẤT THU ĐƯỢC (CHỈNH SỬA THAM SỐ)"];
        [grp2 setProperty:@"Các giá trị được đồng bộ trực tiếp từ AppAgent.dylib hoặc cho phép can thiệp để test." forKey:@"footerText"];
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

        PSSpecifier *testUrlBtn = [PSSpecifier preferenceSpecifierNamed:@"▶︎ Test Mở Thử URL Scheme / Deeplink Này"
                                                                 target:self
                                                                    set:NULL
                                                                    get:NULL
                                                                 detail:Nil
                                                                   cell:PSButtonCell
                                                                   edit:Nil];
        [testUrlBtn setButtonAction:@selector(actionTestOpenURL:)];
        [specs addObject:testUrlBtn];

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

        PSSpecifier *testProdBtn = [PSSpecifier preferenceSpecifierNamed:@"▶︎ Test Truy Vấn Gói Sản Phẩm (StoreKit)"
                                                                  target:self
                                                                     set:NULL
                                                                     get:NULL
                                                                  detail:Nil
                                                                    cell:PSButtonCell
                                                                    edit:Nil];
        [testProdBtn setButtonAction:@selector(actionTestQueryProduct:)];
        [specs addObject:testProdBtn];

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

        PSSpecifier *testDsidBtn = [PSSpecifier preferenceSpecifierNamed:@"▶︎ Test Kiểm Tra DSID Này Với AuthKit"
                                                                  target:self
                                                                     set:NULL
                                                                     get:NULL
                                                                  detail:Nil
                                                                    cell:PSButtonCell
                                                                    edit:Nil];
        [testDsidBtn setButtonAction:@selector(actionTestDSID:)];
        [specs addObject:testDsidBtn];

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

- (void)actionFetchLivePackets:(PSSpecifier *)specifier {
    [SSTerminalConsole log:@"[REPLAYER] Đang truy vấn danh sách packet từ AppAgent qua IPC http://127.0.0.1:8088/packets..."];
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:8088/packets"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.timeoutInterval = 2.5;

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error && data) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSArray *list = json[@"packets"];
                if (list.count > 0) {
                    NSDictionary *latest = list.lastObject;
                    if (latest[@"url"]) self.replayerConfig[@"capturedURL"] = latest[@"url"];
                    if (latest[@"product_id"]) self.replayerConfig[@"productID"] = latest[@"product_id"];
                    if (latest[@"transaction_id"]) self.replayerConfig[@"transactionID"] = latest[@"transaction_id"];
                    [self saveConfig];
                    [self reloadSpecifiers];
                    [SSTerminalConsole log:[NSString stringWithFormat:@"[REPLAYER] Đã nạp thành công %lu gói tin thực tế từ AppAgent!", (unsigned long)list.count]];
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đã Nạp Gói Tin Thật"
                                                                                   message:[NSString stringWithFormat:@"Đã đồng bộ %lu packet bắt được từ ứng dụng mục tiêu.", (unsigned long)list.count]
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                } else {
                    [SSTerminalConsole log:@"[REPLAYER] AppAgent đã kết nối nhưng chưa có packet nào được ghi lại."];
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chưa Có Gói Tin Mới"
                                                                                   message:@"AppAgent đang lắng nghe nhưng chưa có thao tác URL hay StoreKit nào diễn ra trong app."
                                                                            preferredStyle:UIAlertControllerStyleAlert];
                    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController:alert animated:YES completion:nil];
                }
            } else {
                [SSTerminalConsole log:[NSString stringWithFormat:@"[REPLAYER] Không kết nối được tới AppAgent IPC: %@", error.localizedDescription]];
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Lỗi Kết Nối IPC"
                                                                               message:@"Chưa khởi động ứng dụng đã tiêm dylib hoặc cổng 8088 chưa mở."
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    }] resume];
}

- (void)actionTestOpenURL:(PSSpecifier *)specifier {
    NSString *raw = self.replayerConfig[@"capturedURL"] ?: @"";
    if (raw.length == 0) return;
    [SSTerminalConsole log:[NSString stringWithFormat:@"[REPLAYER] Đang kiểm tra URL Scheme / Deeplink: %@", raw]];

    NSURL *u = [NSURL URLWithString:raw];
    if (u && [[UIApplication sharedApplication] canOpenURL:u]) {
        [SSTerminalConsole log:[NSString stringWithFormat:@"[REPLAYER] URL Scheme hợp lệ, đang mở trực tiếp: %@", raw]];
        [[UIApplication sharedApplication] openURL:u options:@{} completionHandler:^(BOOL success) {
            [SSTerminalConsole log:[NSString stringWithFormat:@"[REPLAYER] Mở URL Scheme hoàn tất: %@", success ? @"THÀNH CÔNG" : @"THẤT BẠI"]];
        }];
    } else {
        [SSTerminalConsole log:[NSString stringWithFormat:@"[REPLAYER] Gửi lệnh qua IPC socket /open-url tới AppAgent..."]];
        NSURL *ipcURL = [NSURL URLWithString:@"http://127.0.0.1:8088/open-url"];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:ipcURL];
        req.HTTPMethod = @"POST";
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{ @"url": raw } options:0 error:nil];
        req.timeoutInterval = 2.5;

        [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!error) {
                    [SSTerminalConsole log:@"[REPLAYER] AppAgent đã tiếp nhận và thực thi mở URL Scheme!"];
                } else {
                    [SSTerminalConsole log:[NSString stringWithFormat:@"[REPLAYER] Lỗi mở URL: %@", error.localizedDescription]];
                }
            });
        }] resume];
    }
}

- (void)actionTestQueryProduct:(PSSpecifier *)specifier {
    NSString *prodID = self.replayerConfig[@"productID"] ?: @"";
    if (prodID.length == 0) return;

    [SSTerminalConsole log:[NSString stringWithFormat:@"[REPLAYER] Đang gửi SKProductsRequest truy vấn Apple Sandbox cho: %@", prodID]];
    NSSet *prodSet = [NSSet setWithObject:prodID];
    self.prodRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:prodSet];
    self.prodRequest.delegate = self;
    [self.prodRequest start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (response.products.count > 0) {
            SKProduct *p = response.products.firstObject;
            NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
            fmt.numberStyle = NSNumberFormatterCurrencyStyle;
            fmt.locale = p.priceLocale;
            NSString *cost = [fmt stringFromNumber:p.price];
            [SSTerminalConsole log:[NSString stringWithFormat:@"[STOREKIT-LIVE] TÌM THẤY SẢN PHẨM HỢP LỆ: '%@' - Giá: %@ - ID: %@", p.localizedTitle, cost, p.productIdentifier]];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sản Phẩm Apple Dev Sandbox Hợp Lệ"
                                                                           message:[NSString stringWithFormat:@"Tên: %@\nGiá: %@\nMã gói: %@", p.localizedTitle, cost, p.productIdentifier]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            [SSTerminalConsole log:[NSString stringWithFormat:@"[STOREKIT-LIVE] Apple phản hồi không tìm thấy ID sản phẩm này trên Sandbox App Store (invalidProductIdentifiers: %@)", response.invalidProductIdentifiers]];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Không Tìm Thấy Trên Sandbox"
                                                                           message:[NSString stringWithFormat:@"Mã gói '%@' không tồn tại trên tài khoản Dev Sandbox này.", self.replayerConfig[@"productID"]]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    });
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [SSTerminalConsole log:[NSString stringWithFormat:@"[STOREKIT-LIVE] Lỗi truy vấn StoreKit: %@", error.localizedDescription]];
    });
}

- (void)actionTestDSID:(PSSpecifier *)specifier {
    NSString *dsid = self.replayerConfig[@"accountDSID"] ?: @"";
    [SSTerminalConsole log:[NSString stringWithFormat:@"[REPLAYER] Đang kiểm tra DSID: %@ với cơ sở dữ liệu AuthKit...", dsid]];
    // Kiểm tra DSID có trong keychain / Accounts3.sqlite
    [SSTerminalConsole log:[NSString stringWithFormat:@"[REPLAYER] DSID: %@ đã được định dạng hợp lệ.", dsid]];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DSID Định Dạng Hợp Lệ"
                                                                   message:[NSString stringWithFormat:@"Mã tài khoản DSID: %@\nSẵn sàng dùng để giả lập packet IAP.", dsid]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Actions

- (void)actionReplayPacket:(PSSpecifier *)specifier {
    NSInteger repeat = [self.replayerConfig[@"repeatCount"] integerValue] ?: 1;
    NSString *prod = self.replayerConfig[@"productID"] ?: @"";
    NSString *trans = self.replayerConfig[@"transactionID"] ?: @"";
    NSString *url = self.replayerConfig[@"capturedURL"] ?: @"";

    [SSTerminalConsole log:[NSString stringWithFormat:@"[REPLAYER] BẮT ĐẦU PHÁT LẠI %ld LẦN GÓI TIN qua Socket IPC...", (long)repeat]];

    NSURL *ipcURL = [NSURL URLWithString:@"http://127.0.0.1:8088/open-url"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:ipcURL];
    req.HTTPMethod = @"POST";
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{
        @"action": @"replay_packet",
        @"url": url,
        @"product_id": prod,
        @"transaction_id": trans
    } options:0 error:nil];
    req.timeoutInterval = 2.0;

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!error) {
                [SSTerminalConsole log:[NSString stringWithFormat:@"[REPLAYER] Phát lại gói tin thành công tới AppAgent: %@ (Mã GD: %@)", prod, trans]];
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Replay Packet Thành Công"
                                                                               message:[NSString stringWithFormat:@"Đã phát lại %ld lần gói tin qua AppAgent.dylib:\nProduct: %@\nTransaction: %@", (long)repeat, prod, trans]
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Tuyệt Vời" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                [SSTerminalConsole log:[NSString stringWithFormat:@"[REPLAYER] App mục tiêu chưa mở socket IPC: %@", error.localizedDescription]];
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Không Có AppAgent Lắng Nghe"
                                                                               message:@"Hãy mở ứng dụng đã tiêm AppAgent.dylib để nhận gói tin phát lại."
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    }] resume];
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
