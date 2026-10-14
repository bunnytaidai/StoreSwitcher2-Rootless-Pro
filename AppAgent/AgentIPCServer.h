#import <Foundation/Foundation.h>

@interface AgentIPCServer : NSObject

+ (instancetype)sharedServer;
- (void)startServer;
- (void)stopServer;

@property (nonatomic, assign, readonly) uint16_t port;
@property (nonatomic, assign, readonly) BOOL isRunning;

@end
