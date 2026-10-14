#import "AgentPacketManager.h"
#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

@interface AgentPacketManager ()
@property (nonatomic, strong) NSMutableArray<AgentPacket *> *packets;
@property (nonatomic, strong) dispatch_queue_t syncQueue;
@end

@implementation AgentPacketManager

+ (instancetype)sharedManager {
    static AgentPacketManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AgentPacketManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _packets = [NSMutableArray array];
        _syncQueue = dispatch_queue_create("com.agent.packet.sync", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)recordPacket:(AgentPacket *)packet {
    if (!packet) return;
    dispatch_async(self.syncQueue, ^{
        [self.packets insertObject:packet atIndex:0];
        // Giới hạn lưu tối đa 300 packet mới nhất để tiết kiệm RAM
        if (self.packets.count > 300) {
            [self.packets removeLastObject];
        }
    });
}

- (NSArray<NSDictionary *> *)allPacketsAsDictionaries {
    __block NSMutableArray *list = [NSMutableArray array];
    dispatch_sync(self.syncQueue, ^{
        for (AgentPacket *p in self.packets) {
            [list addObject:[p toDictionary]];
        }
    });
    return list;
}

- (AgentPacket *)packetWithId:(NSString *)packetId {
    __block AgentPacket *target = nil;
    dispatch_sync(self.syncQueue, ^{
        for (AgentPacket *p in self.packets) {
            if ([p.packetId isEqualToString:packetId]) {
                target = p;
                break;
            }
        }
    });
    return target;
}

- (BOOL)modifyPacket:(NSString *)packetId newPayload:(id)payload {
    __block BOOL updated = NO;
    dispatch_sync(self.syncQueue, ^{
        for (AgentPacket *p in self.packets) {
            if ([p.packetId isEqualToString:packetId]) {
                p.payload = payload;
                p.isModified = YES;
                updated = YES;
                break;
            }
        }
    });
    return updated;
}

- (void)replayPacket:(NSString *)packetId completion:(void(^)(BOOL success, id response, NSError *error))completion {
    AgentPacket *packet = [self packetWithId:packetId];
    if (!packet) {
        if (completion) {
            NSError *err = [NSError errorWithDomain:@"AgentPacketManager" code:404 userInfo:@{NSLocalizedDescriptionKey: @"Packet ID không tồn tại"}];
            completion(NO, nil, err);
        }
        return;
    }

    if (packet.type == AgentPacketTypeDeeplink) {
        NSString *urlStr = nil;
        if ([packet.payload isKindOfClass:[NSString class]]) {
            urlStr = (NSString *)packet.payload;
        } else if ([packet.payload isKindOfClass:[NSDictionary class]]) {
            urlStr = packet.payload[@"url"];
        }
        
        if (urlStr) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSURL *url = [NSURL URLWithString:urlStr];
                if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
                    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                        if (completion) completion(success, @{@"status": @"Deeplink Triggered", @"url": urlStr}, nil);
                    }];
                } else {
                    if (completion) {
                        NSError *err = [NSError errorWithDomain:@"AgentPacketManager" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Không thể mở URL Scheme"}];
                        completion(NO, nil, err);
                    }
                }
            });
        }
    } else if (packet.type == AgentPacketTypeNetworkAPI) {
        NSDictionary *reqDict = [packet.payload isKindOfClass:[NSDictionary class]] ? (NSDictionary *)packet.payload : nil;
        if (!reqDict || !reqDict[@"url"]) {
            if (completion) {
                NSError *err = [NSError errorWithDomain:@"AgentPacketManager" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Payload Network API không hợp lệ"}];
                completion(NO, nil, err);
            }
            return;
        }

        NSURL *targetUrl = [NSURL URLWithString:reqDict[@"url"]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:targetUrl];
        request.HTTPMethod = reqDict[@"method"] ?: @"GET";
        
        NSDictionary *headers = reqDict[@"headers"];
        if ([headers isKindOfClass:[NSDictionary class]]) {
            for (NSString *key in headers) {
                [request setValue:headers[key] forHTTPHeaderField:key];
            }
        }

        id bodyData = reqDict[@"body"];
        if (bodyData) {
            if ([bodyData isKindOfClass:[NSString class]]) {
                request.HTTPBody = [(NSString *)bodyData dataUsingEncoding:NSUTF8StringEncoding];
            } else if ([bodyData isKindOfClass:[NSDictionary class]] || [bodyData isKindOfClass:[NSArray class]]) {
                NSError *jsonErr;
                request.HTTPBody = [NSJSONSerialization dataWithJSONObject:bodyData options:0 error:&jsonErr];
            }
        }

        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                if (completion) completion(NO, nil, error);
                return;
            }

            id parsedResponse = nil;
            if (data) {
                parsedResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if (!parsedResponse) {
                    parsedResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                }
            }

            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            NSDictionary *result = @{
                @"statusCode": @(httpResp.statusCode),
                @"headers": httpResp.allHeaderFields ?: @{},
                @"data": parsedResponse ?: @""
            };

            if (completion) completion(YES, result, nil);
        }];
        [task resume];
    } else if (packet.type == AgentPacketTypeIAP) {
        // Replay giao dịch IAP StoreKit
        NSDictionary *iapDict = [packet.payload isKindOfClass:[NSDictionary class]] ? (NSDictionary *)packet.payload : nil;
        NSString *productId = iapDict[@"productId"];
        if (!productId) {
            if (completion) {
                NSError *err = [NSError errorWithDomain:@"AgentPacketManager" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Thiếu productId trong payload IAP"}];
                completion(NO, nil, err);
            }
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            SKMutablePayment *payment = [SKMutablePayment paymentWithProductIdentifier:productId];
#pragma clang diagnostic pop
            if (iapDict[@"quantity"]) {
                payment.quantity = [iapDict[@"quantity"] integerValue];
            }
            [[SKPaymentQueue defaultQueue] addPayment:payment];
            if (completion) completion(YES, @{@"status": @"IAP Payment Added to Queue", @"productId": productId}, nil);
        });
    }
}

- (void)clearPackets {
    dispatch_async(self.syncQueue, ^{
        [self.packets removeAllObjects];
    });
}

@end
