#import <Foundation/Foundation.h>

@interface SSAccount : NSObject
- (BOOL)isActive;
- (void)setActive:(BOOL)arg1;
- (BOOL)isAuthenticated;
- (void)setAuthenticated:(BOOL)arg1;
- (BOOL)isLocalAccount;
- (NSString *)firstName;
- (NSString *)lastName;
- (NSString *)accountName;
- (NSString *)storeFrontIdentifier;
- (id)uniqueIdentifier;
- (NSString *)altDSID;
@end

@interface SSAccountStore : NSObject
+ (id)defaultStore;
- (NSArray *)accounts;
- (BOOL)saveAccount:(id)arg1 verifyCredentials:(BOOL)arg2 error:(id*)arg3;
- (void)removeAccount:(id)arg1 error:(id*)arg2;
- (void)setDefaultAccount:(id)arg1 completionBlock:(id)arg2;
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

@interface SSMutableAuthenticationContext : NSObject
- (void)setPromptStyle:(NSInteger)style;
- (void)setCanCreateNewAccount:(BOOL)flag;
@end

@interface SSAuthenticateRequest : NSObject
- (instancetype)initWithAuthenticationContext:(id)context;
- (void)startWithAuthenticateResponseBlock:(void (^)(id response))block;
@end