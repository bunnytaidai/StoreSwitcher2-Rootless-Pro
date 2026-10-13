#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SSHeader.h"
#import "SSTableViewCell.h"

@interface SSViewController : UINavigationController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableViewController *tableViewController;
@property (nonatomic, strong) NSMutableArray *accounts;

- (void)dismissAnimated;

@end