#import "SSBasePrefsController.h"
#import "SSTerminalConsole.h"

@implementation SSBasePrefsController

@synthesize specifier = _specifier;
@synthesize parentController = _parentController;
@synthesize rootController = _rootController;

- (instancetype)initForContentSize:(CGSize)size {
    return [self init];
}

- (void)setSpecifier:(id)specifier {
    _specifier = specifier;
}

- (id)specifier {
    return _specifier;
}

- (void)setParentController:(id)parent {
    _parentController = parent;
}

- (id)parentController {
    return _parentController;
}

- (void)setRootController:(id)root {
    _rootController = root;
}

- (id)rootController {
    return _rootController;
}

- (BOOL)canBeShownFromSuspendedState {
    return YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[SSTerminalConsole sharedConsole] attachToViewController:self];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[SSTerminalConsole sharedConsole] attachToViewController:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [[SSTerminalConsole sharedConsole] updateLayoutForViewController:self];
}

// Safety net: absorb any other Preferences.framework private selectors
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature *sig = [super methodSignatureForSelector:aSelector];
    if (!sig) {
        sig = [NSMethodSignature signatureWithObjCTypes:"v@:@"];
    }
    return sig;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    // Absorbs unrecognized Preferences selectors gracefully
}

@end
