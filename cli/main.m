#import <Foundation/Foundation.h>

#define REGISTRY_FILE @"/var/mobile/Library/Preferences/com.agent.registered_apps.plist"
#define FALLBACK_REGISTRY @"/tmp/com.agent.registered_apps.plist"

static NSDictionary *getRegistry() {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:REGISTRY_FILE];
    if (!dict) {
        dict = [NSDictionary dictionaryWithContentsOfFile:FALLBACK_REGISTRY];
    }
    return dict ?: @{};
}

static NSInteger getPortForApp(NSString *appQuery) {
    if (!appQuery || appQuery.length == 0) return 0;

    // 1. Kiểm tra beacon file trực tiếp
    NSString *beaconDir = @"/var/mobile/Library/Application Support/StoreSwitcher/injected_beacons";
    if (![[NSFileManager defaultManager] fileExistsAtPath:beaconDir]) {
        beaconDir = @"/var/jb/var/mobile/Library/Application Support/StoreSwitcher/injected_beacons";
    }
    NSString *bPath = [beaconDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", appQuery]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:bPath]) {
        NSData *d = [NSData dataWithContentsOfFile:bPath];
        if (d) {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
            if ([dict isKindOfClass:[NSDictionary class]] && dict[@"ipcPort"]) {
                NSInteger port = [dict[@"ipcPort"] integerValue];
                if (port > 0) return port;
            }
        }
    }

    // 2. Tìm kiếm trong registry
    NSDictionary *reg = getRegistry();
    if (reg[appQuery]) {
        return [reg[appQuery][@"port"] integerValue];
    }

    // Tìm kiếm tương đối theo tên hoặc bundleId
    for (NSString *bundleId in reg) {
        NSDictionary *item = reg[bundleId];
        NSString *appName = item[@"appName"];
        if ([bundleId rangeOfString:appQuery options:NSCaseInsensitiveSearch].location != NSNotFound ||
            (appName && [appName rangeOfString:appQuery options:NSCaseInsensitiveSearch].location != NSNotFound)) {
            return [item[@"port"] integerValue];
        }
    }
    return 0;
}

static id callApi(NSInteger port, NSString *path, NSString *method, id body) {
    NSString *urlStr = [NSString stringWithFormat:@"http://127.0.0.1:%ld%@", (long)port, path];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = method ?: @"GET";
    req.timeoutInterval = 10.0;

    if (body) {
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }

    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block id jsonResp = nil;
    __block NSError *reqError = nil;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            reqError = error;
        } else if (data) {
            jsonResp = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (!jsonResp) {
                jsonResp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
        }
        dispatch_semaphore_signal(sema);
    }];
    [task resume];
    dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));

    if (reqError) {
        printf("[Lỗi] Không thể kết nối tới App: %s\n", reqError.localizedDescription.UTF8String);
        return nil;
    }
    return jsonResp;
}

static void printPrettyJson(id obj) {
    if (!obj) return;
    if ([obj isKindOfClass:[NSDictionary class]] || [obj isKindOfClass:[NSArray class]]) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:NSJSONWritingPrettyPrinted error:nil];
        if (data) {
            NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            printf("%s\n", str.UTF8String);
            return;
        }
    }
    printf("%s\n", [obj description].UTF8String);
}

static void printHelp() {
    printf("===============================================================\n");
    printf(" ⚡ AppAgent CLI - Điều khiển & Khai thác App iOS ⚡\n");
    printf("===============================================================\n");
    printf("Cách sử dụng: agentcli <lệnh> [tham số...]\n\n");
    printf("Danh sách lệnh:\n");
    printf("  list                                   : Liệt kê các app đang chạy có tiêm AppAgent\n");
    printf("  <app> status                           : Xem trạng thái, PID, thông tin app\n");
    printf("  <app> packets                          : Xem danh sách packet (IAP, Deeplink, API)\n");
    printf("  <app> replay <packet_id>               : Gửi lại (Replay) packet IAP, Deeplink, API\n");
    printf("  <app> modify <packet_id> <payload_json>: Sửa payload của packet đã bắt\n");
    printf("  <app> classes [keyword]                : Quét danh sách Class trong app\n");
    printf("  <app> inspect <class_name>             : Soi chi tiết Methods, Properties của Class\n");
    printf("  <app> dump-ui                          : Trích xuất toàn bộ cây giao diện UI\n");
    printf("  <app> click <text_or_id>               : Bấm nút bấm trên app từ xa\n");
    printf("  <app> input <field_id> <text>          : Nhập văn bản vào ô nhập liệu trên app\n");
    printf("  <app> alert <title> <message>          : Bắn popup thông báo vào app\n");
    printf("  <app> overlay                          : Bật/Tắt Live HUD Sniffer nổi trên app\n");
    printf("  <app> open-url <url_scheme>            : Kích hoạt app mở URL Scheme / Deeplink\n");
    printf("===============================================================\n");
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            printHelp();
            return 0;
        }

        NSString *cmd = [NSString stringWithUTF8String:argv[1]];

        if ([cmd isEqualToString:@"help"] || [cmd isEqualToString:@"-h"] || [cmd isEqualToString:@"--help"]) {
            printHelp();
            return 0;
        }

        if ([cmd isEqualToString:@"list"]) {
            NSDictionary *reg = getRegistry();
            printf("Danh sách ứng dụng đang chạy có AppAgent (%lu):\n", (unsigned long)reg.count);
            for (NSString *bundleId in reg) {
                NSDictionary *info = reg[bundleId];
                printf(" - [%s] PID: %ld | Port: %ld | Tên: %s\n",
                       bundleId.UTF8String,
                       (long)[info[@"pid"] integerValue],
                       (long)[info[@"port"] integerValue],
                       [info[@"appName"] UTF8String] ?: "Unknown");
            }
            return 0;
        }

        NSString *appQuery = cmd;
        NSInteger port = getPortForApp(appQuery);
        if (port <= 0) {
            printf("[Lỗi] Không tìm thấy App '%s' đang chạy hoặc App chưa được tiêm AppAgent.dylib!\n", appQuery.UTF8String);
            printf("Gõ 'agentcli list' để xem danh sách app đang kích hoạt.\n");
            return 1;
        }

        if (argc < 3) {
            printf("[Lỗi] Thiếu hành động cho app '%s'. Gõ 'agentcli help' để xem cú pháp.\n", appQuery.UTF8String);
            return 1;
        }

        NSString *subCmd = [NSString stringWithUTF8String:argv[2]];

        if ([subCmd isEqualToString:@"status"]) {
            id resp = callApi(port, @"/status", @"GET", nil);
            printPrettyJson(resp);
        } else if ([subCmd isEqualToString:@"packets"]) {
            id resp = callApi(port, @"/packets", @"GET", nil);
            printPrettyJson(resp);
        } else if ([subCmd isEqualToString:@"clear-packets"]) {
            id resp = callApi(port, @"/packets/clear", @"GET", nil);
            printPrettyJson(resp);
        } else if ([subCmd isEqualToString:@"replay"]) {
            if (argc < 4) {
                printf("[Lỗi] Cần cung cấp <packet_id>. Ví dụ: agentcli %s replay <id>\n", appQuery.UTF8String);
                return 1;
            }
            NSString *pktId = [NSString stringWithUTF8String:argv[3]];
            id resp = callApi(port, @"/packet/replay", @"POST", @{@"id": pktId});
            printPrettyJson(resp);
        } else if ([subCmd isEqualToString:@"modify"]) {
            if (argc < 5) {
                printf("[Lỗi] Cần cung cấp <packet_id> và <json_payload>.\n");
                return 1;
            }
            NSString *pktId = [NSString stringWithUTF8String:argv[3]];
            NSString *jsonStr = [NSString stringWithUTF8String:argv[4]];
            NSData *d = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
            id parsedPayload = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] ?: jsonStr;
            id resp = callApi(port, @"/packet/modify", @"POST", @{@"id": pktId, @"payload": parsedPayload});
            printPrettyJson(resp);
        } else if ([subCmd isEqualToString:@"classes"]) {
            NSString *q = argc >= 4 ? [NSString stringWithUTF8String:argv[3]] : @"";
            NSString *path = [NSString stringWithFormat:@"/classes?q=%@", [q stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
            id resp = callApi(port, path, @"GET", nil);
            printPrettyJson(resp);
        } else if ([subCmd isEqualToString:@"inspect"]) {
            if (argc < 4) {
                printf("[Lỗi] Cần cung cấp <class_name>.\n");
                return 1;
            }
            NSString *clsName = [NSString stringWithUTF8String:argv[3]];
            NSString *path = [NSString stringWithFormat:@"/class/inspect?name=%@", clsName];
            id resp = callApi(port, path, @"GET", nil);
            printPrettyJson(resp);
        } else if ([subCmd isEqualToString:@"dump-ui"]) {
            id resp = callApi(port, @"/ui/dump", @"GET", nil);
            printPrettyJson(resp);
        } else if ([subCmd isEqualToString:@"click"]) {
            if (argc < 4) {
                printf("[Lỗi] Cần cung cấp tên nút hoặc accessibilityId.\n");
                return 1;
            }
            NSString *target = [NSString stringWithUTF8String:argv[3]];
            id resp = callApi(port, @"/ui/click", @"POST", @{@"keyword": target});
            printPrettyJson(resp);
        } else if ([subCmd isEqualToString:@"input"]) {
            if (argc < 5) {
                printf("[Lỗi] Cần cung cấp <field_id> và <text>.\n");
                return 1;
            }
            NSString *target = [NSString stringWithUTF8String:argv[3]];
            NSString *text = [NSString stringWithUTF8String:argv[4]];
            id resp = callApi(port, @"/ui/input", @"POST", @{@"keyword": target, @"text": text});
            printPrettyJson(resp);
        } else if ([subCmd isEqualToString:@"alert"]) {
            NSString *title = argc >= 4 ? [NSString stringWithUTF8String:argv[3]] : @"Thông báo";
            NSString *msg = argc >= 5 ? [NSString stringWithUTF8String:argv[4]] : @"Nội dung test từ Terminal";
            id resp = callApi(port, @"/ui/show-alert", @"POST", @{@"title": title, @"message": msg});
            printPrettyJson(resp);
        } else if ([subCmd isEqualToString:@"overlay"]) {
            id resp = callApi(port, @"/ui/toggle-overlay", @"POST", nil);
            printPrettyJson(resp);
        } else if ([subCmd isEqualToString:@"open-url"]) {
            if (argc < 4) {
                printf("[Lỗi] Cần cung cấp URL Scheme. Ví dụ: agentcli %s open-url itms-apps://\n", appQuery.UTF8String);
                return 1;
            }
            NSString *url = [NSString stringWithUTF8String:argv[3]];
            id resp = callApi(port, @"/open-url", @"POST", @{@"url": url});
            printPrettyJson(resp);
        } else {
            printf("[Lỗi] Lệnh không nhận diện: %s. Gõ 'agentcli help' để xem hướng dẫn.\n", subCmd.UTF8String);
        }
    }
    return 0;
}
