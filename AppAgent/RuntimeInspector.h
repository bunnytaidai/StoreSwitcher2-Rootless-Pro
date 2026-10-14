#import <Foundation/Foundation.h>

@interface RuntimeInspector : NSObject

+ (NSArray<NSString *> *)classesMatchingKeyword:(NSString *)keyword maxCount:(NSUInteger)maxCount;
+ (NSDictionary *)inspectClass:(NSString *)className;
+ (id)invokeMethodOnClass:(NSString *)className selector:(NSString *)selName arguments:(NSArray *)args error:(NSError **)error;

@end
