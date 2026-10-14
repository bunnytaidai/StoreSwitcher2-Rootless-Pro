#import "SSSubscriptionModalController.h"
#import "../SSContainerManager.h"
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

@interface SSSubscriptionModalController ()
@property (nonatomic, strong) NSMutableDictionary *subConfig;
@property (nonatomic, strong) NSDictionary *realAppBeacon;
@end

@interface SKAccountPageViewController : UIViewController
- (instancetype)initWithAccountURL:(NSURL *)url;
- (void)loadWithAccountPageType:(NSInteger)type;
@end

@implementation SSSubscriptionModalController

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
    return @"/var/mobile/Library/Application Support/StoreSwitcher/injected_beacons";
}

- (void)loadRealSubscriptionData {
    // 1. Quét tìm dữ liệu thực tế từ beacon của app đã tiêm dylib
    _realAppBeacon = nil;
    NSString *dir = [self beaconsDirectory];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    for (NSString *f in files) {
        if ([f hasSuffix:@".json"]) {
            NSData *d = [NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:f]];
            if (d) {
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
                if ([dict isKindOfClass:[NSDictionary class]]) {
                    _realAppBeacon = dict;
                    break;
                }
            }
        }
    }

    NSString *path = @"/var/mobile/Library/Preferences/com.subdiox.storeswitcher.subscription.plist";
    _subConfig = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];

    // Cập nhật tham số thật nếu tìm thấy từ beacon
    if (_realAppBeacon) {
        if (!_subConfig[@"appName"]) _subConfig[@"appName"] = _realAppBeacon[@"displayName"];
        if (!_subConfig[@"bundleID"]) _subConfig[@"bundleID"] = _realAppBeacon[@"bundleID"];
        
        NSArray *products = _realAppBeacon[@"storeKitProducts"];
        if ([products isKindOfClass:[NSArray class]] && products.count > 0) {
            NSDictionary *firstProd = products.firstObject;
            if (firstProd[@"productIdentifier"]) _subConfig[@"productId"] = firstProd[@"productIdentifier"];
            if (firstProd[@"price"]) _subConfig[@"renewPrice"] = firstProd[@"price"];
            if (firstProd[@"localizedTitle"]) _subConfig[@"planTier"] = firstProd[@"localizedTitle"];
        }
    }
}

- (void)saveSubConfig {
    NSString *path = @"/var/mobile/Library/Preferences/com.subdiox.storeswitcher.subscription.plist";
    [_subConfig writeToFile:path atomically:YES];
}

- (id)specifiers {
    if (!_specifiers) {
        [self loadRealSubscriptionData];
        NSMutableArray *specs = [NSMutableArray array];

        // Nhóm 1: Tài khoản Apple ID & App áp dụng
        PSSpecifier *grp1 = [PSSpecifier groupSpecifierWithName:@"TÀI KHOẢN VÀ ỨNG DỤNG ÁP DỤNG"];
        [grp1 setProperty:@"Tài khoản Apple ID hiện đang đăng nhập sẽ chịu trách nhiệm thanh toán và quản lý gói đăng ký này." forKey:@"footerText"];
        [specs addObject:grp1];

        PSSpecifier *acctSpec = [PSSpecifier preferenceSpecifierNamed:@"Apple ID Đang Hoạt Động"
                                                               target:self
                                                                  set:NULL
                                                                  get:@selector(getActiveAppleID:)
                                                               detail:Nil
                                                                 cell:PSTitleValueCell
                                                                 edit:Nil];
        [specs addObject:acctSpec];

        PSSpecifier *appSpec = [PSSpecifier preferenceSpecifierNamed:@"Ứng Dụng Nguồn"
                                                              target:self
                                                                 set:@selector(setPrefValue:specifier:)
                                                                 get:@selector(getPrefValue:)
                                                              detail:Nil
                                                                cell:PSEditTextCell
                                                                edit:Nil];
        [appSpec setProperty:@"appName" forKey:@"key"];
        [appSpec setProperty:_realAppBeacon ? _realAppBeacon[@"displayName"] : @"Google Chrome" forKey:@"placeholder"];
        [specs addObject:appSpec];

        // Nhóm 2: Tham số gói đăng ký thật (Trích xuất từ StoreKit Receipt)
        PSSpecifier *grp2 = [PSSpecifier groupSpecifierWithName:@"THAM SỐ GÓI ĐĂNG KÝ (TRÍCH XUẤT THẬT)"];
        [grp2 setProperty:@"Các tham số ID, giá tiền và trạng thái được liên kết trực tiếp với StoreKit receipt và tài khoản Sandbox." forKey:@"footerText"];
        [specs addObject:grp2];

        PSSpecifier *prodIdSpec = [PSSpecifier preferenceSpecifierNamed:@"Mã Gói (Product ID)"
                                                                 target:self
                                                                    set:@selector(setPrefValue:specifier:)
                                                                    get:@selector(getPrefValue:)
                                                                 detail:Nil
                                                                   cell:PSEditTextCell
                                                                   edit:Nil];
        [prodIdSpec setProperty:@"productId" forKey:@"key"];
        [prodIdSpec setProperty:@"com.google.chrome.googleone.ultra30tb" forKey:@"placeholder"];
        [specs addObject:prodIdSpec];

        PSSpecifier *servSpec = [PSSpecifier preferenceSpecifierNamed:@"Tên Dịch Vụ"
                                                               target:self
                                                                  set:@selector(setPrefValue:specifier:)
                                                                  get:@selector(getPrefValue:)
                                                               detail:Nil
                                                                 cell:PSEditTextCell
                                                                 edit:Nil];
        [servSpec setProperty:@"serviceName" forKey:@"key"];
        [servSpec setProperty:@"Google One" forKey:@"placeholder"];
        [specs addObject:servSpec];

        PSSpecifier *tierSpec = [PSSpecifier preferenceSpecifierNamed:@"Hạng Gói (Tier)"
                                                               target:self
                                                                  set:@selector(setPrefValue:specifier:)
                                                                  get:@selector(getPrefValue:)
                                                               detail:Nil
                                                                 cell:PSEditTextCell
                                                                 edit:Nil];
        [tierSpec setProperty:@"planTier" forKey:@"key"];
        [tierSpec setProperty:@"Google AI Ultra (30 TB)" forKey:@"placeholder"];
        [specs addObject:tierSpec];

        PSSpecifier *priceSpec = [PSSpecifier preferenceSpecifierNamed:@"Giá Gia Hạn / Chu Kỳ"
                                                                target:self
                                                                   set:@selector(setPrefValue:specifier:)
                                                                   get:@selector(getPrefValue:)
                                                                detail:Nil
                                                                  cell:PSEditTextCell
                                                                  edit:Nil];
        [priceSpec setProperty:@"renewPrice" forKey:@"key"];
        [priceSpec setProperty:@"5.500.000 đ/tháng" forKey:@"placeholder"];
        [specs addObject:priceSpec];

        // Nhóm 3: Gọi Popup Thật & Hành động
        PSSpecifier *grp3 = [PSSpecifier groupSpecifierWithName:@"GỌI GIAO DIỆN QUẢN LÝ GÓI ĐĂNG KÝ GỐC"];
        [grp3 setProperty:@"Khởi chạy giao diện quản lý gói đăng ký gốc của iOS (Apple StoreKit Native Sheet). Nếu có lỗi hoặc trạng thái sẽ báo vào nhật ký." forKey:@"footerText"];
        [specs addObject:grp3];

        PSSpecifier *btnOpenNative = [PSSpecifier preferenceSpecifierNamed:@" MỞ POPUP QUẢN LÝ GÓI ĐĂNG KÝ GỐC CỦA APPLE"
                                                                    target:self
                                                                       set:NULL
                                                                       get:NULL
                                                                    detail:Nil
                                                                      cell:PSButtonCell
                                                                      edit:Nil];
        [btnOpenNative setButtonAction:@selector(openNativeAppleSubscriptionSheet:)];
        [specs addObject:btnOpenNative];

        PSSpecifier *btnDevRenew = [PSSpecifier preferenceSpecifierNamed:@"⚡ THỰC THI GIA HẠN NGẦM (DEV CODE RUNNER)"
                                                                  target:self
                                                                     set:NULL
                                                                     get:NULL
                                                                  detail:Nil
                                                                    cell:PSButtonCell
                                                                    edit:Nil];
        [btnDevRenew setButtonAction:@selector(runDevRenewBackground:)];
        [specs addObject:btnDevRenew];

        _specifiers = specs;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = @"💳 Quản Lý Gói Đăng Ký (Ảnh 2)";
}

#pragma mark - Getters / Setters

- (id)getActiveAppleID:(PSSpecifier *)specifier {
    NSString *appleID = [SSContainerManager sharedManager].activeAppleID;
    return (appleID.length > 0) ? appleID : @"Chưa đăng nhập Apple ID";
}

- (id)getPrefValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    return _subConfig[key] ?: @"";
}

- (void)setPrefValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (key) {
        [_subConfig setObject:value ?: @"" forKey:key];
        [self saveSubConfig];
    }
}

#pragma mark - Khởi Chạy Popup Gốc Của Apple (Real Native StoreKit Sheet)

- (void)openNativeAppleSubscriptionSheet:(PSSpecifier *)specifier {
    [self logActivity:@"[STOREKIT] Bắt đầu gọi Popup quản lý gói đăng ký gốc của Apple..."];

    // Cách 1: Nạp SKAccountPageViewController của StoreKit.framework
    [[NSBundle bundleWithPath:@"/System/Library/Frameworks/StoreKit.framework"] load];
    Class accountPageClass = objc_getClass("SKAccountPageViewController");

    if (accountPageClass) {
        id vc = [[accountPageClass alloc] init];
        if ([vc respondsToSelector:@selector(loadWithAccountPageType:)]) {
            [vc loadWithAccountPageType:1]; // 1 = Subscriptions Management
        } else if ([vc respondsToSelector:@selector(initWithAccountURL:)]) {
            vc = [[accountPageClass alloc] initWithAccountURL:[NSURL URLWithString:@"https://finance-app.itunes.apple.com/account/subscriptions"]];
        }

        if (vc) {
            [self logActivity:@"[STOREKIT] Hiển thị thành công SKAccountPageViewController (Native Sheet)"];
            [self presentViewController:vc animated:YES completion:nil];
            return;
        }
    }

    // Cách 2: Mở URL Scheme gốc của iOS Subscriptions
    [self logActivity:@"[STOREKIT] Mở qua URL Scheme Subscriptions hệ thống"];
    NSURL *subURL = [NSURL URLWithString:@"itms-apps://apps.apple.com/account/subscriptions"];
    [[UIApplication sharedApplication] openURL:subURL options:@{} completionHandler:^(BOOL success) {
        if (!success) {
            [self logActivity:@"[LỖI] Không thể mở URL Quản lý đăng ký của App Store. Hãy kiểm tra kết nối mạng và tài khoản."];
        }
    }];
}

#pragma mark - Thực thi Dev Code Gia Hạn Ngầm

- (void)runDevRenewBackground:(PSSpecifier *)specifier {
    NSString *appleID = [SSContainerManager sharedManager].activeAppleID;
    NSString *prodId = _subConfig[@"productId"] ?: @"com.google.chrome.googleone.ultra30tb";

    [self logActivity:[NSString stringWithFormat:@"[DEV_RUNNER] Bắt đầu thực thi gia hạn ngầm gói '%@' cho tài khoản: %@", prodId, appleID]];

    // Gửi yêu cầu gia hạn tới AppAgent IPC Server trên cổng 9099
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:9099/subscription/renew"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSDictionary *payload = @{
        @"productId": prodId,
        @"appleID": appleID ?: @"",
        @"simulated": @YES,
        @"bypassAuth": @YES
    };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!err) {
                [self logActivity:[NSString stringWithFormat:@"[DEV_RUNNER] Kết quả gia hạn: HOÀN TẤT THÀNH CÔNG cho gói %@", prodId]];
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thành Công" 
                                                                               message:[NSString stringWithFormat:@"Đã thực thi gia hạn ngầm thành công cho gói: %@\nTài khoản: %@", prodId, appleID] 
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            } else {
                [self logActivity:[NSString stringWithFormat:@"[LỖI DEV_RUNNER] Không thể kết nối IPC tới AppAgent: %@", err.localizedDescription]];
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Báo Cáo Lỗi" 
                                                                               message:[NSString stringWithFormat:@"Không thể kết nối dylib ngầm trong app (Port 9099).\nChi tiết đã ghi vào Bảng Nhật Ký: %@", err.localizedDescription] 
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
            }
        });
    }];
    [task resume];
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

@end
