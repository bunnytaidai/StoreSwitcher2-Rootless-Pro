#import "AgentIPCServer.h"
#import "AgentPacketManager.h"
#import "RuntimeInspector.h"
#import "UIInspector.h"
#import <UIKit/UIKit.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>

#define REGISTRY_FILE @"/var/mobile/Library/Preferences/com.agent.registered_apps.plist"
#define FALLBACK_REGISTRY @"/tmp/com.agent.registered_apps.plist"

@interface AgentIPCServer ()
@property (nonatomic, assign) int serverSocket;
@property (nonatomic, assign) uint16_t port;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong) dispatch_queue_t serverQueue;
@end

@implementation AgentIPCServer

+ (instancetype)sharedServer {
    static AgentIPCServer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AgentIPCServer alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _serverSocket = -1;
        _serverQueue = dispatch_queue_create("com.agent.ipc.server", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (NSString *)registryPath {
    if ([[NSFileManager defaultManager] isWritableFileAtPath:@"/var/mobile/Library/Preferences"] ||
        [[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/Library/Preferences"]) {
        return REGISTRY_FILE;
    }
    return FALLBACK_REGISTRY;
}

- (void)registerAppInSystem {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown_app";
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?:
                        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"] ?: bundleId;

    NSString *path = [self registryPath];
    NSMutableDictionary *registry = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];

    registry[bundleId] = @{
        @"bundleId": bundleId,
        @"appName": appName,
        @"port": @(self.port),
        @"pid": @(getpid()),
        @"startTime": [[NSDate date] description]
    };

    [registry writeToFile:path atomically:YES];
}

- (void)unregisterAppInSystem {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleId) return;

    NSString *path = [self registryPath];
    NSMutableDictionary *registry = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (registry && registry[bundleId]) {
        [registry removeObjectForKey:bundleId];
        [registry writeToFile:path atomically:YES];
    }
}

- (void)startServer {
    if (self.isRunning) return;

    dispatch_async(self.serverQueue, ^{
        self.serverSocket = socket(AF_INET, SOCK_STREAM, 0);
        if (self.serverSocket < 0) {
            NSLog(@"[AppAgent] Không thể khởi tạo socket IPC!");
            return;
        }

        int opt = 1;
        setsockopt(self.serverSocket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

        struct sockaddr_in serverAddr;
        memset(&serverAddr, 0, sizeof(serverAddr));
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_addr.s_addr = inet_addr("127.0.0.1"); // Chỉ lắng nghe localhost để bảo mật

        // Tự động tìm port trống từ 9100 trở đi
        uint16_t currentPort = 9100;
        int bindResult = -1;
        for (int i = 0; i < 200; i++) {
            currentPort = 9100 + i;
            serverAddr.sin_port = htons(currentPort);
            bindResult = bind(self.serverSocket, (struct sockaddr *)&serverAddr, sizeof(serverAddr));
            if (bindResult == 0) break;
        }

        if (bindResult < 0) {
            NSLog(@"[AppAgent] Lỗi bind socket IPC port!");
            close(self.serverSocket);
            self.serverSocket = -1;
            return;
        }

        if (listen(self.serverSocket, 15) < 0) {
            NSLog(@"[AppAgent] Lỗi listen socket IPC!");
            close(self.serverSocket);
            self.serverSocket = -1;
            return;
        }

        self.port = currentPort;
        self.isRunning = YES;
        [self registerAppInSystem];

        NSLog(@"[AppAgent] IPC REST Server đang chạy tại 127.0.0.1:%d cho App: %@", self.port, [[NSBundle mainBundle] bundleIdentifier]);

        while (self.isRunning) {
            struct sockaddr_in clientAddr;
            socklen_t clientLen = sizeof(clientAddr);
            int clientSocket = accept(self.serverSocket, (struct sockaddr *)&clientAddr, &clientLen);
            if (clientSocket < 0) {
                if (!self.isRunning) break;
                continue;
            }

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self handleClient:clientSocket];
            });
        }
    });
}

- (void)handleClient:(int)clientSocket {
    char buffer[16384];
    memset(buffer, 0, sizeof(buffer));
    ssize_t bytesRead = recv(clientSocket, buffer, sizeof(buffer) - 1, 0);

    if (bytesRead <= 0) {
        close(clientSocket);
        return;
    }

    NSString *rawRequest = [NSString stringWithUTF8String:buffer];
    if (!rawRequest) {
        close(clientSocket);
        return;
    }

    NSArray *lines = [rawRequest componentsSeparatedByString:@"\r\n"];
    if (lines.count == 0) {
        close(clientSocket);
        return;
    }

    NSString *requestLine = lines.firstObject;
    NSArray *reqParts = [requestLine componentsSeparatedByString:@" "];
    if (reqParts.count < 2) {
        close(clientSocket);
        return;
    }

    NSString *method = reqParts[0];
    NSString *fullPath = reqParts[1];

    // Trích xuất path và query params
    NSString *endpoint = fullPath;
    NSString *queryString = @"";
    NSRange qRange = [fullPath rangeOfString:@"?"];
    if (qRange.location != NSNotFound) {
        endpoint = [fullPath substringToIndex:qRange.location];
        queryString = [fullPath substringFromIndex:qRange.location + 1];
    }

    NSMutableDictionary *queryParams = [NSMutableDictionary dictionary];
    if (queryString.length > 0) {
        NSArray *pairs = [queryString componentsSeparatedByString:@"&"];
        for (NSString *p in pairs) {
            NSArray *kv = [p componentsSeparatedByString:@"="];
            if (kv.count == 2) {
                queryParams[kv[0]] = [kv[1] stringByRemovingPercentEncoding] ?: kv[1];
            }
        }
    }

    // Trích xuất Request Body nếu có POST
    id jsonBody = nil;
    NSRange bodyRange = [rawRequest rangeOfString:@"\r\n\r\n"];
    if (bodyRange.location != NSNotFound) {
        NSString *bodyStr = [rawRequest substringFromIndex:bodyRange.location + 4];
        if (bodyStr.length > 0) {
            NSData *bodyData = [bodyStr dataUsingEncoding:NSUTF8StringEncoding];
            if (bodyData) {
                jsonBody = [NSJSONSerialization JSONObjectWithData:bodyData options:0 error:nil];
            }
        }
    }

    NSDictionary *responseDict = [self routeEndpoint:endpoint method:method params:queryParams body:jsonBody];
    [self sendJsonResponse:responseDict toSocket:clientSocket];
    close(clientSocket);
}

- (NSDictionary *)routeEndpoint:(NSString *)endpoint method:(NSString *)method params:(NSDictionary *)params body:(id)body {
    // 1. Kiểm tra trạng thái App & Thông tin tổng quát
    if ([endpoint isEqualToString:@"/status"]) {
        return @{
            @"success": @YES,
            @"bundleId": [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown",
            @"appName": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: @"App",
            @"pid": @(getpid()),
            @"port": @(self.port),
            @"version": [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.0",
            @"device": [UIDevice currentDevice].name ?: @"iPhone",
            @"systemVersion": [UIDevice currentDevice].systemVersion ?: @"iOS"
        };
    }

    // 2. Lấy danh sách Packets (StoreKit IAP, Deeplink, Network API)
    if ([endpoint isEqualToString:@"/packets"]) {
        return @{
            @"success": @YES,
            @"count": @([[AgentPacketManager sharedManager] allPacketsAsDictionaries].count),
            @"packets": [[AgentPacketManager sharedManager] allPacketsAsDictionaries]
        };
    }

    // 3. Xoá lịch sử Packets
    if ([endpoint isEqualToString:@"/packets/clear"]) {
        [[AgentPacketManager sharedManager] clearPackets];
        return @{@"success": @YES, @"message": @"Đã xoá bộ nhớ đệm packet!"};
    }

    // 4. Sửa Payload của Packet
    if ([endpoint isEqualToString:@"/packet/modify"] && [method isEqualToString:@"POST"]) {
        NSString *packetId = body[@"id"] ?: params[@"id"];
        id newPayload = body[@"payload"];
        if (packetId && newPayload) {
            BOOL ok = [[AgentPacketManager sharedManager] modifyPacket:packetId newPayload:newPayload];
            return @{@"success": @(ok), @"message": ok ? @"Đã cập nhật packet" : @"Không tìm thấy packet"};
        }
        return @{@"success": @NO, @"error": @"Thiếu packetId hoặc payload"};
    }

    // 5. Gửi lại / Replay Packet (Replay API / IAP / Deeplink)
    if ([endpoint isEqualToString:@"/packet/replay"] && [method isEqualToString:@"POST"]) {
        NSString *packetId = body[@"id"] ?: params[@"id"];
        if (!packetId) return @{@"success": @NO, @"error": @"Thiếu packetId"};

        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        __block NSDictionary *respResult = nil;
        [[AgentPacketManager sharedManager] replayPacket:packetId completion:^(BOOL success, id response, NSError *error) {
            respResult = @{
                @"success": @(success),
                @"response": response ?: @"",
                @"error": error.localizedDescription ?: @""
            };
            dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
        return respResult ?: @{@"success": @NO, @"error": @"Timeout khi replay packet"};
    }

    // 6. Quét danh sách Class trong app
    if ([endpoint isEqualToString:@"/classes"]) {
        NSString *q = params[@"q"] ?: @"";
        NSUInteger max = params[@"max"] ? [params[@"max"] integerValue] : 100;
        NSArray *classes = [RuntimeInspector classesMatchingKeyword:q maxCount:max];
        return @{@"success": @YES, @"count": @(classes.count), @"classes": classes};
    }

    // 7. Soi chi tiết Class (Methods, Properties, Actions)
    if ([endpoint isEqualToString:@"/class/inspect"]) {
        NSString *name = params[@"name"] ?: body[@"name"];
        if (!name) return @{@"success": @NO, @"error": @"Thiếu tên class"};
        NSDictionary *detail = [RuntimeInspector inspectClass:name];
        return @{@"success": @(detail != nil), @"classInfo": detail ?: @{}};
    }

    // 8. Thực thi Method động (Invoke Selector)
    if ([endpoint isEqualToString:@"/class/invoke"] && [method isEqualToString:@"POST"]) {
        NSString *name = body[@"className"];
        NSString *sel = body[@"selector"];
        NSArray *args = body[@"args"] ?: @[];
        if (!name || !sel) return @{@"success": @NO, @"error": @"Thiếu className hoặc selector"};

        NSError *err = nil;
        id ret = [RuntimeInspector invokeMethodOnClass:name selector:sel arguments:args error:&err];
        if (err) return @{@"success": @NO, @"error": err.localizedDescription};
        return @{@"success": @YES, @"result": ret ?: @"nil"};
    }

    // 9. Quét cây giao diện UI (Dump UI Hierarchy)
    if ([endpoint isEqualToString:@"/ui/dump"]) {
        NSDictionary *uiTree = [UIInspector dumpViewHierarchy];
        return @{@"success": @YES, @"ui": uiTree};
    }

    // 10. Giả lập Click Nút bấm
    if ([endpoint isEqualToString:@"/ui/click"] && [method isEqualToString:@"POST"]) {
        NSString *target = body[@"keyword"] ?: params[@"keyword"];
        if (!target) return @{@"success": @NO, @"error": @"Thiếu keyword nút bấm"};
        BOOL ok = [UIInspector tapButtonWithTextOrId:target];
        return @{@"success": @(ok), @"message": ok ? @"Đã bấm nút thành công" : @"Không tìm thấy nút bấm"};
    }

    // 11. Nhập văn bản vào ô Input
    if ([endpoint isEqualToString:@"/ui/input"] && [method isEqualToString:@"POST"]) {
        NSString *target = body[@"keyword"];
        NSString *text = body[@"text"];
        if (!target || !text) return @{@"success": @NO, @"error": @"Thiếu keyword hoặc text"};
        BOOL ok = [UIInspector inputText:text toFieldWithPlaceholderOrId:target];
        return @{@"success": @(ok), @"message": ok ? @"Đã nhập liệu thành công" : @"Không tìm thấy ô nhập liệu"};
    }

    // 12. Hiển thị Popup Alert từ app
    if ([endpoint isEqualToString:@"/ui/show-alert"] && [method isEqualToString:@"POST"]) {
        NSString *title = body[@"title"] ?: @"Thông báo từ AppAgent";
        NSString *msg = body[@"message"] ?: @"";
        NSArray *btns = body[@"buttons"] ?: @[@"OK"];
        [UIInspector showRemoteAlertWithTitle:title message:msg buttons:btns];
        return @{@"success": @YES, @"message": @"Đã hiển thị popup trên app"};
    }

    // 13. Bật/Tắt Live HUD Sniffer nổi trên màn hình
    if ([endpoint isEqualToString:@"/ui/toggle-overlay"]) {
        [UIInspector toggleFloatingInspectorOverlay];
        return @{@"success": @YES, @"message": @"Đã bật/tắt HUD Inspector"};
    }

    // 14. Mở Deeplink URL Scheme trực tiếp
    if ([endpoint isEqualToString:@"/open-url"] && [method isEqualToString:@"POST"]) {
        NSString *urlStr = body[@"url"] ?: params[@"url"];
        if (!urlStr) return @{@"success": @NO, @"error": @"Thiếu url"};
        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL *url = [NSURL URLWithString:urlStr];
            if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            }
        });
        return @{@"success": @YES, @"message": [NSString stringWithFormat:@"Đã trigger mở URL: %@", urlStr]};
    }

    return @{@"success": @NO, @"error": @"404 Not Found", @"endpoint": endpoint ?: @""};
}

- (void)sendJsonResponse:(NSDictionary *)dict toSocket:(int)socket {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    if (!jsonData) {
        jsonData = [@"{\"success\":false,\"error\":\"JSON Serialize Error\"}" dataUsingEncoding:NSUTF8StringEncoding];
    }

    NSString *header = [NSString stringWithFormat:
        @"HTTP/1.1 200 OK\r\n"
        @"Content-Type: application/json; charset=utf-8\r\n"
        @"Content-Length: %lu\r\n"
        @"Access-Control-Allow-Origin: *\r\n"
        @"Connection: close\r\n\r\n", (unsigned long)jsonData.length];

    send(socket, [header UTF8String], strlen([header UTF8String]), 0);
    send(socket, [jsonData bytes], [jsonData length], 0);
}

- (void)stopServer {
    self.isRunning = NO;
    if (self.serverSocket >= 0) {
        close(self.serverSocket);
        self.serverSocket = -1;
    }
    [self unregisterAppInSystem];
}

- (void)dealloc {
    [self stopServer];
}

@end
