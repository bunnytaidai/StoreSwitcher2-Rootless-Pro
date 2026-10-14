#import "URLSchemeHook.h"
#import "AgentPacketManager.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void (*orig_openURL_options_completion)(id, SEL, NSURL *, NSDictionary *, void(^)(BOOL));
static void my_openURL_options_completion(id self, SEL _cmd, NSURL *url, NSDictionary *options, void(^completion)(BOOL)) {
    if (url) {
        AgentPacket *packet = [[AgentPacket alloc] init];
        packet.type = AgentPacketTypeDeeplink;
        packet.title = [NSString stringWithFormat:@"[Outgoing Deeplink] %@", url.scheme ?: @"unknown"];
        packet.payload = @{
            @"direction": @"outgoing",
            @"url": url.absoluteString ?: @"",
            @"scheme": url.scheme ?: @"",
            @"host": url.host ?: @"",
            @"path": url.path ?: @"",
            @"query": url.query ?: @"",
            @"options": options ?: @{}
        };
        [[AgentPacketManager sharedManager] recordPacket:packet];
    }

    if (orig_openURL_options_completion) {
        orig_openURL_options_completion(self, _cmd, url, options, completion);
    }
}

// Hook AppDelegate để bắt Deeplink đi vào (Incoming Deeplink)
static void hookAppDelegateMethods(id appDelegate) {
    if (!appDelegate) return;
    Class delegateClass = [appDelegate class];

    SEL selOptions = @selector(application:openURL:options:);
    Method mOptions = class_getInstanceMethod(delegateClass, selOptions);
    if (mOptions) {
        __block BOOL (*orig_openOptions)(id, SEL, UIApplication *, NSURL *, NSDictionary *) = NULL;
        IMP newImp = imp_implementationWithBlock(^BOOL(id target, UIApplication *app, NSURL *url, NSDictionary *options) {
            if (url) {
                AgentPacket *packet = [[AgentPacket alloc] init];
                packet.type = AgentPacketTypeDeeplink;
                packet.title = [NSString stringWithFormat:@"[Incoming Deeplink] %@", url.scheme ?: @"unknown"];
                packet.payload = @{
                    @"direction": @"incoming",
                    @"url": url.absoluteString ?: @"",
                    @"scheme": url.scheme ?: @"",
                    @"host": url.host ?: @"",
                    @"query": url.query ?: @"",
                    @"options": options ?: @{}
                };
                [[AgentPacketManager sharedManager] recordPacket:packet];
            }
            if (orig_openOptions) {
                return orig_openOptions(target, selOptions, app, url, options);
            }
            return YES;
        });
        orig_openOptions = (BOOL (*)(id, SEL, UIApplication *, NSURL *, NSDictionary *))method_setImplementation(mOptions, newImp);
    }
}

static void (*orig_setDelegate)(id, SEL, id<UIApplicationDelegate>);
static void my_setDelegate(id self, SEL _cmd, id<UIApplicationDelegate> delegate) {
    if (delegate) {
        hookAppDelegateMethods(delegate);
    }
    if (orig_setDelegate) {
        orig_setDelegate(self, _cmd, delegate);
    }
}

@implementation URLSchemeHook

+ (void)installHook {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class appClass = [UIApplication class];
        
        // 1. Hook openURL:options:completionHandler:
        Method mOpen = class_getInstanceMethod(appClass, @selector(openURL:options:completionHandler:));
        if (mOpen) {
            orig_openURL_options_completion = (void (*)(id, SEL, NSURL *, NSDictionary *, void(^)(BOOL)))method_setImplementation(mOpen, (IMP)my_openURL_options_completion);
        }

        // 2. Hook setDelegate:
        Method mSetDelegate = class_getInstanceMethod(appClass, @selector(setDelegate:));
        if (mSetDelegate) {
            orig_setDelegate = (void (*)(id, SEL, id<UIApplicationDelegate>))method_setImplementation(mSetDelegate, (IMP)my_setDelegate);
        }

        // Nếu delegate đã tồn tại sẵn
        if ([UIApplication sharedApplication].delegate) {
            hookAppDelegateMethods([UIApplication sharedApplication].delegate);
        }
    });
}

@end
