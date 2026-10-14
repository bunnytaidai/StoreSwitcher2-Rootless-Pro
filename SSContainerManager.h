#import <Foundation/Foundation.h>

@interface SSContainer : NSObject

@property (nonatomic, copy) NSString *identifier;       // UUID
@property (nonatomic, copy) NSString *name;             // Tên hiển thị (ví dụ: "Vùng chứa #1", "Nick Mỹ")
@property (nonatomic, copy) NSString *appleID;          // Email Apple ID đã gắn kết (hoặc rỗng nếu là container sạch)
@property (nonatomic, copy) NSString *password;         // Mật khẩu lưu trữ cho Apple ID này (nếu có)
@property (nonatomic, copy) NSString *dsid;             // DSID duy nhất của Apple ID
@property (nonatomic, copy) NSString *storeFrontID;     // Mã quốc gia (ví dụ: "143441" cho Mỹ)
@property (nonatomic, assign) BOOL isDefault;           // Có phải vùng chứa mặc định không
@property (nonatomic, assign) BOOL isolateSystemAccounts;// Tách biệt tài khoản hệ thống
@property (nonatomic, assign) BOOL preserveSandbox;     // Không xóa dữ liệu hộp cát app
@property (nonatomic, assign) BOOL isolatedKeychain;    // Tách biệt keychain token (Keychain ID)
@property (nonatomic, assign) BOOL isolatedNotifications;// Tách biệt thông báo
@property (nonatomic, strong) NSDate *lastUsedDate;

- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end

@interface SSSavedAccount : NSObject

@property (nonatomic, copy) NSString *appleID;
@property (nonatomic, copy) NSString *dsid;
@property (nonatomic, copy) NSString *altDSID;
@property (nonatomic, copy) NSString *storeFrontID;
@property (nonatomic, copy) NSString *countryCode;
@property (nonatomic, strong) NSDate *lastUsedDate;
@property (nonatomic, assign) BOOL isTrusted;

- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end

@interface SSContainerManager : NSObject

+ (instancetype)sharedManager;

// Cấu hình chung của tweak
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL isolateSystemAccounts;
@property (nonatomic, assign) BOOL preserveSandboxData;
@property (nonatomic, assign) BOOL isolateKeychain;
@property (nonatomic, assign) BOOL isolateNotifications;
@property (nonatomic, assign) BOOL killDaemonsOnSwitch;
@property (nonatomic, assign) BOOL wipeCachesOnSwitch;
@property (nonatomic, assign) BOOL enable3DTouchShortcut;
@property (nonatomic, assign) BOOL trustAccountsNoPrompt; // Chống popup OTP, 2FA, password

@property (nonatomic, strong) NSMutableArray<SSContainer *> *containers;
@property (nonatomic, strong) NSMutableArray<SSSavedAccount *> *savedAccounts;
@property (nonatomic, copy) NSString *activeContainerID;
@property (nonatomic, copy) NSString *activeAppleID;

// Quản lý containers
- (void)loadSettings;
- (void)saveSettings;
- (SSContainer *)activeContainer;
- (SSContainer *)containerWithIdentifier:(NSString *)identifier;
- (SSContainer *)createNewCleanContainerWithName:(NSString *)name;
- (void)deleteContainer:(SSContainer *)container;

// Quản lý Kho Lưu Trữ Tài Khoản (Accounts Vault - Vĩnh viễn không mất)
- (void)syncAccountsFromSystem;
- (void)saveAccountToVault:(NSString *)appleID dsid:(NSString *)dsid altDSID:(NSString *)altDSID storeFront:(NSString *)storeFront;
- (void)deleteAccountFromVault:(NSString *)appleID;
- (BOOL)switchToAccountWithAppleID:(NSString *)appleID error:(NSError **)error;

// Quy trình chuyển đổi Nick / Vùng chứa (Pipeline)
- (BOOL)switchToContainer:(SSContainer *)targetContainer error:(NSError **)error;

// Tắt daemon & dọn dẹp
- (void)terminateBackgroundDaemons;
- (void)wipeAppCaches;

@end
