#import <UIKit/UIKit.h>

@interface SSTerminalConsole : NSObject

+ (instancetype)shared;
+ (instancetype)sharedConsole;
+ (void)log:(NSString *)format, ...;
+ (void)logAction:(NSString *)action status:(NSString *)status details:(NSString *)details;
+ (void)clear;
+ (void)clearLogs;
- (void)clear;
- (void)clearLogs;
+ (NSString *)allLogs;
+ (void)attachToViewController:(UIViewController *)vc;
+ (void)updateLayoutForViewController:(UIViewController *)vc;
- (void)updateLayoutForViewController:(UIViewController *)vc;
- (void)attachToViewController:(UIViewController *)vc;
- (void)toggleExpanded;
+ (void)toggleExpanded;
+ (CGFloat)currentConsoleHeight;
+ (void)showInViewController:(UIViewController *)vc;

@end
