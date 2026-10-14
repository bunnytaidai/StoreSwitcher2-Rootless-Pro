#import "AgentBeacon.h"
#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

static NSTimer *s_heartbeatTimer = nil;
static NSMutableArray *s_storeKitProducts = nil;
static uint16_t s_ipcPort = 9100;

@implementation AgentBeacon

+ (void)updateIpcPort:(uint16_t)port {
    s_ipcPort = port;
    [self writeBeacon];
}

+ (NSString *)beaconsDirectory {
    NSArray *candidates = @[
        @"/var/jb/var/mobile/Library/Application Support/StoreSwitcher/injected_beacons",
        @"/var/mobile/Library/Application Support/StoreSwitcher/injected_beacons"
    ];
    for (NSString *p in candidates) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
            return p;
        }
    }
    NSString *base = @"/var/mobile/Library/Application Support/StoreSwitcher/injected_beacons";
    [[NSFileManager defaultManager] createDirectoryAtPath:base withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0755} error:nil];
    return base;
}

+ (NSString *)beaconFilePath {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown_app";
    return [[self beaconsDirectory] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", bundleID]];
}

+ (void)startReportingBeacon {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_storeKitProducts = [NSMutableArray array];
        
        // Ghi nhận ngay lập tức khi tiêm dylib thành công
        [self writeBeacon];

        // Duy trì heartbeat mỗi 10 giây
        dispatch_async(dispatch_get_main_queue(), ^{
            s_heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                [self writeBeacon];
            }];
        });
    });
}

+ (void)updateStoreKitProduct:(NSDictionary *)productDict {
    if (!productDict || !productDict[@"productIdentifier"]) return;
    
    @synchronized (s_storeKitProducts) {
        BOOL exists = NO;
        for (NSUInteger i = 0; i < s_storeKitProducts.count; i++) {
            if ([s_storeKitProducts[i][@"productIdentifier"] isEqualToString:productDict[@"productIdentifier"]]) {
                s_storeKitProducts[i] = productDict;
                exists = YES;
                break;
            }
        }
        if (!exists) {
            [s_storeKitProducts addObject:productDict];
        }
    }
    [self writeBeacon];
}

+ (void)writeBeacon {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID || bundleID.length == 0) return;

    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *displayName = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: bundleID;
    NSString *version = info[@"CFBundleShortVersionString"] ?: info[@"CFBundleVersion"] ?: @"1.0";
    NSString *execPath = [[NSBundle mainBundle] executablePath] ?: @"";
    NSString *sandbox = NSHomeDirectory();

    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    BOOL hasReceipt = receiptURL && [[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path];

    NSMutableDictionary *beacon = [NSMutableDictionary dictionary];
    beacon[@"bundleID"] = bundleID;
    beacon[@"displayName"] = displayName;
    beacon[@"version"] = version;
    beacon[@"executablePath"] = execPath;
    beacon[@"sandboxPath"] = sandbox;
    beacon[@"pid"] = @(getpid());
    beacon[@"injectionTime"] = @([[NSDate date] timeIntervalSince1970]);
    beacon[@"lastHeartbeat"] = @([[NSDate date] timeIntervalSince1970]);
    beacon[@"hasStoreKitReceipt"] = @(hasReceipt);
    beacon[@"receiptPath"] = receiptURL ? receiptURL.path : @"";
    beacon[@"ipcPort"] = @(s_ipcPort);

    @synchronized (s_storeKitProducts) {
        beacon[@"storeKitProducts"] = [s_storeKitProducts copy];
    }

    NSData *data = [NSJSONSerialization dataWithJSONObject:beacon options:NSJSONWritingPrettyPrinted error:nil];
    if (data) {
        [data writeToFile:[self beaconFilePath] atomically:YES];
    }
}

@end
