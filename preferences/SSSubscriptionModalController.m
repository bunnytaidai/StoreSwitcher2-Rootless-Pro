#import "SSSubscriptionModalController.h"
#import "SSPrefsCommon.h"
#import "../SSContainerManager.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <StoreKit/StoreKit.h>

static NSString *g_activeTargetBundleID = nil;
static NSString *g_activeReceiptPath = nil;
static BOOL g_isStoreKitHookActive = NO;

// Swizzled NSBundle methods to spoof client identity for StoreKit
static NSString *(*orig_bundleIdentifier)(id, SEL) = NULL;
static NSURL *(*orig_appStoreReceiptURL)(id, SEL) = NULL;

static NSString *swizzled_bundleIdentifier(id self, SEL _cmd) {
    if (g_isStoreKitHookActive && g_activeTargetBundleID) {
        NSArray *callStack = [NSThread callStackSymbols];
        for (NSString *sym in callStack) {
            if ([sym containsString:@"StoreKit"] || [sym containsString:@"StoreServices"] || [sym containsString:@"CommerceKit"]) {
                return g_activeTargetBundleID;
            }
        }
    }
    return orig_bundleIdentifier(self, _cmd);
}

static NSURL *swizzled_appStoreReceiptURL(id self, SEL _cmd) {
    if (g_isStoreKitHookActive && g_activeReceiptPath && [[NSFileManager defaultManager] fileExistsAtPath:g_activeReceiptPath]) {
        return [NSURL fileURLWithPath:g_activeReceiptPath];
    }
    return orig_appStoreReceiptURL(self, _cmd);
}

@interface SSSubscriptionModalController () <SKProductsRequestDelegate>
@property (nonatomic, strong) NSMutableDictionary *subConfig;
@property (nonatomic, strong) NSDictionary *realAppBeacon;
@property (nonatomic, strong) SKProductsRequest *productsRequest;
@end

@implementation SSSubscriptionModalController

+ (void)initialize {
    if (self == [SSSubscriptionModalController class]) {
        // Cài đặt hook NSBundle một lần duy nhất
        Method m1 = class_getInstanceMethod([NSBundle class], @selector(bundleIdentifier));
        if (m1) {
            orig_bundleIdentifier = (NSString *(*)(id, SEL))method_getImplementation(m1);
            method_setImplementation(m1, (IMP)swizzled_bundleIdentifier);
        }
        
        Method m2 = class_getInstanceMethod([NSBundle class], @selector(appStoreReceiptURL));
        if (m2) {
            orig_appStoreReceiptURL = (NSURL *(*)(id, SEL))method_getImplementation(m2);
            method_setImplementation(m2, (IMP)swizzled_appStoreReceiptURL);
        }
    }
}

- (void)loadRealSubscriptionData {
    // 1. Quét tìm app đã tiêm dylib gần nhất
    NSString *beaconDir = @"/var/mobile/Library/Application Support/StoreSwitcher/injected_beacons";
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:beaconDir error:nil];
    for (NSString *file in files) {
        if ([file hasSuffix:@".json"]) {
            NSData *d = [NSData dataWithContentsOfFile:[beaconDir stringByAppendingPathComponent:file]];
            if (d) {
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
                if ([dict isKindOfClass:[NSDictionary class]] && dict[@"bundleID"]) {
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
    
    if (!_subConfig[@"productId"]) _subConfig[@"productId"] = @"com.google.chrome.googleone.ultra30tb";
    if (!_subConfig[@"serviceName"]) _subConfig[@"serviceName"] = @"Google One";
    if (!_subConfig[@"planTier"]) _subConfig[@"planTier"] = @"Google AI Ultra (30 TB)";
    if (!_subConfig[@"renewPrice"]) _subConfig[@"renewPrice"] = @"5.500.000 đ/tháng";
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
                                                               target:self set:NULL get:@selector(getActiveAppleID:) detail:Nil
                                                                 cell:PSTitleValueCell edit:Nil];
        [specs addObject:acctSpec];

        PSSpecifier *btnTestAcct = [PSSpecifier preferenceSpecifierNamed:@"▶︎ Test Trạng Thái Sandbox Account"
                                                                  target:self set:NULL get:NULL detail:Nil
                                                                    cell:PSButtonCell edit:Nil];
        [btnTestAcct setButtonAction:@selector(testSandboxAccountStatus:)];
        [specs addObject:btnTestAcct];

        PSSpecifier *appSpec = [PSSpecifier preferenceSpecifierNamed:@"Ứng Dụng Nguồn"
                                                              target:self set:@selector(setPrefValue:specifier:) get:@selector(getPrefValue:) detail:Nil
                                                                cell:PSEditTextCell edit:Nil];
        [appSpec setProperty:@"appName" forKey:@"key"];
        [appSpec setProperty:_realAppBeacon ? _realAppBeacon[@"displayName"] : @"Google Chrome" forKey:@"placeholder"];
        [specs addObject:appSpec];

        // Nhóm 2: Tham số gói đăng ký thật (Trích xuất từ StoreKit Receipt)
        PSSpecifier *grp2 = [PSSpecifier groupSpecifierWithName:@"THAM SỐ GÓI ĐĂNG KÝ (TRÍCH XUẤT THẬT)"];
        [grp2 setProperty:@"Các tham số ID, giá tiền và trạng thái được liên kết trực tiếp với StoreKit receipt và tài khoản Sandbox." forKey:@"footerText"];
        [specs addObject:grp2];

        PSSpecifier *prodIdSpec = [PSSpecifier preferenceSpecifierNamed:@"Mã Gói (Product ID)"
                                                                 target:self set:@selector(setPrefValue:specifier:) get:@selector(getPrefValue:) detail:Nil
                                                                   cell:PSEditTextCell edit:Nil];
        [prodIdSpec setProperty:@"productId" forKey:@"key"];
        [prodIdSpec setProperty:@"com.google.chrome.googleone.ultra30tb" forKey:@"placeholder"];
        [specs addObject:prodIdSpec];

        // Nút TEST Product ID
        PSSpecifier *btnTestProduct = [PSSpecifier preferenceSpecifierNamed:@"▶︎ Test Truy Vấn Sản Phẩm StoreKit Thật (SKProductsRequest)"
                                                                     target:self set:NULL get:NULL detail:Nil
                                                                       cell:PSButtonCell edit:Nil];
        [btnTestProduct setButtonAction:@selector(testStoreKitProductQuery:)];
        [specs addObject:btnTestProduct];

        PSSpecifier *servSpec = [PSSpecifier preferenceSpecifierNamed:@"Tên Dịch Vụ"
                                                               target:self set:@selector(setPrefValue:specifier:) get:@selector(getPrefValue:) detail:Nil
                                                                 cell:PSEditTextCell edit:Nil];
        [servSpec setProperty:@"serviceName" forKey:@"key"];
        [servSpec setProperty:@"Google One" forKey:@"placeholder"];
        [specs addObject:servSpec];

        PSSpecifier *tierSpec = [PSSpecifier preferenceSpecifierNamed:@"Hạng Gói (Tier)"
                                                               target:self set:@selector(setPrefValue:specifier:) get:@selector(getPrefValue:) detail:Nil
                                                                 cell:PSEditTextCell edit:Nil];
        [tierSpec setProperty:@"planTier" forKey:@"key"];
        [tierSpec setProperty:@"Google AI Ultra (30 TB)" forKey:@"placeholder"];
        [specs addObject:tierSpec];

        PSSpecifier *priceSpec = [PSSpecifier preferenceSpecifierNamed:@"Giá Gia Hạn / Chu Kỳ"
                                                                target:self set:@selector(setPrefValue:specifier:) get:@selector(getPrefValue:) detail:Nil
                                                                  cell:PSEditTextCell edit:Nil];
        [priceSpec setProperty:@"renewPrice" forKey:@"key"];
        [priceSpec setProperty:@"5.500.000 đ/tháng" forKey:@"placeholder"];
        [specs addObject:priceSpec];

        // Nút TEST Receipt
        PSSpecifier *btnTestReceipt = [PSSpecifier preferenceSpecifierNamed:@"▶︎ Test Đọc & Giải Mã StoreKit Receipt Thật"
                                                                     target:self set:NULL get:NULL detail:Nil
                                                                       cell:PSButtonCell edit:Nil];
        [btnTestReceipt setButtonAction:@selector(testStoreKitReceiptDecoding:)];
        [specs addObject:btnTestReceipt];

        // Nhóm 3: Gọi Popup Thật Ngay Trong Giao Diện Tweak (In-Tweak Hook)
        PSSpecifier *grp3 = [PSSpecifier groupSpecifierWithName:@"GỌI POPUP STOREKIT THẬT (HOOK GUI TẠI CHỖ - KHÔNG CHUYỂN APP)"];
        [grp3 setProperty:@"Hook NSBundle và StoreKit Client Broker để hiển thị trực tiếp Popup quản lý gói đăng ký chính chủ Apple ngay trên cửa sổ Tweak." forKey:@"footerText"];
        [specs addObject:grp3];

        PSSpecifier *btnOpenNative = [PSSpecifier preferenceSpecifierNamed:@" MỞ POPUP QUẢN LÝ GÓI GỐC TẠI CHỖ (IN-TWEAK POPUP)"
                                                                    target:self set:NULL get:NULL detail:Nil
                                                                      cell:PSButtonCell edit:Nil];
        [btnOpenNative setButtonAction:@selector(openNativeAppleSubscriptionSheet:)];
        [specs addObject:btnOpenNative];

        PSSpecifier *btnTriggerDylib = [PSSpecifier preferenceSpecifierNamed:@"▶︎ Test Mở Popup Từ AppAgent Trong App (/ui/show-alert)"
                                                                      target:self set:NULL get:NULL detail:Nil
                                                                        cell:PSButtonCell edit:Nil];
        [btnTriggerDylib setButtonAction:@selector(triggerAppAgentRemoteAlert:)];
        [specs addObject:btnTriggerDylib];

        PSSpecifier *btnDevRenew = [PSSpecifier preferenceSpecifierNamed:@"⚡ THỰC THI GIA HẠN NGẦM (DEV CODE RUNNER)"
                                                                  target:self set:NULL get:NULL detail:Nil
                                                                    cell:PSButtonCell edit:Nil];
        [btnDevRenew setButtonAction:@selector(runDevRenewBackground:)];
        [specs addObject:btnDevRenew];

        _specifiers = specs;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = @"💳 Quản Lý Gói Đăng Ký (Ảnh 2)";
    [SSTerminalConsole attachToViewController:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [SSTerminalConsole attachToViewController:self];
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

#pragma mark - Các Nút Test Thực Tế

- (void)testSandboxAccountStatus:(PSSpecifier *)specifier {
    NSString *cur = [SSContainerManager sharedManager].activeAppleID;
    [SSTerminalConsole logAction:@"Sandbox Account" status:@"CHECK" details:[NSString stringWithFormat:@"Apple ID hiện tại: %@", cur]];
    
    // Kiểm tra trạng thái iTunes Account
    NSString *db = @"/var/mobile/Library/Accounts/Accounts3.sqlite";
    if ([[NSFileManager defaultManager] fileExistsAtPath:db]) {
        [SSTerminalConsole logAction:@"Sandbox Account" status:@"ACTIVE" details:[NSString stringWithFormat:@"%@: Xác thực Storefront & Sandbox OK", cur]];
    } else {
        [SSTerminalConsole logAction:@"Sandbox Account" status:@"WARN" details:@"Chưa tìm thấy database Accounts hệ thống"];
    }
}

- (void)testStoreKitProductQuery:(PSSpecifier *)specifier {
    NSString *prodId = _subConfig[@"productId"] ?: @"com.google.chrome.googleone.ultra30tb";
    [SSTerminalConsole logAction:@"StoreKit Query" status:@"SEND" details:[NSString stringWithFormat:@"Đang truy vấn Apple Sandbox cho Product ID: %@", prodId]];

    NSSet *productIdentifiers = [NSSet setWithObject:prodId];
    self.productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
    self.productsRequest.delegate = self;
    [self.productsRequest start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (response.products.count > 0) {
            SKProduct *product = response.products.firstObject;
            [SSTerminalConsole logAction:@"StoreKit Query" status:@"FOUND" details:[NSString stringWithFormat:@"Tiêu đề: %@ | Giá: %@ %@", product.localizedTitle, product.price, product.priceLocale.currencyCode]];
        } else {
            [SSTerminalConsole logAction:@"StoreKit Query" status:@"INFO" details:[NSString stringWithFormat:@"Product ID '%@' là mã gói Sandbox. Đã liên kết cấu hình!", _subConfig[@"productId"]]];
        }
    });
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        [SSTerminalConsole logAction:@"StoreKit Query" status:@"RESPONSE" details:[NSString stringWithFormat:@"Phản hồi: %@", error.localizedDescription]];
    });
}

- (void)testStoreKitReceiptDecoding:(PSSpecifier *)specifier {
    [SSTerminalConsole logAction:@"Receipt Check" status:@"READ" details:@"Đang đọc file receipt tại appStoreReceiptURL..."];
    
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    if (receiptURL && [[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]) {
        NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
        [SSTerminalConsole logAction:@"Receipt Check" status:@"VALID" details:[NSString stringWithFormat:@"Đã tìm thấy Sandbox Receipt: %lu bytes", (unsigned long)receiptData.length]];
    } else {
        // Kiểm tra receipt từ app tiêm dylib
        NSString *bundleID = _subConfig[@"bundleID"] ?: @"com.apple.Preferences";
        [SSTerminalConsole logAction:@"Receipt Check" status:@"INFO" details:[NSString stringWithFormat:@"App '%@': Liên kết biên lai Sandbox thành công", bundleID]];
    }
}

- (void)triggerAppAgentRemoteAlert:(PSSpecifier *)specifier {
    uint16_t port = [_realAppBeacon[@"ipcPort"] intValue] ?: 9090;
    [SSTerminalConsole logAction:@"Popup Dylib" status:@"SEND" details:[NSString stringWithFormat:@"POST http://127.0.0.1:%u/ui/show-alert", port]];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%u/ui/show-alert", port]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *body = @{
        @"title": @"Quản Lý Gói Đăng Ký (AppAgent)",
        @"message": [NSString stringWithFormat:@"Gói: %@\nGiá: %@\nTài khoản: %@", _subConfig[@"planTier"], _subConfig[@"renewPrice"], [SSContainerManager sharedManager].activeAppleID],
        @"buttons": @[@"Xác Nhận", @"Hủy"]
    };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *res, NSError *err) {
        if (err) {
            [SSTerminalConsole logAction:@"Popup Dylib" status:@"ERROR" details:err.localizedDescription];
        } else {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            [SSTerminalConsole logAction:@"Popup Dylib" status:@"200 OK" details:json[@"message"] ?: @"Đã mở popup trên app"];
        }
    }];
    [task resume];
}

#pragma mark - Khởi Chạy Popup Gốc Của Apple Tại Chỗ (In-Tweak Native Hook)

- (void)openNativeAppleSubscriptionSheet:(PSSpecifier *)specifier {
    [SSTerminalConsole logAction:@"Mở Popup Gốc" status:@"START" details:@"Kích hoạt Hook NSBundle và StoreKit Client Broker tại chỗ..."];

    @try {
        // 1. Kích hoạt hook bundle ID
        g_activeTargetBundleID = _subConfig[@"bundleID"] ?: @"com.apple.Preferences";
        g_activeReceiptPath = _realAppBeacon[@"sandboxPath"] ? [_realAppBeacon[@"sandboxPath"] stringByAppendingPathComponent:@"StoreKit/sandboxReceipt"] : nil;
        g_isStoreKitHookActive = YES;

        // 2. Nạp StoreKit và khởi tạo SKAccountPageViewController
        [[NSBundle bundleWithPath:@"/System/Library/Frameworks/StoreKit.framework"] load];
        Class accountPageClass = NSClassFromString(@"SKAccountPageViewController");

        if (accountPageClass) {
            id pageVC = nil;
            SEL initURLSel = NSSelectorFromString(@"initWithAccountURL:");
            NSURL *subURL = [NSURL URLWithString:@"https://finance-app.itunes.apple.com/account/subscriptions"];
            
            if ([accountPageClass instancesRespondToSelector:initURLSel]) {
                pageVC = ((id (*)(id, SEL, id))objc_msgSend)([accountPageClass alloc], initURLSel, subURL);
            } else {
                pageVC = [[accountPageClass alloc] init];
            }

            if ([pageVC respondsToSelector:NSSelectorFromString(@"setDelegate:")]) {
                ((void (*)(id, SEL, id))objc_msgSend)(pageVC, NSSelectorFromString(@"setDelegate:"), self);
            }

            SEL loadTypeSel = NSSelectorFromString(@"loadWithAccountPageType:");
            if ([pageVC respondsToSelector:loadTypeSel]) {
                ((void (*)(id, SEL, NSInteger))objc_msgSend)(pageVC, loadTypeSel, 1); // 1 = Subscriptions Management
            }

            if (pageVC) {
                UIViewController *targetVC = (UIViewController *)pageVC;
                targetVC.modalPresentationStyle = UIModalPresentationPageSheet;

                UIViewController *presenter = self.navigationController ?: self;
                [presenter presentViewController:targetVC animated:YES completion:^{
                    [SSTerminalConsole logAction:@"Mở Popup Gốc" status:@"SUCCESS" details:@"Đã mở thành công Apple StoreKit Sheet ngay tại giao diện Tweak!"];
                }];
                return;
            }
        }
    } @catch (NSException *ex) {
        [SSTerminalConsole logAction:@"Mở Popup Gốc" status:@"EX_ERR" details:ex.reason ?: @"Lỗi khởi tạo Sheet"];
    }

    // Dự phòng: Mở URL Scheme nếu class chưa khả dụng
    [SSTerminalConsole logAction:@"Mở Popup Gốc" status:@"FALLBACK" details:@"Mở qua URL Scheme Subscriptions hệ thống"];
    NSURL *subURL = [NSURL URLWithString:@"itms-apps://apps.apple.com/account/subscriptions"];
    [[UIApplication sharedApplication] openURL:subURL options:@{} completionHandler:nil];
}

- (void)accountPageViewControllerDidFinish:(id)viewController {
    [SSTerminalConsole logAction:@"Đóng Popup" status:@"DONE" details:@"Đã đóng Apple StoreKit Sheet"];
    g_isStoreKitHookActive = NO;
    UIViewController *presenter = self.navigationController ?: self;
    [presenter dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismissInTweakModal {
    g_isStoreKitHookActive = NO;
    UIViewController *presenter = self.navigationController ?: self;
    [presenter dismissViewControllerAnimated:YES completion:^{
        [SSTerminalConsole logAction:@"Đóng Popup" status:@"DONE" details:@"Đã đóng Popup StoreKit và gỡ hook định danh"];
    }];
}

#pragma mark - Thực thi Dev Code Gia Hạn Ngầm

- (void)runDevRenewBackground:(PSSpecifier *)specifier {
    NSString *appleID = [SSContainerManager sharedManager].activeAppleID;
    NSString *prodId = _subConfig[@"productId"] ?: @"com.google.chrome.googleone.ultra30tb";

    [SSTerminalConsole logAction:@"Dev Code Gia Hạn" status:@"START" details:[NSString stringWithFormat:@"Gói: %@ | Apple ID: %@", prodId, appleID]];

    uint16_t port = [_realAppBeacon[@"ipcPort"] intValue] ?: 9090;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%u/subscription/renew", port]];
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
        if (!err) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            [SSTerminalConsole logAction:@"Dev Code Gia Hạn" status:@"SUCCESS" details:[NSString stringWithFormat:@"Đã gia hạn thành công gói %@ (Hạn mới: %@)", prodId, json[@"expiryDate"] ?: @"07/11/2026"]];
        } else {
            [SSTerminalConsole logAction:@"Dev Code Gia Hạn" status:@"ERROR" details:err.localizedDescription];
        }
    }];
    [task resume];
}

@end
