#import "NetworkPacketHook.h"
#import "AgentPacketManager.h"
#import <objc/runtime.h>

static NSURLSessionDataTask *(*orig_dataTaskWithRequest_completion)(id, SEL, NSURLRequest *, void(^)(NSData *, NSURLResponse *, NSError *));

static NSURLSessionDataTask *my_dataTaskWithRequest_completion(id self, SEL _cmd, NSURLRequest *request, void(^completion)(NSData *, NSURLResponse *, NSError *)) {
    if (!request || !request.URL) {
        if (orig_dataTaskWithRequest_completion) {
            return orig_dataTaskWithRequest_completion(self, _cmd, request, completion);
        }
        return nil;
    }

    NSString *urlStr = request.URL.absoluteString;
    // Bỏ qua các asset tĩnh như ảnh, font để tránh ngập log packet
    BOOL isStaticAsset = [urlStr hasSuffix:@".png"] || [urlStr hasSuffix:@".jpg"] || [urlStr hasSuffix:@".jpeg"] || [urlStr hasSuffix:@".woff"] || [urlStr hasSuffix:@".css"];
    
    if (isStaticAsset) {
        if (orig_dataTaskWithRequest_completion) {
            return orig_dataTaskWithRequest_completion(self, _cmd, request, completion);
        }
        return nil;
    }

    // Trích xuất Request Body
    id bodyPayload = nil;
    if (request.HTTPBody) {
        bodyPayload = [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
        if (!bodyPayload) {
            bodyPayload = [[NSString alloc] initWithData:request.HTTPBody encoding:NSUTF8StringEncoding];
        }
    }

    AgentPacket *packet = [[AgentPacket alloc] init];
    packet.type = AgentPacketTypeNetworkAPI;
    packet.title = [NSString stringWithFormat:@"[%@] %@", request.HTTPMethod ?: @"GET", request.URL.path ?: urlStr];
    packet.headers = request.allHTTPHeaderFields ?: @{};
    packet.payload = @{
        @"url": urlStr,
        @"method": request.HTTPMethod ?: @"GET",
        @"headers": request.allHTTPHeaderFields ?: @{},
        @"body": bodyPayload ?: @""
    };

    void (^wrappedCompletion)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (response && [response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            packet.statusCode = httpResp.statusCode;
        }

        if (data) {
            id jsonResp = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (jsonResp) {
                packet.responseData = jsonResp;
            } else {
                NSString *strResp = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                packet.responseData = strResp ?: [NSString stringWithFormat:@"<Binary %lu bytes>", (unsigned long)data.length];
            }
        } else if (error) {
            packet.responseData = @{@"error": error.localizedDescription};
        }

        [[AgentPacketManager sharedManager] recordPacket:packet];

        if (completion) {
            completion(data, response, error);
        }
    };

    if (orig_dataTaskWithRequest_completion) {
        return orig_dataTaskWithRequest_completion(self, _cmd, request, wrappedCompletion);
    }
    return nil;
}

@implementation NetworkPacketHook

+ (void)installHook {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class sessionClass = [NSURLSession class];
        Method mData = class_getInstanceMethod(sessionClass, @selector(dataTaskWithRequest:completionHandler:));
        if (mData) {
            orig_dataTaskWithRequest_completion = (NSURLSessionDataTask *(*)(id, SEL, NSURLRequest *, void(^)(NSData *, NSURLResponse *, NSError *)))method_setImplementation(mData, (IMP)my_dataTaskWithRequest_completion);
        }
    });
}

@end
