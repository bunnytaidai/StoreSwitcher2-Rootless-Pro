#import "UIInspector.h"
#import "AgentPacketManager.h"
#import <objc/runtime.h>

static UIWindow *gOverlayWindow = nil;

@implementation UIInspector

+ (UIWindow *)keyWindow {
    UIWindow *foundWindow = nil;
    NSArray *windows = [UIApplication sharedApplication].windows;
    for (UIWindow *w in windows) {
        if (w.isKeyWindow) {
            foundWindow = w;
            break;
        }
    }
    if (!foundWindow && windows.count > 0) {
        foundWindow = windows.firstObject;
    }
    return foundWindow;
}

+ (NSDictionary *)dumpViewRecursively:(UIView *)view {
    if (!view) return nil;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"class"] = NSStringFromClass([view class]);
    dict[@"frame"] = NSStringFromCGRect(view.frame);
    dict[@"hidden"] = @(view.isHidden);
    dict[@"alpha"] = @(view.alpha);
    dict[@"userInteractionEnabled"] = @(view.isUserInteractionEnabled);

    if (view.accessibilityIdentifier) dict[@"accessibilityId"] = view.accessibilityIdentifier;
    if (view.tag != 0) dict[@"tag"] = @(view.tag);

    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        dict[@"type"] = @"button";
        dict[@"title"] = [btn titleForState:UIControlStateNormal] ?: @"";
    } else if ([view isKindOfClass:[UILabel class]]) {
        UILabel *lbl = (UILabel *)view;
        dict[@"type"] = @"label";
        dict[@"text"] = lbl.text ?: @"";
    } else if ([view isKindOfClass:[UITextField class]]) {
        UITextField *tf = (UITextField *)view;
        dict[@"type"] = @"textField";
        dict[@"text"] = tf.text ?: @"";
        dict[@"placeholder"] = tf.placeholder ?: @"";
    }

    if (view.subviews.count > 0) {
        NSMutableArray *subviewsArray = [NSMutableArray array];
        for (UIView *sub in view.subviews) {
            NSDictionary *childDict = [self dumpViewRecursively:sub];
            if (childDict) [subviewsArray addObject:childDict];
        }
        dict[@"subviews"] = subviewsArray;
    }

    return dict;
}

+ (NSDictionary *)dumpViewHierarchy {
    __block NSMutableDictionary *result = [NSMutableDictionary dictionary];
    dispatch_sync(dispatch_get_main_queue(), ^{
        UIWindow *window = [self keyWindow];
        if (!window) return;
        result[@"bundleId"] = [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
        result[@"windowFrame"] = NSStringFromCGRect(window.frame);
        
        UIViewController *rootVC = window.rootViewController;
        if (rootVC) {
            result[@"rootViewController"] = NSStringFromClass([rootVC class]);
        }
        result[@"tree"] = [self dumpViewRecursively:window];
    });
    return result;
}

+ (UIView *)findButtonMatchingKeyword:(NSString *)keyword inView:(UIView *)view {
    if (!view) return nil;
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        NSString *title = [btn titleForState:UIControlStateNormal];
        if (title && [title rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return btn;
        }
        if (btn.accessibilityIdentifier && [btn.accessibilityIdentifier rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return btn;
        }
    }

    for (UIView *sub in view.subviews) {
        UIView *found = [self findButtonMatchingKeyword:keyword inView:sub];
        if (found) return found;
    }
    return nil;
}

+ (BOOL)tapButtonWithTextOrId:(NSString *)keyword {
    __block BOOL success = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        UIWindow *window = [self keyWindow];
        if (!window) return;
        UIView *target = [self findButtonMatchingKeyword:keyword inView:window];
        if (target && [target isKindOfClass:[UIControl class]]) {
            UIControl *ctrl = (UIControl *)target;
            [ctrl sendActionsForControlEvents:UIControlEventTouchUpInside];
            success = YES;
        }
    });
    return success;
}

+ (UIView *)findTextFieldMatchingKeyword:(NSString *)keyword inView:(UIView *)view {
    if (!view) return nil;
    if ([view isKindOfClass:[UITextField class]]) {
        UITextField *tf = (UITextField *)view;
        if (tf.placeholder && [tf.placeholder rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return tf;
        }
        if (tf.accessibilityIdentifier && [tf.accessibilityIdentifier rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return tf;
        }
    }
    for (UIView *sub in view.subviews) {
        UIView *found = [self findTextFieldMatchingKeyword:keyword inView:sub];
        if (found) return found;
    }
    return nil;
}

+ (BOOL)inputText:(NSString *)text toFieldWithPlaceholderOrId:(NSString *)keyword {
    __block BOOL success = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
        UIWindow *window = [self keyWindow];
        if (!window) return;
        UIView *target = [self findTextFieldMatchingKeyword:keyword inView:window];
        if (target && [target isKindOfClass:[UITextField class]]) {
            UITextField *tf = (UITextField *)target;
            tf.text = text;
            [tf sendActionsForControlEvents:UIControlEventEditingChanged];
            success = YES;
        }
    });
    return success;
}

+ (void)showRemoteAlertWithTitle:(NSString *)title message:(NSString *)message buttons:(NSArray<NSString *> *)buttons {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self keyWindow];
        UIViewController *topVC = window.rootViewController;
        while (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        }

        if (!topVC) return;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title ?: @"AppAgent" message:message preferredStyle:UIAlertControllerStyleAlert];
        
        NSArray *actionButtons = buttons.count > 0 ? buttons : @[@"OK"];
        for (NSString *btnTitle in actionButtons) {
            [alert addAction:[UIAlertAction actionWithTitle:btnTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                // Ghi lại hành động bấm nút của người dùng vào Packet Manager
                AgentPacket *packet = [[AgentPacket alloc] init];
                packet.type = AgentPacketTypeUIAction;
                packet.title = [NSString stringWithFormat:@"[Alert Action] %@", btnTitle];
                packet.payload = @{@"alertTitle": title ?: @"", @"buttonClicked": btnTitle};
                [[AgentPacketManager sharedManager] recordPacket:packet];
            }]];
        }

        [topVC presentViewController:alert animated:YES completion:nil];
    });
}

+ (void)toggleFloatingInspectorOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gOverlayWindow) {
            gOverlayWindow.hidden = YES;
            gOverlayWindow = nil;
            return;
        }

        CGRect frame = CGRectMake(15, 60, 340, 220);
        gOverlayWindow = [[UIWindow alloc] initWithFrame:frame];
        gOverlayWindow.windowLevel = UIWindowLevelAlert + 100;
        gOverlayWindow.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
        gOverlayWindow.layer.cornerRadius = 14;
        gOverlayWindow.layer.borderColor = [UIColor systemGreenColor].CGColor;
        gOverlayWindow.layer.borderWidth = 1.5;
        gOverlayWindow.clipsToBounds = YES;

        UIViewController *overlayVC = [[UIViewController alloc] init];
        
        UILabel *headerLbl = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, 260, 20)];
        headerLbl.text = @"⚡ AppAgent Live Sniffer & Controller";
        headerLbl.textColor = [UIColor systemGreenColor];
        headerLbl.font = [UIFont boldSystemFontOfSize:13];
        [overlayVC.view addSubview:headerLbl];

        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(285, 5, 45, 25);
        [closeBtn setTitle:@"Đóng" forState:UIControlStateNormal];
        closeBtn.tintColor = [UIColor systemRedColor];
        [closeBtn addTarget:self action:@selector(toggleFloatingInspectorOverlay) forControlEvents:UIControlEventTouchUpInside];
        [overlayVC.view addSubview:closeBtn];

        UITextView *logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 35, 320, 175)];
        logView.backgroundColor = [UIColor clearColor];
        logView.textColor = [UIColor whiteColor];
        logView.font = [UIFont fontWithName:@"Courier" size:11];
        logView.editable = NO;

        NSArray *packets = [[AgentPacketManager sharedManager] allPacketsAsDictionaries];
        NSMutableString *logText = [NSMutableString string];
        for (NSDictionary *p in packets) {
            [logText appendFormat:@"[%@] %@\n", p[@"timestamp"] ?: @"", p[@"title"] ?: @""];
        }
        if (logText.length == 0) {
            logText = [NSMutableString stringWithString:@"Chưa có packet nào được ghi nhận.\nHệ thống đang hook StoreKit, Deeplink & API..."];
        }
        logView.text = logText;
        [overlayVC.view addSubview:logView];

        gOverlayWindow.rootViewController = overlayVC;
        gOverlayWindow.hidden = NO;
    });
}

@end
