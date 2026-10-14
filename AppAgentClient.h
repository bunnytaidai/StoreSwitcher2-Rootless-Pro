#import <Foundation/Foundation.h>

@interface AppAgentClient : NSObject

+ (instancetype)sharedClient;

// Lấy danh sách tất cả các App đang chạy có Dylib
- (NSDictionary *)getRegisteredApps;

// Giao tiếp với app cụ thể
- (void)fetchStatusForBundleId:(NSString *)bundleId completion:(void(^)(NSDictionary *status, NSError *error))completion;
- (void)fetchPacketsForBundleId:(NSString *)bundleId completion:(void(^)(NSArray *packets, NSError *error))completion;
- (void)replayPacketForBundleId:(NSString *)bundleId packetId:(NSString *)packetId completion:(void(^)(BOOL success, id response, NSError *error))completion;
- (void)modifyPacketForBundleId:(NSString *)bundleId packetId:(NSString *)packetId newPayload:(id)payload completion:(void(^)(BOOL success, NSError *error))completion;
- (void)fetchClassesForBundleId:(NSString *)bundleId keyword:(NSString *)keyword completion:(void(^)(NSArray *classes, NSError *error))completion;
- (void)inspectClassForBundleId:(NSString *)bundleId className:(NSString *)className completion:(void(^)(NSDictionary *classInfo, NSError *error))completion;
- (void)dumpUIForBundleId:(NSString *)bundleId completion:(void(^)(NSDictionary *uiTree, NSError *error))completion;
- (void)clickButtonForBundleId:(NSString *)bundleId textOrId:(NSString *)keyword completion:(void(^)(BOOL success, NSError *error))completion;
- (void)sendInputForBundleId:(NSString *)bundleId targetId:(NSString *)keyword text:(NSString *)text completion:(void(^)(BOOL success, NSError *error))completion;
- (void)showAlertInApp:(NSString *)bundleId title:(NSString *)title message:(NSString *)message completion:(void(^)(BOOL success, NSError *error))completion;
- (void)toggleOverlayInApp:(NSString *)bundleId completion:(void(^)(BOOL success, NSError *error))completion;
- (void)openUrlInApp:(NSString *)bundleId url:(NSString *)url completion:(void(^)(BOOL success, NSError *error))completion;

@end
