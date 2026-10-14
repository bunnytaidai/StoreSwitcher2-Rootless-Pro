#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

@interface UIInspector : NSObject

+ (NSDictionary *)dumpViewHierarchy;
+ (BOOL)tapButtonWithTextOrId:(NSString *)keyword;
+ (BOOL)inputText:(NSString *)text toFieldWithPlaceholderOrId:(NSString *)keyword;
+ (void)showRemoteAlertWithTitle:(NSString *)title message:(NSString *)message buttons:(NSArray<NSString *> *)buttons;
+ (void)toggleFloatingInspectorOverlay;

@end
