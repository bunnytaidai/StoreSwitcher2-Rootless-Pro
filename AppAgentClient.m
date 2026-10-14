#import "AppAgentClient.h"

#define REGISTRY_FILE @"/var/mobile/Library/Preferences/com.agent.registered_apps.plist"
#define FALLBACK_REGISTRY @"/tmp/com.agent.registered_apps.plist"

@implementation AppAgentClient

+ (instancetype)sharedClient {
    static AppAgentClient *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[AppAgentClient alloc] init];
    });
    return inst;
}

- (NSDictionary *)getRegisteredApps {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:REGISTRY_FILE];
    if (!dict) {
        dict = [NSDictionary dictionaryWithContentsOfFile:FALLBACK_REGISTRY];
    }
    return dict ?: @{};
}

- (NSInteger)portForBundleId:(NSString *)bundleId {
    if (!bundleId || bundleId.length == 0) return 0;

    // 1. Kiểm tra beacon file trước (thời gian thực từ AppAgent.dylib)
    NSString *beaconPath = [NSString stringWithFormat:@"/var/mobile/Library/Application Support/StoreSwitcher/injected_beacons/%@.json", bundleId];
    if (![[NSFileManager defaultManager] fileExistsAtPath:beaconPath]) {
        beaconPath = [NSString stringWithFormat:@"/var/jb/var/mobile/Library/Application Support/StoreSwitcher/injected_beacons/%@.json", bundleId];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:beaconPath]) {
        NSData *data = [NSData dataWithContentsOfFile:beaconPath];
        if (data) {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([dict isKindOfClass:[NSDictionary class]] && dict[@"ipcPort"]) {
                NSInteger port = [dict[@"ipcPort"] integerValue];
                if (port > 0) return port;
            }
        }
    }

    // 2. Kiểm tra plist registry
    NSDictionary *reg = [self getRegisteredApps];
    if (reg[bundleId]) {
        return [reg[bundleId][@"port"] integerValue];
    }
    return 0;
}

- (void)sendRequestToBundleId:(NSString *)bundleId
                         path:(NSString *)path
                       method:(NSString *)method
                         body:(id)body
                   completion:(void(^)(id json, NSError *error))completion {
    NSInteger port = [self portForBundleId:bundleId];
    if (port <= 0) {
        if (completion) {
            NSError *err = [NSError errorWithDomain:@"AppAgentClient" code:404 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"App %@ chưa kích hoạt Dylib IPC!", bundleId]}];
            completion(nil, err);
        }
        return;
    }

    NSString *urlStr = [NSString stringWithFormat:@"http://127.0.0.1:%ld%@", (long)port, path];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = method ?: @"GET";
    req.timeoutInterval = 10.0;

    if (body) {
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) completion(nil, error);
            return;
        }

        id json = nil;
        if (data) {
            json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }

        if (completion) {
            completion(json, nil);
        }
    }];
    [task resume];
}

- (void)fetchStatusForBundleId:(NSString *)bundleId completion:(void(^)(NSDictionary *status, NSError *error))completion {
    [self sendRequestToBundleId:bundleId path:@"/status" method:@"GET" body:nil completion:^(id json, NSError *error) {
        if (completion) completion(json, error);
    }];
}

- (void)fetchPacketsForBundleId:(NSString *)bundleId completion:(void(^)(NSArray *packets, NSError *error))completion {
    [self sendRequestToBundleId:bundleId path:@"/packets" method:@"GET" body:nil completion:^(id json, NSError *error) {
        if (completion) {
            if ([json isKindOfClass:[NSDictionary class]] && json[@"packets"]) {
                completion(json[@"packets"], error);
            } else {
                completion(@[], error);
            }
        }
    }];
}

- (void)replayPacketForBundleId:(NSString *)bundleId packetId:(NSString *)packetId completion:(void(^)(BOOL success, id response, NSError *error))completion {
    [self sendRequestToBundleId:bundleId path:@"/packet/replay" method:@"POST" body:@{@"id": packetId} completion:^(id json, NSError *error) {
        if (completion) {
            BOOL ok = [json[@"success"] boolValue];
            completion(ok, json[@"response"], error);
        }
    }];
}

- (void)modifyPacketForBundleId:(NSString *)bundleId packetId:(NSString *)packetId newPayload:(id)payload completion:(void(^)(BOOL success, NSError *error))completion {
    [self sendRequestToBundleId:bundleId path:@"/packet/modify" method:@"POST" body:@{@"id": packetId, @"payload": payload} completion:^(id json, NSError *error) {
        if (completion) {
            BOOL ok = [json[@"success"] boolValue];
            completion(ok, error);
        }
    }];
}

- (void)fetchClassesForBundleId:(NSString *)bundleId keyword:(NSString *)keyword completion:(void(^)(NSArray *classes, NSError *error))completion {
    NSString *path = [NSString stringWithFormat:@"/classes?q=%@", [keyword stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] ?: @""];
    [self sendRequestToBundleId:bundleId path:path method:@"GET" body:nil completion:^(id json, NSError *error) {
        if (completion) {
            completion(json[@"classes"] ?: @[], error);
        }
    }];
}

- (void)inspectClassForBundleId:(NSString *)bundleId className:(NSString *)className completion:(void(^)(NSDictionary *classInfo, NSError *error))completion {
    NSString *path = [NSString stringWithFormat:@"/class/inspect?name=%@", className];
    [self sendRequestToBundleId:bundleId path:path method:@"GET" body:nil completion:^(id json, NSError *error) {
        if (completion) {
            completion(json[@"classInfo"] ?: @{}, error);
        }
    }];
}

- (void)dumpUIForBundleId:(NSString *)bundleId completion:(void(^)(NSDictionary *uiTree, NSError *error))completion {
    [self sendRequestToBundleId:bundleId path:@"/ui/dump" method:@"GET" body:nil completion:^(id json, NSError *error) {
        if (completion) {
            completion(json[@"ui"] ?: @{}, error);
        }
    }];
}

- (void)clickButtonForBundleId:(NSString *)bundleId textOrId:(NSString *)keyword completion:(void(^)(BOOL success, NSError *error))completion {
    [self sendRequestToBundleId:bundleId path:@"/ui/click" method:@"POST" body:@{@"keyword": keyword} completion:^(id json, NSError *error) {
        if (completion) {
            completion([json[@"success"] boolValue], error);
        }
    }];
}

- (void)sendInputForBundleId:(NSString *)bundleId targetId:(NSString *)keyword text:(NSString *)text completion:(void(^)(BOOL success, NSError *error))completion {
    [self sendRequestToBundleId:bundleId path:@"/ui/input" method:@"POST" body:@{@"keyword": keyword, @"text": text} completion:^(id json, NSError *error) {
        if (completion) {
            completion([json[@"success"] boolValue], error);
        }
    }];
}

- (void)showAlertInApp:(NSString *)bundleId title:(NSString *)title message:(NSString *)message completion:(void(^)(BOOL success, NSError *error))completion {
    [self sendRequestToBundleId:bundleId path:@"/ui/show-alert" method:@"POST" body:@{@"title": title ?: @"", @"message": message ?: @""} completion:^(id json, NSError *error) {
        if (completion) {
            completion([json[@"success"] boolValue], error);
        }
    }];
}

- (void)toggleOverlayInApp:(NSString *)bundleId completion:(void(^)(BOOL success, NSError *error))completion {
    [self sendRequestToBundleId:bundleId path:@"/ui/toggle-overlay" method:@"POST" body:nil completion:^(id json, NSError *error) {
        if (completion) {
            completion([json[@"success"] boolValue], error);
        }
    }];
}

- (void)openUrlInApp:(NSString *)bundleId url:(NSString *)url completion:(void(^)(BOOL success, NSError *error))completion {
    [self sendRequestToBundleId:bundleId path:@"/open-url" method:@"POST" body:@{@"url": url} completion:^(id json, NSError *error) {
        if (completion) {
            completion([json[@"success"] boolValue], error);
        }
    }];
}

@end
