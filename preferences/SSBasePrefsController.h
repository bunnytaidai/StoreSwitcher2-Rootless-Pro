#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface SSBasePrefsController : UITableViewController

@property (nonatomic, strong) id specifier;
@property (nonatomic, weak) id parentController;
@property (nonatomic, weak) id rootController;

- (instancetype)initForContentSize:(CGSize)size;
- (void)setSpecifier:(id)specifier;
- (id)specifier;
- (void)setParentController:(id)parent;
- (id)parentController;
- (void)setRootController:(id)root;
- (id)rootController;
- (BOOL)canBeShownFromSuspendedState;

@end
