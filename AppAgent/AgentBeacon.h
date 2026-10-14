#import <Foundation/Foundation.h>

@interface AgentBeacon : NSObject

+ (void)startReportingBeacon;
+ (void)updateIpcPort:(uint16_t)port;
+ (void)updateStoreKitProduct:(NSDictionary *)productDict;

@end
