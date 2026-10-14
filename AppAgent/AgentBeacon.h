#import <Foundation/Foundation.h>

@interface AgentBeacon : NSObject

+ (void)startReportingBeacon;
+ (void)updateStoreKitProduct:(NSDictionary *)productDict;

@end
