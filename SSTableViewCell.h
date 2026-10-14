#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#else
#import <Foundation/Foundation.h>
@class UITableViewCell;
typedef NS_ENUM(NSInteger, UITableViewCellStyle) {
    UITableViewCellStyleDefault,
    UITableViewCellStyleValue1,
    UITableViewCellStyleValue2,
    UITableViewCellStyleSubtitle
};
#endif

@interface SSTableViewCell: UITableViewCell {
  
}
- (UITableViewCell *)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier;

@end