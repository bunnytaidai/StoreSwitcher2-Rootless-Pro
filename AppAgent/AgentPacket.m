#import "AgentPacket.h"

@implementation AgentPacket

- (instancetype)init {
    self = [super init];
    if (self) {
        _packetId = [[NSUUID UUID] UUIDString];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
        _timestamp = [formatter stringFromDate:[NSDate date]];
        _isModified = NO;
    }
    return self;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"id"] = self.packetId ?: @"";
    dict[@"type"] = @(self.type);
    dict[@"timestamp"] = self.timestamp ?: @"";
    dict[@"title"] = self.title ?: @"";
    if (self.headers) dict[@"headers"] = self.headers;
    if (self.payload) dict[@"payload"] = self.payload;
    if (self.responseData) dict[@"responseData"] = self.responseData;
    dict[@"statusCode"] = @(self.statusCode);
    dict[@"isModified"] = @(self.isModified);
    return dict;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    AgentPacket *packet = [[AgentPacket alloc] init];
    if (dict[@"id"]) packet.packetId = dict[@"id"];
    if (dict[@"type"]) packet.type = [dict[@"type"] integerValue];
    if (dict[@"timestamp"]) packet.timestamp = dict[@"timestamp"];
    if (dict[@"title"]) packet.title = dict[@"title"];
    if (dict[@"headers"]) packet.headers = dict[@"headers"];
    if (dict[@"payload"]) packet.payload = dict[@"payload"];
    if (dict[@"responseData"]) packet.responseData = dict[@"responseData"];
    if (dict[@"statusCode"]) packet.statusCode = [dict[@"statusCode"] integerValue];
    if (dict[@"isModified"]) packet.isModified = [dict[@"isModified"] boolValue];
    return packet;
}

@end
