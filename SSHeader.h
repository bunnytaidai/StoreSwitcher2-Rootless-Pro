#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

// Định nghĩa các URL Scheme chuẩn xác (Rút ra từ phân tích hành vi iOS 15.8.8)
#define kSSURLSchemeStoreKit2Manage     @"itms-apps://apps.apple.com/account/manage-subscriptions"
#define kSSURLSchemeStoreKit1Manage     @"itms-apps://apps.apple.com/account/subscriptions"
#define kSSURLSchemeSettingsSandbox     @"App-prefs:STORE&path=SANDBOX_ACCOUNT"
#define kSSURLSchemeSettingsSandboxAlt  @"prefs:root=STORE&path=SANDBOX_ACCOUNT"
#define kSSURLSchemeTestFlightDirect    @"itms-beta://"
#define kSSDeepLinkAccountSummary       @"itms-ui://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/accountSummary"

typedef NS_ENUM(NSInteger, SSSandboxOpenMode) {
  SSSandboxOpenModeStoreKit2 = 0,    // Mở thẳng popup sheet Đăng ký [SANDBOX] (StoreKit 2 Native)
  SSSandboxOpenModeStoreKit1 = 1,    // Mở popup quản lý Subscriptions cổ điển (StoreKit 1)
  SSSandboxOpenModeSettingsSandbox = 2, // Mở thẳng mục Cài đặt App Store -> Tài khoản Sandbox
  SSSandboxOpenModeTestFlight = 3,   // Mở trang WebObjects TestFlight Account Summary
  SSSandboxOpenModeDirectRenewal = 4 // Kích hoạt gia hạn trực tiếp gói In-App
};

@interface SSAccount : NSObject
- (BOOL)isActive;
- (void)setActive:(BOOL)arg1;
- (BOOL)isLocalAccount;
- (NSString *)firstName;
- (NSString *)lastName;
- (NSString *)accountName;
- (NSString *)storeFrontIdentifier;
- (NSNumber *)uniqueIdentifier; // DSID
- (NSString *)altDSID;
- (NSString *)creditsString;
- (NSString *)secureToken;
- (void)setSecureToken:(NSString *)token;
- (NSInteger)accountScope;
- (id)backingAccount;
- (id)backupAccountIdentifier;
@end

@interface SSAccountStore : NSObject
+ (id)defaultStore;
- (NSArray *)accounts;
- (SSAccount *)activeAccount;
- (SSAccount *)accountWithUniqueIdentifier:(id)arg1;
- (SSAccount *)accountWithAltDSID:(id)arg1;
- (BOOL)saveAccount:(id)arg1 verifyCredentials:(BOOL)arg2 error:(id*)arg3;
- (void)removeAccount:(id)arg1 error:(id*)arg2;
- (void)resetCaches;
@end

@interface SSDevice : NSObject
+ (id)currentDevice;
- (void)reloadStoreFrontIdentifier;
@end

@interface SKUIApplicationController : NSObject
- (void)_resetUserInterfaceAfterStoreFrontChange;
@end

@interface SKUIClientContext : NSObject
+ (id)defaultContext;
- (SKUIApplicationController *)applicationController;
@end

@interface SKPaymentQueue (StoreKit2)
+ (void)showManageSubscriptionsInWindowScene:(id)windowScene completionHandler:(void (^)(NSError *error))completionHandler;
@end

// Trạm kiểm soát RAM - Soft Swap Manager & Vault
@interface SSSoftSwapManager : NSObject
+ (instancetype)sharedManager;
@property (nonatomic, assign) BOOL isSoftSwapping;
@property (nonatomic, strong) SSAccount *originalAccount;
@property (nonatomic, strong) SSAccount *softSwapAccount;
@property (nonatomic, assign) BOOL autoFillPasswordEnabled;
@property (nonatomic, copy) NSString *customURLScheme;
@property (nonatomic, copy) NSString *customDeepLink;
@property (nonatomic, strong) NSMutableArray *customButtons; // Danh sách nút động
@property (nonatomic, strong) NSMutableArray *capturedTransactions; // Giao dịch Sandbox đã bắt
@property (nonatomic, strong) NSMutableArray *vaultAccounts; // Danh sách tài khoản đã snapshot & lưu token đầy đủ

@property (nonatomic, assign) BOOL bypassReauthEnabled; // Dev code chạy ngầm chặn 2FA re-auth
@property (nonatomic, assign) BOOL autoConfirmPurchaseEnabled; // Tự động xác nhận mua trên GUI

- (void)startSoftSwapWithAccount:(SSAccount *)targetAccount completion:(void(^)(BOOL success))completion;
- (void)startSoftSwapWithAccount:(SSAccount *)targetAccount mode:(SSSandboxOpenMode)mode completion:(void(^)(BOOL success))completion;
- (void)stopSoftSwap;
- (NSString *)passwordForAccount:(NSString *)accountName;
- (void)reloadVaultConfig;
- (SSAccount *)currentDeviceAccount;

// Tut Trick: Snapshot Lập Tức Nick Hiện Tại (Lấy đầy đủ Token, DSID, StoreFront, Pass)
- (NSDictionary *)captureCurrentDeviceAccountSnapshotAndSaveToVaultWithPassword:(NSString *)password;
- (void)saveVaultAccountsToDisk;
- (void)loadVaultAccountsFromDisk;

// Thao tác StoreKit & Sandbox chuyên sâu
- (void)openManageSubscriptionsInScene:(id)scene account:(SSAccount *)account;
- (void)openSettingsSandboxPage;
- (void)recordCapturedTransaction:(NSDictionary *)txDetails;
- (void)saveCapturedTransactionsToDisk;
- (BOOL)verifyAndAutoFillPasswordForCurrentAccountInView:(UIView *)targetView;
@end

// Khai báo StoreServices Authentication Request để Hook Dev Code Chạy Ngầm
@interface SSAuthenticateResponse : NSObject
@property (nonatomic, assign) NSInteger authenticateResponseType;
@property (nonatomic, strong) SSAccount *authenticatedAccount;
@property (nonatomic, strong) NSError *error;
@end

@interface SSAuthenticateRequest : NSObject
- (id)initWithAccount:(id)arg1;
- (id)initWithAuthenticationContext:(id)arg1;
- (void)startWithAuthenticateResponseBlock:(void(^)(SSAuthenticateResponse *response))block;
@end

// iTunesStore.framework Private Interfaces
@interface ISURLOperation : NSOperation
- (NSURLRequest *)request;
@end

@interface ISStoreURLOperation : ISURLOperation
@end

// AppStoreDaemon.framework Private Interfaces (TestFlight Sandbox & In-App Subscriptions)
@interface ASDSubscriptionEntitlements : NSObject
+ (id)sharedInstance;
- (void)getSubscriptionEntitlementsForActiveAccountWithCompletionHandler:(void(^)(NSArray *entitlements, BOOL isCanceled, NSError *error))handler;
@end

@interface ASDPurchaseRequestOptions : NSObject
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *buyParameters;
@end

@interface ASDPurchaseResult : NSObject
@property (nonatomic, readonly) BOOL success;
@property (nonatomic, readonly) NSError *error;
@end

@interface ASDPurchaseRequest : NSObject
- (void)startWithCompletionHandler:(void(^)(ASDPurchaseResult *result, NSError *error))handler;
@end

#define kSSSoftSwapStateChangedNotification @"kSSSoftSwapStateChangedNotification"
#define kSSCommandDarwinNotification "com.subdiox.storeswitcher.command"