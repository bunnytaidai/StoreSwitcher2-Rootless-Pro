#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, AgentPacketType) {
    AgentPacketTypeIAP = 1,
    AgentPacketTypeDeeplink = 2,
    AgentPacketTypeNetworkAPI = 3,
    AgentPacketTypeUIAction = 4
};

@interface AgentPacket : NSObject

@property (nonatomic, copy) NSString *packetId;
@property (nonatomic, assign) AgentPacketType type;
@property (nonatomic, copy) NSString *timestamp;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSDictionary *headers;
@property (nonatomic, strong) id payload;
@property (nonatomic, strong) id responseData;
@property (nonatomic, assign) NSInteger statusCode;
@property (nonatomic, assign) BOOL isModified;

- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end
