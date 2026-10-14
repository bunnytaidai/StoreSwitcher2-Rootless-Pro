#import "SSPrefsRootListController.h"
#import "SSContainersListController.h"
#import "SSInjectedAppsController.h"
#import "SSAutoRunnerController.h"
#import "SSPacketReplayerController.h"

// Controller xem log toàn màn hình phong cách Terminal Console
@interface SSLiveLogConsoleController : UIViewController
@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) NSTimer *refreshTimer;
@end

@implementation SSLiveLogConsoleController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"📜 Live Activity Log Console";
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:1.0];

    self.textView = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.textView.backgroundColor = [UIColor clearColor];
    self.textView.textColor = [UIColor colorWithRed:0.35 green:0.95 blue:0.55 alpha:1.0]; // Terminal green
    self.textView.font = [UIFont fontWithName:@"Menlo" size:11.0] ?: [UIFont systemFontOfSize:11.0];
    self.textView.editable = NO;
    [self.view addSubview:self.textView];

    UIBarButtonItem *refreshBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadLogContent)];
    UIBarButtonItem *clearBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(clearLog)];
    self.navigationItem.rightBarButtonItems = @[refreshBtn, clearBtn];

    [self reloadLogContent];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(reloadLogContent) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (NSString *)logFilePath {
    NSString *rootlessPath = @"/var/jb/var/mobile/Library/Application Support/StoreSwitcher/activity.log";
    if ([[NSFileManager defaultManager] fileExistsAtPath:rootlessPath]) {
        return rootlessPath;
    }
    return @"/var/mobile/Library/Application Support/StoreSwitcher/activity.log";
}

- (void)reloadLogContent {
    NSString *path = [self logFilePath];
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (!content || content.length == 0) {
        content = [NSString stringWithFormat:@"[STORESWITCHER PRO 2.4.0 LOG CONSOLE]\n\n[INFO] Khởi động hệ thống giám sát thời gian thực...\n[INFO] Tweak StoreSwitcher2 đang chạy nền.\n[OK] Đã gắn kết 5 Tab điều khiển: Vùng chứa, AppAgent, DevRunner, Replayer, Console.\n[LOG] Chưa có thêm lỗi hoặc hành động mới.\n(File log: %@)\n", path];
    }
    self.textView.text = content;
    [self.textView scrollRangeToVisible:NSMakeRange(self.textView.text.length, 0)];
}

- (void)clearLog {
    NSString *path = [self logFilePath];
    [@"" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self reloadLogContent];
}

@end

// Root List Controller
@interface SSPrefsRootListController ()
@property (nonatomic, assign) BOOL logDrawerExpanded;
@end

@implementation SSPrefsRootListController

- (id)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *path = @"/var/mobile/Library/Preferences/com.subdiox.storeswitcher.plist";
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:path];
    return settings[[specifier propertyForKey:@"key"]] ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *path = @"/var/mobile/Library/Preferences/com.subdiox.storeswitcher.plist";
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
    [settings setObject:value forKey:[specifier propertyForKey:@"key"]];
    [settings writeToFile:path atomically:YES];
}

- (id)versionString {
    return @"2.4.0 (5-Tab Pro Edition)";
}

#pragma mark - Actions for the 4 Tabs

- (void)openContainersList:(PSSpecifier *)specifier {
    SSContainersListController *vc = [[SSContainersListController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openInjectedApps:(PSSpecifier *)specifier {
    SSInjectedAppsController *vc = [[SSInjectedAppsController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openAutoRunner:(PSSpecifier *)specifier {
    SSAutoRunnerController *vc = [[SSAutoRunnerController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openPacketReplayer:(PSSpecifier *)specifier {
    SSPacketReplayerController *vc = [[SSPacketReplayerController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Tab 5: Live Activity Log Drawer Actions

- (NSString *)logFilePath {
    NSString *rootlessPath = @"/var/jb/var/mobile/Library/Application Support/StoreSwitcher/activity.log";
    if ([[NSFileManager defaultManager] fileExistsAtPath:rootlessPath]) {
        return rootlessPath;
    }
    return @"/var/mobile/Library/Application Support/StoreSwitcher/activity.log";
}

- (void)toggleLogDrawer:(PSSpecifier *)specifier {
    self.logDrawerExpanded = !self.logDrawerExpanded;
    
    NSString *path = [self logFilePath];
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if (!content || content.length == 0) {
        content = @"[OK] Hệ thống đang chạy ổn định. Chưa ghi nhận lỗi runtime.";
    } else {
        // Lấy 10 dòng cuối cùng
        NSArray *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        NSInteger start = MAX(0, (NSInteger)lines.count - 10);
        NSArray *lastLines = [lines subarrayWithRange:NSMakeRange(start, lines.count - start)];
        content = [lastLines componentsJoinedByString:@"\n"];
    }

    NSString *title = self.logDrawerExpanded ? @"📜 NHẬT KÝ ĐANG MỞ RỘNG" : @"📜 NHẬT KÝ ĐÃ THU GỌN";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:content
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Mở Toàn Màn Hình" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self openLiveLogViewer:nil];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openLiveLogViewer:(PSSpecifier *)specifier {
    SSLiveLogConsoleController *console = [[SSLiveLogConsoleController alloc] init];
    [self.navigationController pushViewController:console animated:YES];
}

- (void)clearLogFile:(PSSpecifier *)specifier {
    NSString *path = [self logFilePath];
    [@"" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đã Xóa Log"
                                                                   message:@"Toàn bộ lịch sử nhật ký hoạt động đã được làm sạch."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
