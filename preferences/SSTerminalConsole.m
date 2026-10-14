#import "SSTerminalConsole.h"

#define LOG_FILE_PATH @"/var/mobile/Library/Application Support/StoreSwitcher/activity.log"
#define FALLBACK_LOG_PATH @"/tmp/storeswitcher_activity.log"

@interface SSTerminalConsole ()
@property (nonatomic, strong) UIView *dockedView;
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *toggleBtn;
@property (nonatomic, strong) NSMutableString *logBuffer;
@property (nonatomic, assign) BOOL isExpanded;
@property (nonatomic, weak) UIViewController *currentVC;
@end

@implementation SSTerminalConsole

+ (instancetype)shared {
    static SSTerminalConsole *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SSTerminalConsole alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _logBuffer = [NSMutableString string];
        _isExpanded = YES;
        
        // Nạp log cũ từ file nếu có
        NSString *path = [self activeLogPath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            NSString *existing = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
            if (existing && existing.length > 0) {
                // Giữ lại 15 dòng gần nhất
                NSArray *lines = [existing componentsSeparatedByString:@"\n"];
                NSInteger start = (lines.count > 20) ? (lines.count - 20) : 0;
                for (NSInteger i = start; i < lines.count; i++) {
                    if ([lines[i] length] > 0) {
                        [_logBuffer appendFormat:@"%@\n", lines[i]];
                    }
                }
            }
        }
        
        if (_logBuffer.length == 0) {
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            [fmt setDateFormat:@"HH:mm:ss"];
            NSString *now = [fmt stringFromDate:[NSDate date]];
            [_logBuffer appendFormat:@"[%@] >_ StoreSwitcher Pro 2.4.0 Terminal Live Console Ready\n", now];
            [_logBuffer appendFormat:@"[%@] [SYS] Hệ thống giám sát thời gian thực gắn kết thành công\n", now];
        }
    }
    return self;
}

- (NSString *)activeLogPath {
    NSString *dir = @"/var/mobile/Library/Application Support/StoreSwitcher";
    if ([[NSFileManager defaultManager] fileExistsAtPath:dir] ||
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @0755} error:nil]) {
        return LOG_FILE_PATH;
    }
    return FALLBACK_LOG_PATH;
}

- (void)appendLog:(NSString *)message {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    [fmt setDateFormat:@"HH:mm:ss"];
    NSString *timestamp = [fmt stringFromDate:[NSDate date]];
    
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.logBuffer appendString:line];
        
        // Giới hạn buffer tối đa 100 dòng trong RAM
        NSArray *lines = [self.logBuffer componentsSeparatedByString:@"\n"];
        if (lines.count > 100) {
            NSArray *tail = [lines subarrayWithRange:NSMakeRange(lines.count - 80, 80)];
            self.logBuffer = [NSMutableString stringWithString:[tail componentsJoinedByString:@"\n"]];
        }
        
        if (self.textView) {
            self.textView.text = self.logBuffer;
            [self.textView scrollRangeToVisible:NSMakeRange(self.textView.text.length, 0)];
        }
        
        // Ghi xuống file thật
        dispatch_async(dispatch_queue_create("com.storeswitcher.logwriter", DISPATCH_QUEUE_SERIAL), ^{
            NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:[self activeLogPath]];
            if (!fh) {
                [[NSFileManager defaultManager] createFileAtPath:[self activeLogPath] contents:nil attributes:nil];
                fh = [NSFileHandle fileHandleForWritingAtPath:[self activeLogPath]];
            }
            [fh seekToEndOfFile];
            [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        });
    });
}

+ (void)log:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    [[SSTerminalConsole shared] appendLog:msg];
}

+ (void)logAction:(NSString *)action status:(NSString *)status details:(NSString *)details {
    NSString *formatted = [NSString stringWithFormat:@"[%@] %@ -> %@", status ?: @"INFO", action ?: @"Action", details ?: @""];
    [[SSTerminalConsole shared] appendLog:formatted];
}

+ (void)clear {
    SSTerminalConsole *c = [SSTerminalConsole shared];
    dispatch_async(dispatch_get_main_queue(), ^{
        c.logBuffer = [NSMutableString string];
        [@"" writeToFile:[c activeLogPath] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        if (c.textView) {
            c.textView.text = @">_ Terminal đã xoá lịch sử. Đang chờ tác vụ mới...\n";
        }
    });
}

+ (NSString *)allLogs {
    return [SSTerminalConsole shared].logBuffer;
}

+ (CGFloat)currentConsoleHeight {
    SSTerminalConsole *c = [SSTerminalConsole shared];
    return c.isExpanded ? 150.0 : 34.0;
}

- (void)setupDockedViewInHostView:(UIView *)hostView {
    if (!hostView) return;

    if (self.dockedView && self.dockedView.superview == hostView) {
        [self updateViewLayoutInHostView:hostView];
        [hostView bringSubviewToFront:self.dockedView];
        return;
    }
    
    [self.dockedView removeFromSuperview];
    
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
    CGFloat w = hostView.bounds.size.width > 0 ? hostView.bounds.size.width : screenW;
    CGFloat hostH = hostView.bounds.size.height > 0 ? hostView.bounds.size.height : screenH;
    CGFloat h = self.isExpanded ? 165.0 : 34.0;
    CGFloat y = hostH - h;
    
    self.dockedView = [[UIView alloc] initWithFrame:CGRectMake(0, y, w, h)];
    self.dockedView.backgroundColor = [UIColor colorWithRed:0.04 green:0.06 blue:0.09 alpha:0.96]; // Dark terminal
    self.dockedView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.dockedView.layer.borderWidth = 1.0;
    self.dockedView.layer.borderColor = [UIColor colorWithRed:0.0 green:0.9 blue:0.46 alpha:0.6].CGColor; // Neon green border
    self.dockedView.layer.cornerRadius = 8.0;
    self.dockedView.clipsToBounds = YES;
    self.dockedView.layer.zPosition = 9999.0;
    self.dockedView.userInteractionEnabled = YES;
    
    // 1. Header Toolbar (Height 32 pt)
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, 32)];
    header.backgroundColor = [UIColor colorWithRed:0.08 green:0.12 blue:0.18 alpha:1.0];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.dockedView addSubview:header];
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, w - 170, 32)];
    self.titleLabel.text = @">_ Live Terminal Console";
    self.titleLabel.textColor = [UIColor colorWithRed:0.0 green:0.95 blue:0.5 alpha:1.0];
    self.titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:11.0] ?: [UIFont boldSystemFontOfSize:11.0];
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [header addSubview:self.titleLabel];
    
    // Nút Clear
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    clearBtn.frame = CGRectMake(w - 160, 2, 45, 28);
    [clearBtn setTitle:@"Xoá" forState:UIControlStateNormal];
    [clearBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.45 blue:0.45 alpha:1.0] forState:UIControlStateNormal];
    clearBtn.titleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    clearBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [clearBtn addTarget:self action:@selector(clearTapped) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:clearBtn];
    
    // Nút Copy
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    copyBtn.frame = CGRectMake(w - 110, 2, 45, 28);
    [copyBtn setTitle:@"Copy" forState:UIControlStateNormal];
    [copyBtn setTitleColor:[UIColor colorWithRed:0.4 green:0.75 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    copyBtn.titleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
    copyBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [copyBtn addTarget:self action:@selector(copyTapped) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:copyBtn];
    
    // Nút Toggle Thu nhỏ / Mở rộng
    self.toggleBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.toggleBtn.frame = CGRectMake(w - 60, 2, 52, 28);
    [self.toggleBtn setTitle:self.isExpanded ? @"▼ Đóng" : @"▲ Mở" forState:UIControlStateNormal];
    [self.toggleBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.toggleBtn.titleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    self.toggleBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.toggleBtn addTarget:self action:@selector(toggleExpandedTapped) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:self.toggleBtn];
    
    // 2. Body Text View (Terminal display)
    self.textView = [[UITextView alloc] initWithFrame:CGRectMake(4, 34, w - 8, h - 36)];
    self.textView.backgroundColor = [UIColor clearColor];
    self.textView.textColor = [UIColor colorWithRed:0.85 green:0.92 blue:0.95 alpha:1.0];
    self.textView.font = [UIFont fontWithName:@"Menlo" size:10.0] ?: [UIFont systemFontOfSize:10.0];
    self.textView.editable = NO;
    self.textView.selectable = YES;
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.text = self.logBuffer;
    self.textView.hidden = !self.isExpanded;
    [self.dockedView addSubview:self.textView];
    
    [hostView addSubview:self.dockedView];
    [hostView bringSubviewToFront:self.dockedView];
    
    [self adjustTableInsetForVC:self.currentVC];
    [self.textView scrollRangeToVisible:NSMakeRange(self.textView.text.length, 0)];
}

- (void)adjustTableInsetForVC:(UIViewController *)vc {
    if (!vc) return;
    if ([vc respondsToSelector:@selector(table)]) {
        UITableView *tbl = (UITableView *)[vc performSelector:@selector(table)];
        if ([tbl isKindOfClass:[UITableView class]]) {
            CGFloat bottomInset = self.isExpanded ? 170.0 : 38.0;
            tbl.contentInset = UIEdgeInsetsMake(0, 0, bottomInset, 0);
            tbl.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, bottomInset, 0);
        }
    }
}

- (void)updateViewLayoutInHostView:(UIView *)hostView {
    if (!self.dockedView || !hostView) return;
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
    CGFloat w = hostView.bounds.size.width > 0 ? hostView.bounds.size.width : screenW;
    CGFloat hostH = hostView.bounds.size.height > 0 ? hostView.bounds.size.height : screenH;
    CGFloat h = self.isExpanded ? 165.0 : 34.0;
    CGFloat y = hostH - h;
    self.dockedView.frame = CGRectMake(0, y, w, h);
    self.dockedView.layer.zPosition = 9999.0;
    [self.toggleBtn setTitle:self.isExpanded ? @"▼ Đóng" : @"▲ Mở" forState:UIControlStateNormal];
    self.textView.hidden = !self.isExpanded;
    [hostView bringSubviewToFront:self.dockedView];
    [self adjustTableInsetForVC:self.currentVC];
}

- (void)clearTapped {
    [SSTerminalConsole clear];
}

- (void)copyTapped {
    [UIPasteboard generalPasteboard].string = self.logBuffer;
    [self appendLog:@"[CLIPBOARD] Đã sao chép toàn bộ nhật ký vào bộ nhớ tạm!"];
}

- (void)toggleExpandedTapped {
    [self toggleExpanded];
}

- (void)toggleExpanded {
    self.isExpanded = !self.isExpanded;
    UIView *hostView = self.dockedView.superview;
    if (hostView) {
        [UIView animateWithDuration:0.25 animations:^{
            [self updateViewLayoutInHostView:hostView];
        }];
    }
}

+ (void)toggleExpanded {
    [[SSTerminalConsole shared] toggleExpanded];
}

+ (instancetype)sharedConsole {
    return [self shared];
}

+ (void)clearLogs {
    [self clear];
}

- (void)clear {
    [SSTerminalConsole clear];
}

- (void)clearLogs {
    [SSTerminalConsole clear];
}

- (void)attachToViewController:(UIViewController *)vc {
    [SSTerminalConsole attachToViewController:vc];
}

+ (void)updateLayoutForViewController:(UIViewController *)vc {
    if (!vc || !vc.view) return;
    UIView *hostView = vc.navigationController.view ?: vc.view;
    [[SSTerminalConsole shared] updateViewLayoutInHostView:hostView];
}

- (void)updateLayoutForViewController:(UIViewController *)vc {
    [SSTerminalConsole updateLayoutForViewController:vc];
}

+ (void)attachToViewController:(UIViewController *)vc {
    if (!vc) return;
    
    SSTerminalConsole *c = [SSTerminalConsole shared];
    c.currentVC = vc;
    
    UIView *hostView = vc.navigationController.view ?: vc.view;
    if (hostView) {
        [c setupDockedViewInHostView:hostView];
    }
}

+ (void)showInViewController:(UIViewController *)vc {
    [self attachToViewController:vc];
}

@end
