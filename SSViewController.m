#import "SSViewController.h"

@implementation SSViewController

@synthesize tableViewController;
@synthesize accounts;

- (UINavigationController *)init {
  UITableViewStyle tableStyle = UITableViewStyleGrouped;
  if (@available(iOS 13.0, *)) {
    tableStyle = UITableViewStyleInsetGrouped;
  }
  
  UITableViewController *contentViewController = [[UITableViewController alloc] initWithStyle:tableStyle];
  SSViewController *viewController = [super initWithRootViewController:contentViewController];
  [viewController setTableViewController:contentViewController];
  
  UITableView *tableView = [contentViewController tableView];
  [tableView setDelegate:viewController];
  [tableView setDataSource:viewController];
  [tableView registerClass:[SSTableViewCell class] forCellReuseIdentifier:@"SSTableViewCell"];
  
  return viewController;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [[self tableViewController] setTitle:@"StoreSwitcher 2"];
  
  UIBarButtonItem *dismissButton =
    [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
      target:self
      action:@selector(dismissAnimated)
    ];
  [[[self tableViewController] navigationItem] setLeftBarButtonItem:dismissButton];
  [[[self tableViewController] navigationItem] setRightBarButtonItem:[[self tableViewController] editButtonItem]];
  
  // Nạp Header hiển thị Nick Apple ID đang đăng nhập hiện tại trên máy
  [[self tableViewController] tableView].tableHeaderView = [self createCurrentAccountHeaderView];
  
  [self reloadAccountsList];
}

#pragma mark - Thông tin Nick Apple ID đang đăng nhập trên thiết bị

- (UIView *)createCurrentAccountHeaderView {
  SSAccount *curAcc = [[SSSoftSwapManager sharedManager] currentDeviceAccount];
  if (!curAcc) return nil;
  
  UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 375, 138)];
  header.backgroundColor = [UIColor clearColor];
  
  UIView *card = [[UIView alloc] initWithFrame:CGRectMake(16, 6, 343, 126)];
  if (@available(iOS 13.0, *)) {
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
  } else {
    card.backgroundColor = [UIColor whiteColor];
  }
  card.layer.cornerRadius = 14;
  card.layer.masksToBounds = YES;
  
  // Tiêu đề nhỏ
  UILabel *tagLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, 240, 16)];
  tagLabel.text = @"● TÀI KHOẢN ĐANG ĐĂNG NHẬP HIỆN HỮU:";
  tagLabel.font = [UIFont boldSystemFontOfSize:11];
  tagLabel.textColor = [UIColor systemBlueColor];
  [card addSubview:tagLabel];
  
  // Tên / Email
  UILabel *emailLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 28, 310, 20)];
  emailLabel.text = [curAcc accountName] ?: @"Chưa đăng nhập";
  emailLabel.font = [UIFont boldSystemFontOfSize:15];
  if (@available(iOS 13.0, *)) {
    emailLabel.textColor = [UIColor labelColor];
  }
  [card addSubview:emailLabel];
  
  // Thông tin phụ: DSID + Quốc gia + Token status
  UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 50, 310, 18)];
  NSString *dsidStr = [curAcc uniqueIdentifier] ? [NSString stringWithFormat:@"DSID: %@", [curAcc uniqueIdentifier]] : @"";
  subLabel.text = [NSString stringWithFormat:@"%@ • %@ • Zero-Disk Token", [self countryCodeForAccount:curAcc], dsidStr];
  subLabel.font = [UIFont systemFontOfSize:12];
  subLabel.textColor = [UIColor grayColor];
  [card addSubview:subLabel];
  
  // NÚT BẤM TO: "⚡ SNAPSHOT & LƯU NHANH VÀO VAULT (1-CLICK)"
  UIButton *snapshotBtn = [UIButton buttonWithType:UIButtonTypeCustom];
  snapshotBtn.frame = CGRectMake(14, 76, 315, 36)];
  snapshotBtn.backgroundColor = [UIColor colorWithRed:0.55 green:0.25 blue:0.95 alpha:1.0];
  snapshotBtn.layer.cornerRadius = 8;
  snapshotBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
  [snapshotBtn setTitle:@"⚡ Snapshot & Lưu Nhanh Nick Này Vào Vault" forState:UIControlStateNormal];
  [snapshotBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  [snapshotBtn addTarget:self action:@selector(snapshotCurrentAccountTapped:) forControlEvents:UIControlEventTouchUpInside];
  [card addSubview:snapshotBtn];
  
  [header addSubview:card];
  return header;
}

- (void)snapshotCurrentAccountTapped:(UIButton *)sender {
  SSAccount *curAcc = [[SSSoftSwapManager sharedManager] currentDeviceAccount];
  if (!curAcc) return;
  
  NSString *email = [curAcc accountName];
  NSString *existingPass = [[SSSoftSwapManager sharedManager] passwordForAccount:email] ?: @"";
  
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚡ Snapshot Nick Vào Vault"
                                                                 message:[NSString stringWithFormat:@"Lập tức lưu toàn bộ Token, DSID, StoreFront của:\n%@\n\nNhập mật khẩu (để tự điền khi mua In-App):", email]
                                                          preferredStyle:UIAlertControllerStyleAlert];
                                                          
  [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
    textField.placeholder = @"Mật khẩu Apple ID (Tùy chọn)";
    textField.secureTextEntry = YES;
    if (existingPass.length > 0) {
      textField.text = existingPass;
    }
  }];
  
  [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:@"💾 Lưu Ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
    NSString *inputPass = alert.textFields.firstObject.text;
    NSDictionary *snap = [[SSSoftSwapManager sharedManager] captureCurrentDeviceAccountSnapshotAndSaveToVaultWithPassword:inputPass];
    if (snap) {
      [self reloadAccountsList];
      [[self tableViewController] tableView].tableHeaderView = [self createCurrentAccountHeaderView];
    }
  }]];
  
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)reloadAccountsList {
  NSMutableArray *allAccounts = [[[objc_getClass("SSAccountStore") defaultStore] accounts] mutableCopy];
  if (!allAccounts) {
    allAccounts = [NSMutableArray array];
  }
  
  NSIndexSet *localAccountIndexSet = [allAccounts indexesOfObjectsPassingTest:^BOOL(id object, NSUInteger index, BOOL *stop) {
    SSAccount *account = (SSAccount *)object;
    return [account isLocalAccount];
  }];
  [allAccounts removeObjectsAtIndexes:localAccountIndexSet];
  [self setAccounts:allAccounts];
  [[[self tableViewController] tableView] reloadData];
}

- (void)dismissAnimated {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSString *)countryCodeForAccount:(SSAccount *)account {
  NSString *frontIdentifier = [account storeFrontIdentifier];
  if (!frontIdentifier || [frontIdentifier length] == 0) {
    return @"Unknown";
  }
  NSString *internalCountryCode = [[[[frontIdentifier componentsSeparatedByString:@","] firstObject] componentsSeparatedByString:@"-"] firstObject];
  NSDictionary *countryDict = @{
    @"143563": @"Algeria (DZ)",
    @"143564": @"Angola (AO)",
    @"143538": @"Anguilla (AI)",
    @"143540": @"Antigua & Barbuda (AG)",
    @"143505": @"Argentina (AR)",
    @"143524": @"Armenia (AM)",
    @"143460": @"Australia (AU)",
    @"143445": @"Austria (AT)",
    @"143568": @"Azerbaijan (AZ)",
    @"143559": @"Bahrain (BH)",
    @"143490": @"Bangladesh (BD)",
    @"143541": @"Barbados (BB)",
    @"143565": @"Belarus (BY)",
    @"143446": @"Belgium (BE)",
    @"143555": @"Belize (BZ)",
    @"143542": @"Bermuda (BM)",
    @"143556": @"Bolivia (BO)",
    @"143525": @"Botswana (BW)",
    @"143503": @"Brazil (BR)",
    @"143543": @"British Virgin Islands (VG)",
    @"143560": @"Brunei (BN)",
    @"143526": @"Bulgaria (BG)",
    @"143455": @"Canada (CA)",
    @"143544": @"Cayman Islands (KY)",
    @"143483": @"Chile (CL)",
    @"143465": @"China (CN)",
    @"143501": @"Colombia (CO)",
    @"143495": @"Costa Rica (CR)",
    @"143527": @"Cote d'Ivoire (CI)",
    @"143494": @"Croatia (HR)",
    @"143557": @"Cyprus (CY)",
    @"143489": @"Czech Republic (CZ)",
    @"143458": @"Denmark (DK)",
    @"143545": @"Dominica (DM)",
    @"143508": @"Dominican Rep. (DO)",
    @"143509": @"Ecuador (EC)",
    @"143516": @"Egypt (EG)",
    @"143506": @"El Salvador (SV)",
    @"143518": @"Estonia (EE)",
    @"143447": @"Finland (FI)",
    @"143442": @"France (FR)",
    @"143443": @"Germany (DE)",
    @"143573": @"Ghana (GH)",
    @"143448": @"Greece (GR)",
    @"143546": @"Grenada (GD)",
    @"143504": @"Guatemala (GT)",
    @"143553": @"Guyana (GY)",
    @"143510": @"Honduras (HN)",
    @"143463": @"Hong Kong (HK)",
    @"143482": @"Hungary (HU)",
    @"143558": @"Iceland (IS)",
    @"143467": @"India (IN)",
    @"143476": @"Indonesia (ID)",
    @"143449": @"Ireland (IE)",
    @"143491": @"Israel (IL)",
    @"143450": @"Italy (IT)",
    @"143511": @"Jamaica (JM)",
    @"143462": @"Japan (JP)",
    @"143528": @"Jordan (JO)",
    @"143517": @"Kazakstan (KZ)",
    @"143529": @"Kenya (KE)",
    @"143466": @"Korea, Republic Of (KR)",
    @"143493": @"Kuwait (KW)",
    @"143519": @"Latvia (LV)",
    @"143497": @"Lebanon (LB)",
    @"143522": @"Liechtenstein (LI)",
    @"143520": @"Lithuania (LT)",
    @"143451": @"Luxembourg (LU)",
    @"143515": @"Macau (MO)",
    @"143530": @"Macedonia (MK)",
    @"143531": @"Madagascar (MG)",
    @"143473": @"Malaysia (MY)",
    @"143488": @"Maldives (MV)",
    @"143532": @"Mali (ML)",
    @"143521": @"Malta (MT)",
    @"143533": @"Mauritius (MU)",
    @"143468": @"Mexico (MX)",
    @"143523": @"Moldova, Republic Of (MD)",
    @"143547": @"Montserrat (MS)",
    @"143484": @"Nepal (NP)",
    @"143452": @"Netherlands (NL)",
    @"143461": @"New Zealand (NZ)",
    @"143512": @"Nicaragua (NI)",
    @"143534": @"Niger (NE)",
    @"143561": @"Nigeria (NG)",
    @"143457": @"Norway (NO)",
    @"143562": @"Oman (OM)",
    @"143477": @"Pakistan (PK)",
    @"143485": @"Panama (PA)",
    @"143513": @"Paraguay (PY)",
    @"143507": @"Peru (PE)",
    @"143474": @"Philippines (PH)",
    @"143478": @"Poland (PL)",
    @"143453": @"Portugal (PT)",
    @"143498": @"Qatar (QA)",
    @"143487": @"Romania (RO)",
    @"143469": @"Russia (RU)",
    @"143479": @"Saudi Arabia (SA)",
    @"143535": @"Senegal (SN)",
    @"143500": @"Serbia (RS)",
    @"143464": @"Singapore (SG)",
    @"143496": @"Slovakia (SK)",
    @"143499": @"Slovenia (SI)",
    @"143472": @"South Africa (ZA)",
    @"143454": @"Spain (ES)",
    @"143486": @"Sri Lanka (LK)",
    @"143548": @"St. Kitts & Nevis (KN)",
    @"143549": @"St. Lucia (LC)",
    @"143550": @"St. Vincent & The Grenadines (VC)",
    @"143554": @"Suriname (SR)",
    @"143456": @"Sweden (SE)",
    @"143459": @"Switzerland (CH)",
    @"143470": @"Taiwan (TW)",
    @"143572": @"Tanzania (TZ)",
    @"143475": @"Thailand (TH)",
    @"143539": @"The Bahamas (BS)",
    @"143551": @"Trinidad & Tobago (TT)",
    @"143536": @"Tunisia (TN)",
    @"143480": @"Turkey (TR)",
    @"143552": @"Turks & Caicos (TC)",
    @"143537": @"Uganda (UG)",
    @"143492": @"Ukraine (UA)",
    @"143481": @"United Arab Emirates (AE)",
    @"143444": @"United Kingdom (UK)",
    @"143441": @"United States (US)",
    @"143514": @"Uruguay (UY)",
    @"143566": @"Uzbekistan (UZ)",
    @"143502": @"Venezuela (VE)",
    @"143471": @"Vietnam (VN)",
    @"143571": @"Yemen (YE)"
  };
  NSString *countryCode = countryDict[internalCountryCode];
  if (!countryCode) {
    countryCode = [NSString stringWithFormat:@"Unknown [%@]", internalCountryCode];
  }
  return countryCode;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  return @"Danh sách tài khoản";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
  return @"💡 Chạm vào tài khoản để chuyển hẳn (Hard Swap).\n👈 Vuốt sang trái để chọn các nút URL Scheme / Sandbox đã cấu hình.";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [accounts count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *cellIdentifier = @"SSTableViewCell";
  SSTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
  SSAccount *account = accounts[indexPath.row];
  
  NSString *displayName = [account firstName] ? [NSString stringWithFormat:@"%@ %@", [account firstName], [account lastName]] : [account accountName];
  NSString *detailInfo = [NSString stringWithFormat:@"%@ • %@", [account accountName], [self countryCodeForAccount:account]];
  
  [[cell textLabel] setText:displayName];
  [[cell detailTextLabel] setText:detailInfo];
  
  BOOL isActive = [account isActive];
  BOOL isSoftSwapped = ([SSSoftSwapManager sharedManager].isSoftSwapping &&
                        [[[[SSSoftSwapManager sharedManager] softSwapAccount] accountName] isEqualToString:[account accountName]]);
  
  if (isSoftSwapped) {
    [cell setAccessoryType:UITableViewCellAccessoryDetailButton];
    cell.textLabel.textColor = [UIColor systemPurpleColor];
    [[cell detailTextLabel] setText:[NSString stringWithFormat:@"⚡ [Soft Swap Sandbox] • %@", detailInfo]];
  } else if (isActive) {
    [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    cell.textLabel.textColor = [UIColor systemBlueColor];
  } else {
    [cell setAccessoryType:UITableViewCellAccessoryNone];
    if (@available(iOS 13.0, *)) {
      cell.textLabel.textColor = [UIColor labelColor];
    } else {
      cell.textLabel.textColor = [UIColor blackColor];
    }
  }
  
  return cell;
}

// Chạm để đổi tài khoản thật (Hard Swap)
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  SSAccount *account = accounts[indexPath.row];
  
  if ([SSSoftSwapManager sharedManager].isSoftSwapping) {
    [[SSSoftSwapManager sharedManager] stopSoftSwap];
  }
  
  [account setActive:YES];
  [[objc_getClass("SSAccountStore") defaultStore] saveAccount:account verifyCredentials:NO error:nil];
  [[objc_getClass("SSDevice") currentDevice] reloadStoreFrontIdentifier];
  [[[objc_getClass("SKUIClientContext") defaultContext] applicationController] _resetUserInterfaceAfterStoreFrontChange];
  
  [self dismissAnimated];
}

#pragma mark - Vuốt sang trái (Swipe Actions Chuyên Sâu Cho Sandbox TestFlight & StoreKit 1/2)

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
  SSAccount *account = accounts[indexPath.row];
  NSMutableArray *actions = [NSMutableArray array];
  
  // 1. Nút chính StoreKit 2: "Quản lý Đăng ký (StoreKit 2)" - Mở thẳng Sheet Subscriptions
  UIContextualAction *sk2Action = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
    title:@"StoreKit 2\nĐăng ký"
    handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
      [[SSSoftSwapManager sharedManager] startSoftSwapWithAccount:account mode:SSSandboxOpenModeStoreKit2 completion:nil];
      [self dismissAnimated];
      completionHandler(YES);
    }];
  sk2Action.backgroundColor = [UIColor colorWithRed:0.55 green:0.25 blue:0.95 alpha:1.0]; // Tím neon
  if (@available(iOS 13.0, *)) {
    sk2Action.image = [UIImage systemImageNamed:@"cart.badge.plus"];
  }
  [actions addObject:sk2Action];
  
  // 2. Nút Cài đặt Sandbox: Mở App-prefs:STORE&path=SANDBOX_ACCOUNT (Mở thẳng mục Settings Sandbox)
  UIContextualAction *settingsAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
    title:@"Cài đặt\nSandbox"
    handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
      [[SSSoftSwapManager sharedManager] startSoftSwapWithAccount:account mode:SSSandboxOpenModeSettingsSandbox completion:nil];
      [self dismissAnimated];
      completionHandler(YES);
    }];
  settingsAction.backgroundColor = [UIColor colorWithRed:0.95 green:0.55 blue:0.10 alpha:1.0]; // Cam
  if (@available(iOS 13.0, *)) {
    settingsAction.image = [UIImage systemImageNamed:@"gearshape.2.fill"];
  }
  [actions addObject:settingsAction];
  
  // 3. Nút TestFlight WebObjects / Deep Link tùy chỉnh
  UIContextualAction *tfAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
    title:@"TestFlight\nDeep Link"
    handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
      [[SSSoftSwapManager sharedManager] startSoftSwapWithAccount:account mode:SSSandboxOpenModeTestFlight completion:nil];
      [self dismissAnimated];
      completionHandler(YES);
    }];
  tfAction.backgroundColor = [UIColor colorWithRed:0.15 green:0.55 blue:0.95 alpha:1.0]; // Xanh dương
  if (@available(iOS 13.0, *)) {
    tfAction.image = [UIImage systemImageNamed:@"bolt.horizontal.fill"];
  }
  [actions addObject:tfAction];
  
  // 4. Nút Xoá (nếu không active)
  if (![account isActive]) {
    UIContextualAction *deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
      title:@"Xoá"
      handler:^(UIContextualAction * _Nonnull action, __kindof UIView * _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [[objc_getClass("SSAccountStore") defaultStore] removeAccount:account error:nil];
        [self.accounts removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        completionHandler(YES);
      }];
    if (@available(iOS 13.0, *)) {
      deleteAction.image = [UIImage systemImageNamed:@"trash"];
    }
    [actions addObject:deleteAction];
  }
  
  UISwipeActionsConfiguration *config = [UISwipeActionsConfiguration configurationWithActions:actions];
  config.performsFirstActionWithFullSwipe = NO;
  return config;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
  SSAccount *account = accounts[indexPath.row];
  NSString *accName = [account accountName] ?: @"Apple ID";
  
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Tùy chọn Sandbox In-App"
                                                                 message:[NSString stringWithFormat:@"Chọn hành động StoreKit cho tài khoản:\n%@", accName]
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
                                                          
  [alert addAction:[UIAlertAction actionWithTitle:@"⚡ 1. Mở Quản lý Subscriptions (StoreKit 2)"
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction * _Nonnull action) {
    [[SSSoftSwapManager sharedManager] startSoftSwapWithAccount:account mode:SSSandboxOpenModeStoreKit2 completion:nil];
    [self dismissAnimated];
  }]];
  
  [alert addAction:[UIAlertAction actionWithTitle:@"📦 2. Mở Subscriptions Cổ điển (StoreKit 1)"
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction * _Nonnull action) {
    [[SSSoftSwapManager sharedManager] startSoftSwapWithAccount:account mode:SSSandboxOpenModeStoreKit1 completion:nil];
    [self dismissAnimated];
  }]];
  
  [alert addAction:[UIAlertAction actionWithTitle:@"⚙️ 3. Mở Cài đặt App Store Sandbox"
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction * _Nonnull action) {
    [[SSSoftSwapManager sharedManager] startSoftSwapWithAccount:account mode:SSSandboxOpenModeSettingsSandbox completion:nil];
    [self dismissAnimated];
  }]];
  
  [alert addAction:[UIAlertAction actionWithTitle:@"✈️ 4. Mở TestFlight Account Summary"
                                           style:UIAlertActionStyleDefault
                                         handler:^(UIAlertAction * _Nonnull action) {
    [[SSSoftSwapManager sharedManager] startSoftSwapWithAccount:account mode:SSSandboxOpenModeTestFlight completion:nil];
    [self dismissAnimated];
  }]];
  
  [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
  
  [self presentViewController:alert animated:YES completion:nil];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
  SSAccount *account = accounts[indexPath.row];
  if (tableView.editing && ![account isActive]) {
    return UITableViewCellEditingStyleDelete;
  }
  return UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  SSAccount *account = accounts[indexPath.row];
  if (![account isActive]) {
    [[objc_getClass("SSAccountStore") defaultStore] removeAccount:account error:nil];
    [accounts removeObjectAtIndex:indexPath.row];
    [tableView reloadData];
  }
}

@end