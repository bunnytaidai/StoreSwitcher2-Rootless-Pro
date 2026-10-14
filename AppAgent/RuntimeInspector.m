#import "RuntimeInspector.h"
#import <objc/runtime.h>

@implementation RuntimeInspector

+ (NSArray<NSString *> *)classesMatchingKeyword:(NSString *)keyword maxCount:(NSUInteger)maxCount {
    NSMutableArray *results = [NSMutableArray array];
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        Class *classes = (Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        
        NSString *bundlePrefix = [[NSBundle mainBundle] bundleIdentifier];

        for (int i = 0; i < numClasses; i++) {
            Class cls = classes[i];
            const char *name = class_getName(cls);
            if (!name) continue;
            NSString *className = [NSString stringWithUTF8String:name];

            if (keyword && keyword.length > 0) {
                if ([className rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    [results addObject:className];
                }
            } else {
                // Nếu không truyền keyword, ưu tiên lấy class thuộc app chính (bỏ qua tiền tố Apple NS, UI, CF...)
                if (![className hasPrefix:@"_"] &&
                    ![className hasPrefix:@"NS"] &&
                    ![className hasPrefix:@"UI"] &&
                    ![className hasPrefix:@"CA"] &&
                    ![className hasPrefix:@"CF"]) {
                    [results addObject:className];
                }
            }

            if (maxCount > 0 && results.count >= maxCount) {
                break;
            }
        }
        free(classes);
    }
    return results;
}

+ (NSDictionary *)inspectClass:(NSString *)className {
    Class cls = objc_getClass([className UTF8String]);
    if (!cls) return nil;

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"className"] = className;

    Class superCls = class_getSuperclass(cls);
    if (superCls) {
        info[@"superClass"] = [NSString stringWithUTF8String:class_getName(superCls)];
    }

    // 1. Quét Instance Methods
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(cls, &methodCount);
    NSMutableArray *instanceMethods = [NSMutableArray array];
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL sel = method_getName(methods[i]);
        const char *selName = sel_getName(sel);
        const char *types = method_getTypeEncoding(methods[i]);
        [instanceMethods addObject:@{
            @"name": [NSString stringWithUTF8String:selName],
            @"types": types ? [NSString stringWithUTF8String:types] : @""
        }];
    }
    if (methods) free(methods);
    info[@"instanceMethods"] = instanceMethods;

    // 2. Quét Class Methods
    Class metaCls = object_getClass((id)cls);
    if (metaCls) {
        unsigned int classMethodCount = 0;
        Method *cMethods = class_copyMethodList(metaCls, &classMethodCount);
        NSMutableArray *classMethodsList = [NSMutableArray array];
        for (unsigned int i = 0; i < classMethodCount; i++) {
            SEL sel = method_getName(cMethods[i]);
            [classMethodsList addObject:[NSString stringWithUTF8String:sel_getName(sel)]];
        }
        if (cMethods) free(cMethods);
        info[@"classMethods"] = classMethodsList;
    }

    // 3. Quét Properties
    unsigned int propCount = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &propCount);
    NSMutableArray *propList = [NSMutableArray array];
    for (unsigned int i = 0; i < propCount; i++) {
        const char *propName = property_getName(properties[i]);
        const char *propAttr = property_getAttributes(properties[i]);
        [propList addObject:@{
            @"name": [NSString stringWithUTF8String:propName],
            @"attributes": propAttr ? [NSString stringWithUTF8String:propAttr] : @""
        }];
    }
    if (properties) free(properties);
    info[@"properties"] = propList;

    return info;
}

+ (id)invokeMethodOnClass:(NSString *)className selector:(NSString *)selName arguments:(NSArray *)args error:(NSError **)error {
    Class cls = objc_getClass([className UTF8String]);
    if (!cls) {
        if (error) *error = [NSError errorWithDomain:@"RuntimeInspector" code:404 userInfo:@{NSLocalizedDescriptionKey: @"Không tìm thấy Class"}];
        return nil;
    }

    SEL sel = NSSelectorFromString(selName);
    if (!sel) {
        if (error) *error = [NSError errorWithDomain:@"RuntimeInspector" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Selector không hợp lệ"}];
        return nil;
    }

    NSMethodSignature *sig = [cls methodSignatureForSelector:sel];
    id target = cls;
    if (!sig) {
        // Thử tìm trên singleton shared / instance
        if ([cls respondsToSelector:@selector(sharedInstance)]) {
            target = [cls performSelector:@selector(sharedInstance)];
        } else if ([cls respondsToSelector:@selector(shared)]) {
            target = [cls performSelector:@selector(shared)];
        } else if ([cls respondsToSelector:@selector(defaultManager)]) {
            target = [cls performSelector:@selector(defaultManager)];
        }
        
        if (target && target != cls) {
            sig = [target methodSignatureForSelector:sel];
        }
    }

    if (!sig) {
        if (error) *error = [NSError errorWithDomain:@"RuntimeInspector" code:405 userInfo:@{NSLocalizedDescriptionKey: @"Target không nhận Selector này"}];
        return nil;
    }

    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setTarget:target];
    [inv setSelector:sel];

    for (NSUInteger i = 0; i < args.count; i++) {
        id arg = args[i];
        [inv setArgument:&arg atIndex:2 + i];
    }

    [inv invoke];

    const char *retType = [sig methodReturnType];
    if (strcmp(retType, "@") == 0) {
        void *retVal = NULL;
        [inv getReturnValue:&retVal];
        return (__bridge id)retVal;
    }

    return @"Method executed (Void/Primitive)";
}

@end
