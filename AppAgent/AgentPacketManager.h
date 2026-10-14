#import <Foundation/Foundation.h>
#import "AgentPacket.h"

@interface AgentPacketManager : NSObject

+ (instancetype)sharedManager;

@property (nonatomic, strong, readonly) NSMutableArray<AgentPacket *> *packets;

- (void)recordPacket:(AgentPacket *)packet;
- (NSArray<NSDictionary *> *)allPacketsAsDictionaries;
- (AgentPacket *)packetWithId:(NSString *)packetId;
- (BOOL)modifyPacket:(NSString *)packetId newPayload:(id)payload;
- (void)replayPacket:(NSString *)packetId completion:(void(^)(BOOL success, id response, NSError *error))completion;
- (void)clearPackets;

@end
