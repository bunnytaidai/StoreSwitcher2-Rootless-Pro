#import "SSAutoRunnerController.h"
#import "../SSContainerManager.h"

@interface SSAutoRunnerController ()
@property (nonatomic, strong) NSMutableDictionary *runnerSettings;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, strong) NSTimer *runnerTimer;
@property (nonatomic, assign) NSInteger currentAccountIndex;
@end

@implementation SSAutoRunnerController

- (void)loadSettings {
    NSString *path = @"/var/mobile/Library/Preferences/com.subdiox.storeswitcher.autorunner.plist";
    _runnerSettings = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
}

- (void)saveSettings {
    NSString *path = @"/var/mobile/Library/Preferences/com.subdiox.storeswitcher.autorunner.plist";
    [_runnerSettings writeToFile:path atomically:YES];
}

- (id)specifiers {
    if (!_specifiers) {
        [self loadSettings];
        NSMutableArray *specs = [NSMutableArray array];

        // Nhóm 1: Trạng thái & chế độ
        PSSpecifier *grp1 = [PSSpecifier groupSpecifierWithName:@"DEV RUNNER TỰ ĐỘNG XOAY VÒNG APPLE ID"];
        [grp1 setProperty:@"Hệ thống sẽ chạy ngầm, tự động đổi tuần tự qua từng Apple ID / Vùng chứa, thực hiện chuỗi hành động tùy biến rồi chuyển sang tài khoản kế tiếp." forKey:@"footerText"];
        [specs addObject:grp1];

        PSSpecifier *enableSwitch = [PSSpecifier preferenceSpecifierNamed:@"Kích Hoạt Tự Động Đổi Nick Xoay Vòng"
                                                                   target:self
                                                                      set:@selector(setPrefBool:specifier:)
                                                                      get:@selector(getPrefBool:)
                                                                   detail:Nil
                                                                     cell:PSSwitchCell
                                                                     edit:Nil];
        [enableSwitch setProperty:@"loopEnabled" forKey:@"key"];
        [enableSwitch setProperty:@NO forKey:@"default"];
        [specs addObject:enableSwitch];

        PSSpecifier *bgSwitch = [PSSpecifier preferenceSpecifierNamed:@"Chạy Ngầm Liên Tục Khi Khóa Màn Hình"
                                                               target:self
                                                                  set:@selector(setPrefBool:specifier:)
                                                                  get:@selector(getPrefBool:)
                                                               detail:Nil
                                                                 cell:PSSwitchCell
                                                                 edit:Nil];
        [bgSwitch setProperty:@"runInBackground" forKey:@"key"];
        [bgSwitch setProperty:@YES forKey:@"default"];
        [specs addObject:bgSwitch];

        // Nhóm 2: Thiết lập thời gian & chu kỳ
        PSSpecifier *grp2 = [PSSpecifier groupSpecifierWithName:@"THIẾT LẬP THỜI GIAN & CHU KỲ"];
        [specs addObject:grp2];

        PSSpecifier *delaySpec = [PSSpecifier preferenceSpecifierNamed:@"Thời Gian Chờ Sau Mỗi Lần Đổi (Giây)"
                                                                target:self
                                                                   set:@selector(setPrefValue:specifier:)
                                                                   get:@selector(getPrefValue:)
                                                                detail:Nil
                                                                  cell:PSEditTextCell
                                                                  edit:Nil];
        [delaySpec setProperty:@"delaySeconds" forKey:@"key"];
        [delaySpec setProperty:@"15" forKey:@"placeholder"];
        [specs addObject:delaySpec];

        PSSpecifier *loopsSpec = [PSSpecifier preferenceSpecifierNamed:@"Số Vòng Lặp Tối Đa (0 = Vô Hạn)"
                                                                target:self
                                                                   set:@selector(setPrefValue:specifier:)
                                                                   get:@selector(getPrefValue:)
                                                                detail:Nil
                                                                  cell:PSEditTextCell
                                                                  edit:Nil];
        [loopsSpec setProperty:@"maxLoops" forKey:@"key"];
        [loopsSpec setProperty:@"0" forKey:@"placeholder"];
        [specs addObject:loopsSpec];

        // Nhóm 3: Chuỗi hành động tùy cấu hình
        PSSpecifier *grp3 = [PSSpecifier groupSpecifierWithName:@"CHUỖI HÀNH ĐỘNG TÙY CẤU HÌNH (PIPELINE)"];
        [grp3 setProperty:@"Chọn các bước tweak sẽ tự động thi hành sau mỗi lần chuyển sang một Apple ID mới." forKey:@"footerText"];
        [specs addObject:grp3];

        PSSpecifier *killSpec = [PSSpecifier preferenceSpecifierNamed:@"1. Tắt Sạch Daemons (akd, itunesstored)"
                                                               target:self
                                                                  set:@selector(setPrefBool:specifier:)
                                                                  get:@selector(getPrefBool:)
                                                               detail:Nil
                                                                 cell:PSSwitchCell
                                                                 edit:Nil];
        [killSpec setProperty:@"killDaemons" forKey:@"key"];
        [killSpec setProperty:@YES forKey:@"default"];
        [specs addObject:killSpec];

        PSSpecifier *wipeSpec = [PSSpecifier preferenceSpecifierNamed:@"2. Xóa Sạch Cookie & Temp Tokens"
                                                               target:self
                                                                  set:@selector(setPrefBool:specifier:)
                                                                  get:@selector(getPrefBool:)
                                                               detail:Nil
                                                                 cell:PSSwitchCell
                                                                 edit:Nil];
        [wipeSpec setProperty:@"wipeCaches" forKey:@"key"];
        [wipeSpec setProperty:@YES forKey:@"default"];
        [specs addObject:wipeSpec];

        PSSpecifier *launchSpec = [PSSpecifier preferenceSpecifierNamed:@"3. Tự Động Mở App Mục Tiêu"
                                                                 target:self
                                                                    set:@selector(setPrefBool:specifier:)
                                                                    get:@selector(getPrefBool:)
                                                                 detail:Nil
                                                                   cell:PSSwitchCell
                                                                   edit:Nil];
        [launchSpec setProperty:@"launchTargetApp" forKey:@"key"];
        [launchSpec setProperty:@YES forKey:@"default"];
        [specs addObject:launchSpec];

        PSSpecifier *targetAppSpec = [PSSpecifier preferenceSpecifierNamed:@"Bundle ID App Cần Mở Tự Động"
                                                                    target:self
                                                                       set:@selector(setPrefValue:specifier:)
                                                                       get:@selector(getPrefValue:)
                                                                    detail:Nil
                                                                      cell:PSEditTextCell
                                                                      edit:Nil];
        [targetAppSpec setProperty:@"targetBundleID" forKey:@"key"];
        [targetAppSpec setProperty:@"com.apple.AppStore" forKey:@"placeholder"];
        [specs addObject:targetAppSpec];

        PSSpecifier *agentSpec = [PSSpecifier preferenceSpecifierNamed:@"4. Chạy Code Tương Tác Của AppAgent"
                                                                target:self
                                                                   set:@selector(setPrefBool:specifier:)
                                                                   get:@selector(getPrefBool:)
                                                                detail:Nil
                                                                  cell:PSSwitchCell
                                                                  edit:Nil];
        [agentSpec setProperty:@"executeAppAgent" forKey:@"key"];
        [agentSpec setProperty:@YES forKey:@"default"];
        [specs addObject:agentSpec];

        PSSpecifier *waitSpec = [PSSpecifier preferenceSpecifierNamed:@"5. Chờ Hoàn Tất Rồi Đổi Nick Tiếp Theo"
                                                               target:self
                                                                  set:@selector(setPrefBool:specifier:)
                                                                  get:@selector(getPrefBool:)
                                                               detail:Nil
                                                                 cell:PSSwitchCell
                                                                 edit:Nil];
        [waitSpec setProperty:@"waitSuccess" forKey:@"key"];
        [waitSpec setProperty:@YES forKey:@"default"];
        [specs addObject:waitSpec];

        // Nhóm 4: Thống kê & Điều khiển
        PSSpecifier *grp4 = [PSSpecifier groupSpecifierWithName:@"TIẾN TRÌNH & ĐIỀU KHIỂN"];
        [specs addObject:grp4];

        PSSpecifier *countSpec = [PSSpecifier preferenceSpecifierNamed:@"Tổng Số Apple ID Đang Quản Lý"
                                                                target:self
                                                                   set:NULL
                                                                   get:@selector(getTotalAccountsCount:)
                                                                detail:Nil
                                                                  cell:PSTitleValueCell
                                                                  edit:Nil];
        [specs addObject:countSpec];

        PSSpecifier *statSpec = [PSSpecifier preferenceSpecifierNamed:@"Trạng Thái Hiện Tại"
                                                               target:self
                                                                  set:NULL
                                                                  get:@selector(getCurrentStatus:)
                                                               detail:Nil
                                                                 cell:PSTitleValueCell
                                                                 edit:Nil];
        [specs addObject:statSpec];

        PSSpecifier *startBtn = [PSSpecifier preferenceSpecifierNamed:@"▶ BẮT ĐẦU CHẠY CHU TRÌNH NGAY"
                                                               target:self
                                                                  set:NULL
                                                                  get:NULL
                                                               detail:Nil
                                                                 cell:PSButtonCell
                                                                 edit:Nil];
        [startBtn setButtonAction:@selector(startAutoRunnerAction:)];
        [specs addObject:startBtn];

        PSSpecifier *stopBtn = [PSSpecifier preferenceSpecifierNamed:@"⏹ DỪNG CHU TRÌNH DEV RUNNER"
                                                              target:self
                                                                 set:NULL
                                                                 get:NULL
                                                              detail:Nil
                                                                cell:PSButtonCell
                                                                edit:Nil];
        [stopBtn setButtonAction:@selector(stopAutoRunnerAction:)];
        [specs addObject:stopBtn];

        _specifiers = specs;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = @"⚡ Dev Auto Runner";
    [self reloadSpecifiers];
}

#pragma mark - Getters / Setters

- (id)getPrefBool:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    NSNumber *val = self.runnerSettings[key];
    return val ?: [specifier propertyForKey:@"default"];
}

- (void)setPrefBool:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    [self.runnerSettings setObject:value forKey:key];
    [self saveSettings];
}

- (id)getPrefValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    return self.runnerSettings[key] ?: [specifier propertyForKey:@"placeholder"];
}

- (void)setPrefValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    [self.runnerSettings setObject:value forKey:key];
    [self saveSettings];
}

- (id)getTotalAccountsCount:(PSSpecifier *)specifier {
    NSUInteger c = [[SSContainerManager sharedManager].containers count];
    return [NSString stringWithFormat:@"%lu Tài khoản", (unsigned long)c];
}

- (id)getCurrentStatus:(PSSpecifier *)specifier {
    if (self.isRunning) {
        return [NSString stringWithFormat:@"Đang chạy (Nick #%ld)", (long)self.currentAccountIndex + 1];
    }
    return @"Sẵn sàng (Đang dừng)";
}

#pragma mark - Runner Actions

- (void)startAutoRunnerAction:(PSSpecifier *)specifier {
    NSArray *containers = [SSContainerManager sharedManager].containers;
    if (containers.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chưa Có Tài Khoản"
                                                                       message:@"Hãy tạo các vùng chứa ảo trước khi bắt đầu vòng lặp xoay vòng."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    self.isRunning = YES;
    self.currentAccountIndex = 0;
    [self reloadSpecifiers];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Khởi Động Dev Runner"
                                                                   message:@"Chu trình tự động xoay vòng tài khoản đã bắt đầu chạy ngầm."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Bắt Đầu" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self executeStep];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)executeStep {
    if (!self.isRunning) return;

    NSArray *containers = [SSContainerManager sharedManager].containers;
    if (self.currentAccountIndex >= containers.count) {
        self.currentAccountIndex = 0;
    }

    SSContainer *c = containers[self.currentAccountIndex];
    [[SSContainerManager sharedManager] switchToContainer:c error:nil];

    self.currentAccountIndex++;
    [self reloadSpecifiers];

    NSInteger delay = [self.runnerSettings[@"delaySeconds"] integerValue] ?: 15;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.isRunning) {
            [self executeStep];
        }
    });
}

- (void)stopAutoRunnerAction:(PSSpecifier *)specifier {
    self.isRunning = NO;
    [self.runnerTimer invalidate];
    self.runnerTimer = nil;
    [self reloadSpecifiers];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đã Dừng Chu Trình"
                                                                   message:@"Chu trình tự động xoay vòng tài khoản đã kết thúc."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
