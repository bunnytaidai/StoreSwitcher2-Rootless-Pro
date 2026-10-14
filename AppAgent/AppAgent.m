#import "AppAgent.h"
#import "StoreKitHook.h"
#import "URLSchemeHook.h"
#import "NetworkPacketHook.h"
#import "AgentIPCServer.h"
#import <UIKit/UIKit.h>

@implementation AppAgent

+ (void)initializeAgent {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"[AppAgent] Initializing in process: %@ (PID: %d)", [[NSBundle mainBundle] bundleIdentifier], getpid());

        // 1. Cài đặt các bộ Hook packet
        [StoreKitHook installHook];
        [URLSchemeHook installHook];
        [NetworkPacketHook installHook];

        // 2. Chờ UIApplication khởi chạy xong rồi start IPC Server
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[AgentIPCServer sharedServer] startServer];
        });
    });
}

@end

// Hàm Constructor tự động thực thi khi .dylib được tiêm vào process
__attribute__((constructor))
static void AppAgentEntry(void) {
    @autoreleasepool {
        // Chỉ kích hoạt nếu là ứng dụng UIKit (tránh các daemon hệ thống vô nghĩa)
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        if (info && (info[@"CFBundlePackageType"] == nil || [info[@"CFBundlePackageType"] isEqualToString:@"APPL"])) {
            [AppAgent initializeAgent];
        }
    }
}
