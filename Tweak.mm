#import <UIKit/UIKit.h>
#import "SSHeader.h"
#import "SSViewController.h"

#pragma mark - Trạm kiểm soát RAM (Soft Swap Manager & Vault)

@interface SSSoftSwapManager ()
@property (nonatomic, strong) NSMutableDictionary *vaultPasswords;
@end

static void handleDarwinCommand(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);

@implementation SSSoftSwapManager

@synthesize isSoftSwapping = _isSoftSwapping;
@synthesize originalAccount = _originalAccount;
@synthesize softSwapAccount = _softSwapAccount;
@synthesize autoFillPasswordEnabled = _autoFillPasswordEnabled;
@synthesize bypassReauthEnabled = _bypassReauthEnabled;
@synthesize autoConfirmPurchaseEnabled = _autoConfirmPurchaseEnabled;
@synthesize customURLScheme = _customURLScheme;
@synthesize customDeepLink = _customDeepLink;
@synthesize customButtons = _customButtons;

+ (instancetype)sharedManager {
  static SSSoftSwapManager *manager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    manager = [[self alloc] init];
  });
  return manager;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _isSoftSwapping = NO;
    _originalAccount = nil;
    _softSwapAccount = nil;
    _autoFillPasswordEnabled = YES;
    _bypassReauthEnabled = YES; // Mặc định bật để triệt tiêu 2FA
    _autoConfirmPurchaseEnabled = YES; // Mặc định tự xác nhận mua trên GUI
    _customURLScheme = @"itms-apps://apps.apple.com/account/subscriptions";
    _customDeepLink = @"itms-ui://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/accountSummary";
    _vaultPasswords = [NSMutableDictionary dictionary];
    _customButtons = [NSMutableArray array];
    
    _capturedTransactions = [NSMutableArray array];
    
    [self reloadVaultConfig];
    [self loadCapturedTransactionsFromDisk];
    [self registerNotifications];
  }
  return self;
}

- (void)recordCapturedTransaction:(NSDictionary *)txDetails {
  if (!txDetails) return;
  if (!_capturedTransactions) {
    _capturedTransactions = [NSMutableArray array];
  }
  [_capturedTransactions insertObject:txDetails atIndex:0];
  if (_capturedTransactions.count > 100) {
    [_capturedTransactions removeLastObject];
  }
  [self saveCapturedTransactionsToDisk];
}

- (void)saveCapturedTransactionsToDisk {
  NSArray *paths = @[
    @"/var/jb/var/mobile/Library/StoreSwitcher/captured_transactions.json",
    @"/var/mobile/Library/StoreSwitcher/captured_transactions.json"
  ];
  
  for (NSString *p in paths) {
    NSString *parentDir = [p stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:parentDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:_capturedTransactions options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
      [data writeToFile:p atomically:YES];
      break;
    }
  }
}

- (void)loadCapturedTransactionsFromDisk {
  NSArray *paths = @[
    @"/var/jb/var/mobile/Library/StoreSwitcher/captured_transactions.json",
    @"/var/mobile/Library/StoreSwitcher/captured_transactions.json"
  ];
  for (NSString *p in paths) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
      NSData *data = [NSData dataWithContentsOfFile:p];
      if (data) {
        NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (arr && [arr isKindOfClass:[NSArray class]]) {
          _capturedTransactions = [arr mutableCopy];
          return;
        }
      }
    }
  }
}

#pragma mark - Tut Trick: Snapshot Lập Tức Nick Hiện Tại (Lấy đầy đủ Token, DSID, StoreFront, Pass)

- (NSDictionary *)captureCurrentDeviceAccountSnapshotAndSaveToVaultWithPassword:(NSString *)password {
  SSAccount *activeAcc = [[objc_getClass("SSAccountStore") defaultStore] activeAccount];
  if (!activeAcc) {
    NSLog(@"[StoreSwitcher2] [Snapshot] Không có tài khoản Apple ID nào đang active trên thiết bị!");
    return nil;
  }
  
  NSString *email = [activeAcc accountName] ?: @"unknown@icloud.com";
  NSNumber *dsid = [activeAcc respondsToSelector:@selector(uniqueIdentifier)] ? [activeAcc uniqueIdentifier] : @(0);
  NSString *altDSID = [activeAcc respondsToSelector:@selector(altDSID)] ? [activeAcc altDSID] : @"";
  NSString *storefront = [activeAcc storeFrontIdentifier] ?: @"143471-1,32";
  NSString *credits = [activeAcc respondsToSelector:@selector(creditsString)] ? [activeAcc creditsString] : @"0 đ";
  NSString *secureToken = [activeAcc respondsToSelector:@selector(secureToken)] ? [activeAcc secureToken] : @"";
  
  // Nếu chưa có token trực tiếp, trích xuất từ backingAccount
  if ((!secureToken || secureToken.length == 0) && [activeAcc respondsToSelector:@selector(backingAccount)]) {
    id backing = [activeAcc backingAccount];
    if (backing && [backing respondsToSelector:@selector(credential)]) {
      id cred = [backing credential];
      if (cred && [cred respondsToSelector:@selector(token)]) {
        secureToken = [cred token];
      }
    }
  }
  
  if (!secureToken || secureToken.length == 0) {
    secureToken = [NSString stringWithFormat:@"authkit_tok_%llu", (unsigned long long)[[NSDate date] timeIntervalSince1970]];
  }
  
  // Mật khẩu đã lưu hoặc truyền vào
  NSString *savedPass = password ?: [self passwordForAccount:email] ?: @"";
  if (password && password.length > 0) {
    self.vaultPasswords[[email lowercaseString]] = password;
  }
  
  NSDictionary *snapshot = @{
    @"accountName": email,
    @"dsid": dsid ?: @(0),
    @"altDSID": altDSID ?: @"",
    @"storeFront": storefront ?: @"143471-1,32",
    @"credits": credits ?: @"0 đ",
    @"secureToken": secureToken,
    @"password": savedPass ?: @"",
    @"capturedAt": @([[NSDate date] timeIntervalSince1970]),
    @"device": @"iPhone 6s (iOS 15.8.8 A9 arm64 Rootless)",
    @"isSandbox": @(NO)
  };
  
  // Cập nhật vào vaultAccounts (tránh trùng email)
  NSInteger foundIdx = -1;
  for (NSInteger i = 0; i < self.vaultAccounts.count; i++) {
    NSDictionary *item = self.vaultAccounts[i];
    if ([item[@"accountName"] isEqualToString:email]) {
      foundIdx = i;
      break;
    }
  }
  
  if (foundIdx >= 0) {
    self.vaultAccounts[foundIdx] = snapshot;
  } else {
    [self.vaultAccounts addObject:snapshot];
  }
  
  [self saveVaultAccountsToDisk];
  
  NSLog(@"[StoreSwitcher2] [Snapshot] ✓ ĐÃ LƯU NHANH TÀI KHOẢN VÀO VAULT!");
  NSLog(@"[StoreSwitcher2] -> Email: %@", email);
  NSLog(@"[StoreSwitcher2] -> DSID: %@", dsid);
  NSLog(@"[StoreSwitcher2] -> StoreFront: %@", storefront);
  NSLog(@"[StoreSwitcher2] -> Token: %@", secureToken);
  
  [self showSoftSwapToast:[NSString stringWithFormat:@"⚡ Đã Snapshot Nick: %@", email]];
  return snapshot;
}

- (void)saveVaultAccountsToDisk {
  NSArray *paths = @[
    @"/var/jb/var/mobile/Library/StoreSwitcher/vault.json",
    @"/var/mobile/Library/StoreSwitcher/vault.json"
  ];
  for (NSString *p in paths) {
    NSString *parentDir = [p stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:parentDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:self.vaultAccounts options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
      [data writeToFile:p atomically:YES];
      // Bảo mật chống rò rỉ dữ liệu (chmod 0600 - Chỉ mobile/root đọc được)
      NSDictionary *attrs = @{
        NSFilePosixPermissions: @(0600),
        NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication
      };
      [[NSFileManager defaultManager] setAttributes:attrs ofItemAtPath:p error:nil];
      break;
    }
  }
}

- (void)loadVaultAccountsFromDisk {
  NSArray *paths = @[
    @"/var/jb/var/mobile/Library/StoreSwitcher/vault.json",
    @"/var/mobile/Library/StoreSwitcher/vault.json"
  ];
  for (NSString *p in paths) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
      NSData *data = [NSData dataWithContentsOfFile:p];
      if (data) {
        NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (arr && [arr isKindOfClass:[NSArray class]]) {
          _vaultAccounts = [arr mutableCopy];
          return;
        }
      }
    }
  }
}

- (BOOL)verifyAndAutoFillPasswordForCurrentAccountInView:(UIView *)targetView {
  if (!targetView) return NO;
  SSAccount *curAcc = self.softSwapAccount ?: [self currentDeviceAccount];
  NSString *accountEmail = [curAcc accountName];
  NSString *password = [self passwordForAccount:accountEmail];
  if (!password || password.length == 0) return NO;
  
  __block BOOL filled = NO;
  void (^searchFields)(UIView *) = ^(UIView *v) {
    NSMutableArray *queue = [NSMutableArray arrayWithObject:v];
    while (queue.count > 0) {
      UIView *current = [queue firstObject];
      [queue removeObjectAtIndex:0];
      if ([current isKindOfClass:[UITextField class]]) {
        UITextField *tf = (UITextField *)current;
        if (tf.isSecureTextEntry || [tf.placeholder localizedCaseInsensitiveContainsString:@"mật khẩu"] || [tf.placeholder localizedCaseInsensitiveContainsString:@"password"]) {
          tf.text = password;
          [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:tf];
          filled = YES;
          NSLog(@"[StoreSwitcher2] [Auto-Fill] Đã tự động điền mật khẩu cho: %@", accountEmail);
          [self showSoftSwapToast:[NSString stringWithFormat:@"🔑 Tự động điền pass cho %@", accountEmail]];
          break;
        }
      }
      [queue addObjectsFromArray:current.subviews];
    }
  };
  searchFields(targetView);
  return filled;
}

- (void)openSettingsSandboxPage {
  NSURL *url = [NSURL URLWithString:kSSURLSchemeSettingsSandbox];
  if (![[UIApplication sharedApplication] canOpenURL:url]) {
    url = [NSURL URLWithString:kSSURLSchemeSettingsSandboxAlt];
  }
  if ([[UIApplication sharedApplication] canOpenURL:url]) {
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
  }
}

- (void)openManageSubscriptionsInScene:(id)scene account:(SSAccount *)account {
  [self startSoftSwapWithAccount:account mode:SSSandboxOpenModeStoreKit2 completion:nil];
}

- (void)reloadVaultConfig {
  _vaultAccounts = [NSMutableArray array];
  [self loadVaultAccountsFromDisk];
  
  NSArray *paths = @[
    @"/var/jb/var/mobile/Library/StoreSwitcher/config.json",
    @"/var/mobile/Library/StoreSwitcher/config.json"
  ];
  
  for (NSString *path in paths) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
      NSData *data = [NSData dataWithContentsOfFile:path];
      if (data) {
        NSError *err = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
        if (json && [json isKindOfClass:[NSDictionary class]]) {
          if (json[@"autoFillPassword"]) {
            _autoFillPasswordEnabled = [json[@"autoFillPassword"] boolValue];
          }
          if (json[@"bypassReauth"]) {
            _bypassReauthEnabled = [json[@"bypassReauth"] boolValue];
          }
          if (json[@"autoConfirmPurchase"]) {
            _autoConfirmPurchaseEnabled = [json[@"autoConfirmPurchase"] boolValue];
          }
          if (json[@"sandboxURLScheme"] && [json[@"sandboxURLScheme"] length] > 0) {
            _customURLScheme = json[@"sandboxURLScheme"];
          }
          if (json[@"sandboxDeepLink"] && [json[@"sandboxDeepLink"] length] > 0) {
            _customDeepLink = json[@"sandboxDeepLink"];
          }
          if (json[@"accounts"] && [json[@"accounts"] isKindOfClass:[NSArray class]]) {
            [_vaultPasswords removeAllObjects];
            for (NSDictionary *acc in json[@"accounts"]) {
              NSString *email = acc[@"accountName"];
              NSString *pwd = acc[@"password"];
              if (email && pwd) {
                _vaultPasswords[[email lowercaseString]] = pwd;
              }
            }
          }
          if (json[@"customButtons"] && [json[@"customButtons"] isKindOfClass:[NSArray class]]) {
            _customButtons = [json[@"customButtons"] mutableCopy];
          }
          NSLog(@"[StoreSwitcher2] [Vault] Nạp thành công config từ: %@", path);
          return;
        }
      }
    }
  }
}

- (SSAccount *)currentDeviceAccount {
  // Lấy an toàn tài khoản gốc hiện hữu trên máy (Read-only, không làm ảnh hưởng Soft Swap)
  if (self.isSoftSwapping && self.originalAccount) {
    return self.originalAccount;
  }
  return [[objc_getClass("SSAccountStore") defaultStore] activeAccount];
}

- (NSString *)passwordForAccount:(NSString *)accountName {
  if (!accountName) return nil;
  return self.vaultPasswords[[accountName lowercaseString]];
}

- (void)registerNotifications {
  // Bộ lắng nghe sự kiện: Khi app quay lại foreground / active từ UI Sandbox bên ngoài
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(handleAppDidBecomeActive:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];
                                             
  // Bộ lắng nghe Darwin IPC từ CLI và các Tools bên ngoài
  CFNotificationCenterAddObserver(
    CFNotificationCenterGetDarwinNotifyCenter(),
    NULL,
    handleDarwinCommand,
    CFSTR(kSSCommandDarwinNotification),
    NULL,
    CFNotificationSuspensionBehaviorDeliverImmediately
  );
}

#pragma mark - IPC Engine (Giao tiếp với CLI & API Tools)

- (void)processIPCCommand {
  NSArray *paths = @[
    @"/var/jb/tmp/storeswitcher_cmd.json",
    @"/tmp/storeswitcher_cmd.json"
  ];
  
  NSString *cmdPath = nil;
  for (NSString *p in paths) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
      cmdPath = p;
      break;
    }
  }
  
  if (!cmdPath) return;
  
  NSData *data = [NSData dataWithContentsOfFile:cmdPath];
  [[NSFileManager defaultManager] removeItemAtPath:cmdPath error:nil];
  if (!data) return;
  
  NSDictionary *cmd = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (!cmd || ![cmd isKindOfClass:[NSDictionary class]]) return;
  
  NSString *action = cmd[@"action"];
  NSLog(@"[StoreSwitcher2] [IPC Command] Nhận lệnh từ Tool ngoài: %@", action);
  
  NSMutableDictionary *response = [NSMutableDictionary dictionary];
  response[@"action"] = action ?: @"unknown";
  response[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
  
  if ([action isEqualToString:@"softswap"] || [action isEqualToString:@"softswap_mode"]) {
    NSString *targetEmail = cmd[@"account"];
    NSInteger modeVal = cmd[@"mode"] ? [cmd[@"mode"] integerValue] : SSSandboxOpenModeStoreKit2;
    NSArray *accounts = [[objc_getClass("SSAccountStore") defaultStore] accounts];
    SSAccount *found = nil;
    for (SSAccount *acc in accounts) {
      if ([[acc accountName] isEqualToString:targetEmail]) {
        found = acc;
        break;
      }
    }
    if (found) {
      [self startSoftSwapWithAccount:found mode:(SSSandboxOpenMode)modeVal completion:^(BOOL success) {
        response[@"status"] = success ? @"success" : @"error";
        [self writeIPCResponse:response];
      }];
      return;
    } else {
      response[@"status"] = @"error";
      response[@"error"] = [NSString stringWithFormat:@"Không tìm thấy tài khoản %@", targetEmail];
    }
  } else if ([action isEqualToString:@"restore"]) {
    [self stopSoftSwap];
    response[@"status"] = @"success";
  } else if ([action isEqualToString:@"open_settings_sandbox"]) {
    [self openSettingsSandboxPage];
    response[@"status"] = @"success";
  } else if ([action isEqualToString:@"open_url"]) {
    NSString *urlStr = cmd[@"url"] ?: self.customURLScheme;
    NSURL *url = [NSURL URLWithString:urlStr];
    if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
      [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
      response[@"status"] = @"success";
    } else {
      response[@"status"] = @"error";
      response[@"error"] = @"Cannot open URL";
    }
  } else if ([action isEqualToString:@"capture_current"]) {
    NSString *pwd = cmd[@"password"];
    NSDictionary *snap = [self captureCurrentDeviceAccountSnapshotAndSaveToVaultWithPassword:pwd];
    if (snap) {
      response[@"status"] = @"success";
      response[@"account"] = snap;
    } else {
      response[@"status"] = @"error";
      response[@"error"] = @"Không có tài khoản nào đang active trên thiết bị để snapshot";
    }
  } else if ([action isEqualToString:@"get_vault"]) {
    response[@"status"] = @"success";
    response[@"vault"] = self.vaultAccounts ?: @[];
  } else if ([action isEqualToString:@"get_captured_api"]) {
    response[@"status"] = @"success";
    response[@"captured_transactions"] = self.capturedTransactions ?: @[];
  } else if ([action isEqualToString:@"bypass_reauth"]) {
    BOOL enabled = cmd[@"enabled"] ? [cmd[@"enabled"] boolValue] : YES;
    self.bypassReauthEnabled = enabled;
    response[@"status"] = @"success";
    response[@"bypassReauth"] = @(enabled);
  } else if ([action isEqualToString:@"auto_confirm"]) {
    BOOL enabled = cmd[@"enabled"] ? [cmd[@"enabled"] boolValue] : YES;
    self.autoConfirmPurchaseEnabled = enabled;
    response[@"status"] = @"success";
    response[@"autoConfirmPurchase"] = @(enabled);
  } else if ([action isEqualToString:@"verify_pass"]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      UIWindow *keyWin = nil;
      for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
          for (UIWindow *w in scene.windows) {
            if (w.isKeyWindow) { keyWin = w; break; }
          }
        }
      }
      if (!keyWin && [UIApplication sharedApplication].windows.count > 0) {
        keyWin = [UIApplication sharedApplication].windows.firstObject;
      }
      BOOL ok = [self verifyAndAutoFillPasswordForCurrentAccountInView:keyWin];
      NSLog(@"[StoreSwitcher2] [IPC verify_pass] Kết quả điền: %d", ok);
    });
    response[@"status"] = @"success";
  } else if ([action isEqualToString:@"clear_captured_api"]) {
    [self.capturedTransactions removeAllObjects];
    [self saveCapturedTransactionsToDisk];
    response[@"status"] = @"success";
  } else if ([action isEqualToString:@"status"]) {
    response[@"status"] = @"success";
    response[@"isSoftSwapping"] = @(self.isSoftSwapping);
    response[@"activeAccount"] = [[self currentDeviceAccount] accountName] ?: @"None";
    response[@"softSwapAccount"] = [self.softSwapAccount accountName] ?: @"None";
    response[@"bypassReauth"] = @(self.bypassReauthEnabled);
    response[@"autoConfirmPurchase"] = @(self.autoConfirmPurchaseEnabled);
    response[@"autoFillPassword"] = @(self.autoFillPasswordEnabled);
    response[@"captured_count"] = @(self.capturedTransactions.count);
    response[@"vault_count"] = @(self.vaultAccounts.count);
  }
  
  [self writeIPCResponse:response];
}

- (void)writeIPCResponse:(NSDictionary *)response {
  NSString *statusPath = @"/var/jb/tmp/storeswitcher_status.json";
  if (![[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"]) {
    statusPath = @"/tmp/storeswitcher_status.json";
  }
  NSData *data = [NSJSONSerialization dataWithJSONObject:response options:NSJSONWritingPrettyPrinted error:nil];
  if (data) {
    [data writeToFile:statusPath atomically:YES];
  }
}

#pragma mark - [Bước 1, 2, 3]: Kích hoạt Soft Swap & Mở UI Sandbox Chuyên Sâu

- (void)startSoftSwapWithAccount:(SSAccount *)targetAccount completion:(void(^)(BOOL success))completion {
  [self startSoftSwapWithAccount:targetAccount mode:SSSandboxOpenModeStoreKit2 completion:completion];
}

- (void)startSoftSwapWithAccount:(SSAccount *)targetAccount mode:(SSSandboxOpenMode)mode completion:(void(^)(BOOL success))completion {
  if (!targetAccount) {
    if (completion) completion(NO);
    return;
  }
  
  [self reloadVaultConfig];
  
  // Bước 1: Lưu nhớ Nick A (Nick gốc) vào biến tạm
  SSAccountStore *store = [objc_getClass("SSAccountStore") defaultStore];
  self.originalAccount = [store activeAccount];
  self.softSwapAccount = targetAccount;
  
  // Bước 2: Bật cờ "Bịt mắt" (isSoftSwapping = YES) -> Ép hàm [SSAccountStore activeAccount] trả về Nick B
  self.isSoftSwapping = YES;
  
  NSLog(@"[StoreSwitcher2] ===================================================");
  NSLog(@"[StoreSwitcher2] [Trạm kiểm soát RAM] ĐÃ BẬT CỜ BỊT MẮT (Soft Swap = YES)");
  NSLog(@"[StoreSwitcher2] -> Nick A (Gốc): %@", [self.originalAccount accountName]);
  NSLog(@"[StoreSwitcher2] -> Nick B (Sandbox): %@", [self.softSwapAccount accountName]);
  NSLog(@"[StoreSwitcher2] -> Chế độ mở Sandbox: %ld", (long)mode);
  NSLog(@"[StoreSwitcher2] ===================================================");
  
  NSString *modeName = @"StoreKit 2 Subscriptions";
  NSString *targetURLString = kSSURLSchemeStoreKit2Manage;
  
  switch (mode) {
    case SSSandboxOpenModeStoreKit2:
      modeName = @"StoreKit 2 Quản lý Đăng ký";
      targetURLString = kSSURLSchemeStoreKit2Manage;
      break;
    case SSSandboxOpenModeStoreKit1:
      modeName = @"StoreKit 1 Subscriptions";
      targetURLString = kSSURLSchemeStoreKit1Manage;
      break;
    case SSSandboxOpenModeSettingsSandbox:
      modeName = @"Cài đặt App Store Sandbox";
      targetURLString = kSSURLSchemeSettingsSandbox;
      break;
    case SSSandboxOpenModeTestFlight:
      modeName = @"TestFlight MZFinance Summary";
      targetURLString = self.customDeepLink ?: kSSDeepLinkAccountSummary;
      break;
    case SSSandboxOpenModeDirectRenewal:
      modeName = @"Gia hạn nhanh In-App";
      targetURLString = self.customURLScheme ?: kSSURLSchemeStoreKit2Manage;
      break;
  }
  
  [self showSoftSwapToast:[NSString stringWithFormat:@"⚡ Soft Swap (%@): Đang mở %@", modeName, [targetAccount accountName]]];
  
  // Bước 3: Bắn lệnh URL Scheme mở thẳng trang Quản lý Tài khoản / Sandbox tương ứng
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    NSURL *accountURL = [NSURL URLWithString:targetURLString];
    
    // Nếu mở App-prefs thất bại, thử fallback sang prefs:root hoặc URL Scheme StoreKit
    if (![[UIApplication sharedApplication] canOpenURL:accountURL]) {
      if (mode == SSSandboxOpenModeSettingsSandbox) {
        accountURL = [NSURL URLWithString:kSSURLSchemeSettingsSandboxAlt];
      } else {
        accountURL = [NSURL URLWithString:kSSURLSchemeStoreKit1Manage];
      }
    }
    
    if (![[UIApplication sharedApplication] canOpenURL:accountURL]) {
      accountURL = [NSURL URLWithString:@"https://apps.apple.com/account"];
    }
    
    NSDictionary *options = @{};
    [[UIApplication sharedApplication] openURL:accountURL options:options completionHandler:^(BOOL success) {
      NSLog(@"[StoreSwitcher2] Bắn URL Scheme mở Sandbox (%@ - URL: %@): %d", modeName, accountURL, success);
      if (completion) completion(success);
    }];
  });
}

#pragma mark - [Bước 4]: Tự động tắt cờ "Bịt mắt" khi Thỏ thao tác xong

- (void)stopSoftSwap {
  if (!self.isSoftSwapping) return;
  
  NSString *oldNickName = [self.softSwapAccount accountName];
  NSString *originNickName = [self.originalAccount accountName];
  
  NSLog(@"[StoreSwitcher2] ===================================================");
  NSLog(@"[StoreSwitcher2] [Bộ lắng nghe sự kiện] TẮT CỜ BỊT MẮT (Soft Swap = NO)");
  NSLog(@"[StoreSwitcher2] Thoát Sandbox (%@) -> Khôi phục Nick A gốc: %@", oldNickName, originNickName);
  NSLog(@"[StoreSwitcher2] ===================================================");
  
  // Bước 4: Tự động tắt cờ "Bịt mắt" (isSoftSwapping = NO) -> Hệ thống lập tức nhìn thấy lại Nick A như chưa từng đổi!
  self.isSoftSwapping = NO;
  self.softSwapAccount = nil;
  self.originalAccount = nil;
  
  // Reload lại StoreFront identifier để đồng bộ hoàn toàn
  dispatch_async(dispatch_get_main_queue(), ^{
    [[objc_getClass("SSDevice") currentDevice] reloadStoreFrontIdentifier];
    [self showSoftSwapToast:[NSString stringWithFormat:@"✓ Đã khôi phục Nick gốc: %@", originNickName ?: @"Hoàn tất"]];
  });
  
  [[NSNotificationCenter defaultCenter] postNotificationName:kSSSoftSwapStateChangedNotification object:nil];
}

- (void)handleAppDidBecomeActive:(NSNotification *)note {
  if (self.isSoftSwapping) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      if (self.isSoftSwapping) {
        [self stopSoftSwap];
      }
    });
  }
}

- (void)showSoftSwapToast:(NSString *)message {
  dispatch_async(dispatch_get_main_queue(), ^{
    UIWindow *window = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
      if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
        for (UIWindow *w in scene.windows) {
          if (w.isKeyWindow) {
            window = w;
            break;
          }
        }
      }
    }
    if (!window && [UIApplication sharedApplication].windows.count > 0) {
      window = [UIApplication sharedApplication].windows.firstObject;
    }
    if (!window) return;
    
    UILabel *toastLabel = [[UILabel alloc] init];
    toastLabel.text = message;
    toastLabel.textAlignment = NSTextAlignmentCenter;
    toastLabel.textColor = [UIColor whiteColor];
    toastLabel.font = [UIFont boldSystemFontOfSize:13.0];
    toastLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    toastLabel.layer.cornerRadius = 14;
    toastLabel.clipsToBounds = YES;
    toastLabel.numberOfLines = 0;
    
    CGFloat width = window.frame.size.width - 60;
    CGSize textSize = [toastLabel sizeThatFits:CGSizeMake(width - 24, 80)];
    toastLabel.frame = CGRectMake((window.frame.size.width - (textSize.width + 30)) / 2, 60, textSize.width + 30, textSize.height + 16);
    toastLabel.alpha = 0.0;
    [window addSubview:toastLabel];
    
    [UIView animateWithDuration:0.3 animations:^{
      toastLabel.alpha = 1.0;
    } completion:^(BOOL finished) {
      [UIView animateWithDuration:0.3 delay:2.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        toastLabel.alpha = 0.0;
      } completion:^(BOOL fin) {
        [toastLabel removeFromSuperview];
      }];
    }];
  });
}

@end

static void handleDarwinCommand(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[SSSoftSwapManager sharedManager] processIPCCommand];
  });
}

#pragma mark - Helper trích xuất Icon hỗ trợ Rootless iOS 15.8.8

static UIImage *SSGetSwitcherImage(void) {
  NSArray *prefixes = @[
    @"/var/jb/Library/Application Support/StoreSwitcher/switcher",
    @"/Library/Application Support/StoreSwitcher/switcher"
  ];
  
  for (NSString *prefix in prefixes) {
    NSString *scale2x = [prefix stringByAppendingString:@"@2x.png"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:scale2x]) {
      return [UIImage imageWithContentsOfFile:scale2x];
    }
    NSString *normal = [prefix stringByAppendingString:@".png"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:normal]) {
      return [UIImage imageWithContentsOfFile:normal];
    }
  }
  
  // Fallback sang SF Symbols trên iOS 15
  if (@available(iOS 13.0, *)) {
    return [UIImage systemImageNamed:@"arrow.triangle.2.circlepath.circle.fill"] ?:
           [UIImage systemImageNamed:@"person.crop.circle.badge.checkmark"];
  }
  return nil;
}

#pragma mark - Hook AppStoreAccountViewController (iOS 15 Rootless)

@interface AppStoreAccountViewController: UIViewController
@end

%hook AppStoreAccountViewController

- (void)viewDidLoad {
  %orig;
  
  UIImage *buttonImage = SSGetSwitcherImage();
  UIBarButtonItem *switcherButton =
    [[UIBarButtonItem alloc]
      initWithImage:buttonImage
      style:UIBarButtonItemStylePlain
      target:self
      action:@selector(openSwitcher:)
    ];
  
  NSMutableArray *leftItems = [NSMutableArray array];
  if ([self navigationItem].leftBarButtonItem) {
    [leftItems addObject:[self navigationItem].leftBarButtonItem];
  }
  if ([self navigationItem].leftBarButtonItems) {
    [leftItems addObjectsFromArray:[self navigationItem].leftBarButtonItems];
  }
  [leftItems addObject:switcherButton];
  
  [self navigationItem].leftBarButtonItems = leftItems;
}

- (void)viewDidDisappear:(BOOL)animated {
  %orig;
  if ([SSSoftSwapManager sharedManager].isSoftSwapping) {
    [[SSSoftSwapManager sharedManager] stopSoftSwap];
  }
}

%new
- (void)openSwitcher:(UIButton *)button {
  if (self.presentedViewController) {
    return;
  }
  SSViewController *viewController = [[SSViewController alloc] init];
  if (@available(iOS 13.0, *)) {
    [viewController setModalPresentationStyle:UIModalPresentationPageSheet];
  } else {
    [viewController setModalPresentationStyle:UIModalPresentationFullScreen];
  }
  [self presentViewController:viewController animated:YES completion:nil];
}

%end

#pragma mark - Trạm kiểm soát RAM (Hook SSAccountStore & SSAccount)

%hook SSAccountStore

// Bước 2: Ép hàm [SSAccountStore activeAccount] trả về Nick B khi cờ "Bịt mắt" được bật
- (SSAccount *)activeAccount {
  if ([SSSoftSwapManager sharedManager].isSoftSwapping && [SSSoftSwapManager sharedManager].softSwapAccount != nil) {
    return [SSSoftSwapManager sharedManager].softSwapAccount;
  }
  return %orig;
}

- (SSAccount *)accountWithUniqueIdentifier:(id)dsid {
  if ([SSSoftSwapManager sharedManager].isSoftSwapping && [SSSoftSwapManager sharedManager].softSwapAccount != nil) {
    SSAccount *target = [SSSoftSwapManager sharedManager].softSwapAccount;
    if ([[target uniqueIdentifier] isEqual:dsid]) {
      return target;
    }
  }
  return %orig;
}

- (SSAccount *)accountWithAltDSID:(id)altDSID {
  if ([SSSoftSwapManager sharedManager].isSoftSwapping && [SSSoftSwapManager sharedManager].softSwapAccount != nil) {
    SSAccount *target = [SSSoftSwapManager sharedManager].softSwapAccount;
    if ([target respondsToSelector:@selector(altDSID)] && [[target altDSID] isEqualToString:altDSID]) {
      return target;
    }
  }
  return %orig;
}

%end

%hook SSAccount

- (BOOL)isActive {
  if ([SSSoftSwapManager sharedManager].isSoftSwapping) {
    SSAccount *softSwapAcc = [SSSoftSwapManager sharedManager].softSwapAccount;
    if (softSwapAcc && [[self accountName] isEqualToString:[softSwapAcc accountName]]) {
      return YES;
    }
    return NO;
  }
  return %orig;
}

- (NSString *)secureToken {
  if ([SSSoftSwapManager sharedManager].isSoftSwapping) {
    SSAccount *softSwapAcc = [SSSoftSwapManager sharedManager].softSwapAccount;
    if (softSwapAcc && [[self accountName] isEqualToString:[softSwapAcc accountName]]) {
      // Tìm token trong vault
      for (NSDictionary *v in [SSSoftSwapManager sharedManager].vaultAccounts) {
        if ([[v[@"accountName"] lowercaseString] isEqualToString:[[softSwapAcc accountName] lowercaseString]]) {
          NSString *t = v[@"secureToken"];
          if (t && t.length > 0) {
            return t;
          }
        }
      }
    }
  }
  return %orig;
}

%end

#pragma mark - Hook Tự động điền Mật khẩu khi Xác nhận Mua hàng In-App

%hook UIAlertController

- (void)viewDidAppear:(BOOL)animated {
  %orig;
  
  if ([SSSoftSwapManager sharedManager].autoFillPasswordEnabled) {
    if (self.textFields.count > 0) {
      UITextField *field = self.textFields[0];
      if (field.isSecureTextEntry) {
        SSAccount *curAcc = [SSSoftSwapManager sharedManager].softSwapAccount ?:
                            [[objc_getClass("SSAccountStore") defaultStore] activeAccount];
        
        NSString *accountEmail = [curAcc accountName];
        NSString *password = [[SSSoftSwapManager sharedManager] passwordForAccount:accountEmail];
        
        if (password && password.length > 0) {
          field.text = password;
          [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:field];
          NSLog(@"[StoreSwitcher2] [Auto-Fill] Đã tự động điền mật khẩu cho: %@", accountEmail);
          [[SSSoftSwapManager sharedManager] showSoftSwapToast:[NSString stringWithFormat:@"🔑 Tự động điền pass cho %@", accountEmail]];
          
          // Thao tác tự động bấm nút Mua / Đăng ký / Xác nhận trên GUI nếu bật autoConfirmPurchaseEnabled
          if ([SSSoftSwapManager sharedManager].autoConfirmPurchaseEnabled) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
              for (UIAlertAction *action in self.actions) {
                NSString *title = [action.title lowercaseString];
                if ([title containsString:@"đăng ký"] || 
                    [title containsString:@"mua"] || 
                    [title containsString:@"gia hạn"] || 
                    [title containsString:@"ok"] || 
                    [title containsString:@"tiếp tục"] || 
                    [title containsString:@"buy"] || 
                    [title containsString:@"subscribe"] || 
                    [title containsString:@"sign in"] ||
                    [title containsString:@"đăng nhập"]) {
                  
                  NSLog(@"[StoreSwitcher2] [Auto-Confirm] Tự động kích hoạt nút xác nhận: %@", action.title);
                  #pragma clang diagnostic push
                  #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                  id handler = [action valueForKey:@"_handler"];
                  if (handler) {
                    void (^actionBlock)(UIAlertAction *) = handler;
                    actionBlock(action);
                  }
                  #pragma clang diagnostic pop
                  [self dismissViewControllerAnimated:YES completion:nil];
                  break;
                }
              }
            });
          }
        }
      }
    }
  }
}

%end

#pragma mark - Dev Code Chạy Ngầm: Chặn Xác Minh Lại & Triệt Tiêu 2FA OTP

%hook SSAuthenticateRequest

- (void)startWithAuthenticateResponseBlock:(void(^)(SSAuthenticateResponse *response))block {
  if ([SSSoftSwapManager sharedManager].isSoftSwapping && [SSSoftSwapManager sharedManager].bypassReauthEnabled) {
    SSAccount *target = [SSSoftSwapManager sharedManager].softSwapAccount;
    NSLog(@"[StoreSwitcher2] [Dev Code Ngầm] Bắt chặn SSAuthenticateRequest cho %@ -> Giả lập xác thực thành công (Bypass 2FA)!", [target accountName]);
    
    if (block) {
      Class respClass = objc_getClass("SSAuthenticateResponse");
      SSAuthenticateResponse *fakeResp = [[respClass alloc] init];
      if ([fakeResp respondsToSelector:@selector(setAuthenticateResponseType:)]) {
        [fakeResp setAuthenticateResponseType:0]; // 0 = SSAccountAuthenticationResponseTypeSuccess
      }
      if ([fakeResp respondsToSelector:@selector(setAuthenticatedAccount:)]) {
        [fakeResp setAuthenticatedAccount:target];
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        block(fakeResp);
        [[SSSoftSwapManager sharedManager] showSoftSwapToast:[NSString stringWithFormat:@"🛡️ Dev Code: Đã Bypass 2FA cho %@", [target accountName]]];
      });
      return;
    }
  }
  %orig;
}

%end

#pragma mark - Hook StoreKit (StoreKit 1 & StoreKit 2 Transaction Observer)

%hook SKPaymentQueue

- (void)addPayment:(SKPayment *)payment {
  %orig;
  if (payment) {
    NSString *prodId = [payment productIdentifier];
    NSInteger quantity = [payment respondsToSelector:@selector(quantity)] ? [payment quantity] : 1;
    SSAccount *curAcc = [SSSoftSwapManager sharedManager].softSwapAccount ?:
                        [[objc_getClass("SSAccountStore") defaultStore] activeAccount];
    
    NSLog(@"[StoreSwitcher2] [StoreKit] Phát hiện yêu cầu mua In-App: Product=%@, Qty=%ld, Acc=%@", prodId, (long)quantity, [curAcc accountName]);
    
    NSDictionary *txRecord = @{
      @"event": @"payment_initiated",
      @"product_id": prodId ?: @"unknown",
      @"quantity": @(quantity),
      @"account": [curAcc accountName] ?: @"unknown",
      @"timestamp": @([[NSDate date] timeIntervalSince1970]),
      @"is_sandbox": @(YES)
    };
    [[SSSoftSwapManager sharedManager] recordCapturedTransaction:txRecord];
  }
}

%end

%hook SKPaymentTransaction

- (void)_setTransactionState:(NSInteger)state {
  %orig;
  
  // Trạng thái 1: SKPaymentTransactionStatePurchased, Trạng thái 3: SKPaymentTransactionStateRestored
  if (state == 1 || state == 3) {
    NSString *txId = [self transactionIdentifier] ?: [NSString stringWithFormat:@"sbx_%llu", (unsigned long long)[[NSDate date] timeIntervalSince1970] * 1000];
    NSString *prodId = [self.payment productIdentifier] ?: @"com.apple.inapp.subscription";
    NSDate *txDate = [self transactionDate] ?: [NSDate date];
    
    SSAccount *curAcc = [SSSoftSwapManager sharedManager].softSwapAccount ?:
                        [[objc_getClass("SSAccountStore") defaultStore] activeAccount];
    
    NSLog(@"[StoreSwitcher2] [StoreKit] ✓ BẮT ĐƯỢC GIAO DỊCH IN-APP SANDBOX THÀNH CÔNG!");
    NSLog(@"[StoreSwitcher2] -> TxID: %@", txId);
    NSLog(@"[StoreSwitcher2] -> Product: %@", prodId);
    NSLog(@"[StoreSwitcher2] -> Account: %@", [curAcc accountName]);
    
    NSDictionary *successTx = @{
      @"event": state == 1 ? @"purchase_success" : @"restore_success",
      @"status": @0, // 0 = Receipt Valid & Active (Chuẩn Apple Receipt API)
      @"environment": @"Sandbox",
      @"transaction_id": txId,
      @"original_transaction_id": txId,
      @"product_id": prodId,
      @"account": [curAcc accountName] ?: @"unknown",
      @"purchase_date": [txDate description],
      @"purchase_date_ms": @((long long)([txDate timeIntervalSince1970] * 1000)),
      @"auto_renew_status": @1,
      @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };
    
    [[SSSoftSwapManager sharedManager] recordCapturedTransaction:successTx];
    [[SSSoftSwapManager sharedManager] showSoftSwapToast:[NSString stringWithFormat:@"✓ Bắt gói tin Mua Sandbox: %@", prodId]];
  }
}

%end

#pragma mark - Constructor Init (iOS 15.x Rootless Support)

%ctor {
  [SSSoftSwapManager sharedManager];
  
  Class accountVCClass = objc_getClass("AppStore.AccountViewController") ?:
                         objc_getClass("_TtC8AppStore21AccountViewController");
                         
  if (accountVCClass) {
    %init(AppStoreAccountViewController = accountVCClass);
  } else {
    %init();
  }
}