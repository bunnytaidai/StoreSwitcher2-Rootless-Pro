#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#else
#import <Foundation/Foundation.h>
@class UIViewController, UINavigationController, UITableViewController, UITableView, UITableViewCell, UIBarButtonItem, UIImage, UIAlertController, UIAlertAction, UIColor, UIFont, UIView, NSIndexPath;
@protocol UITableViewDelegate <NSObject>
@end
@protocol UITableViewDataSource <NSObject>
@end
typedef NS_ENUM(NSInteger, UITableViewCellEditingStyle) {
    UITableViewCellEditingStyleNone,
    UITableViewCellEditingStyleDelete,
    UITableViewCellEditingStyleInsert
};
typedef NS_ENUM(NSInteger, UITableViewCellAccessoryType) {
    UITableViewCellAccessoryNone,
    UITableViewCellAccessoryDisclosureIndicator,
    UITableViewCellAccessoryDetailDisclosureButton,
    UITableViewCellAccessoryCheckmark,
    UITableViewCellAccessoryDetailButton
};
typedef NS_ENUM(NSInteger, UITableViewStyle) {
    UITableViewStylePlain,
    UITableViewStyleGrouped,
    UITableViewStyleInsetGrouped
};
typedef NS_ENUM(NSInteger, UIBarButtonItemStyle) {
    UIBarButtonItemStylePlain,
    UIBarButtonItemStyleBordered,
    UIBarButtonItemStyleDone
};
typedef NS_ENUM(NSInteger, UIBarButtonSystemItem) {
    UIBarButtonSystemItemDone,
    UIBarButtonSystemItemCancel,
    UIBarButtonSystemItemEdit,
    UIBarButtonSystemItemSave,
    UIBarButtonSystemItemAdd,
    UIBarButtonSystemItemFlexibleSpace,
    UIBarButtonSystemItemFixedSpace,
    UIBarButtonSystemItemCompose,
    UIBarButtonSystemItemReply,
    UIBarButtonSystemItemAction,
    UIBarButtonSystemItemOrganize,
    UIBarButtonSystemItemBookmarks,
    UIBarButtonSystemItemSearch,
    UIBarButtonSystemItemRefresh,
    UIBarButtonSystemItemStop,
    UIBarButtonSystemItemCamera,
    UIBarButtonSystemItemTrash,
    UIBarButtonSystemItemPlay,
    UIBarButtonSystemItemPause,
    UIBarButtonSystemItemStopAudio,
    UIBarButtonSystemItemPageCurl
};
typedef NS_ENUM(NSInteger, UIModalPresentationStyle) {
    UIModalPresentationFullScreen = 0,
    UIModalPresentationPageSheet = 1,
    UIModalPresentationFormSheet = 2,
    UIModalPresentationCurrentContext = 3,
    UIModalPresentationCustom = 4,
    UIModalPresentationOverFullScreen = 5,
    UIModalPresentationOverCurrentContext = 6,
    UIModalPresentationPopover = 7,
    UIModalPresentationNone = -1,
    UIModalPresentationAutomatic = -2
};
#endif

#import <objc/runtime.h>
#import "SSHeader.h"
#import "SSTableViewCell.h"

@interface SSViewController: UINavigationController<UITableViewDelegate, UITableViewDataSource> {
  UITableViewController *_tableViewController;
  NSMutableArray *_accounts;
}

@property(retain, nonatomic) UITableViewController *tableViewController;
@property(retain, nonatomic) NSMutableArray *accounts;

@end