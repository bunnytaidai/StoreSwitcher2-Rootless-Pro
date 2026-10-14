#import "SSViewController.h"
#import "SSContainerManager.h"
#import "AppAgentDashboardController.h"

@implementation SSViewController
@synthesize tableViewController = _tableViewController;
@synthesize accounts = _accounts;

- (UINavigationController *)init {
  UITableViewController *contentViewController = [[UITableViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
  SSViewController *viewController = [super initWithRootViewController:contentViewController];
  [viewController setTableViewController:contentViewController];
  [[contentViewController tableView] setDelegate:viewController];
  [[contentViewController tableView] setDataSource:viewController];
  [[contentViewController tableView] registerClass:[SSTableViewCell class] forCellReuseIdentifier:@"SSTableViewCell"];
  
  return viewController;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/StoreServices.framework"] load];
  [[self tableViewController] setTitle:@"StoreSwitcher Pro"];
  
  UIBarButtonItem *dismissButton =
    [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
      target:self
      action:@selector(dismissAnimated)
    ];
  
  UIBarButtonItem *agentButton =
    [[UIBarButtonItem alloc]
      initWithTitle:@"⚡ Agent"
      style:UIBarButtonItemStylePlain
      target:self
      action:@selector(openAppAgentDashboard)
    ];

  UIBarButtonItem *addAccountBtn =
    [[UIBarButtonItem alloc]
      initWithTitle:@"➕ Thêm Nick"
      style:UIBarButtonItemStyleDone
      target:self
      action:@selector(promptAddNewAppleID)
    ];

  [[[self tableViewController] navigationItem] setLeftBarButtonItems:@[dismissButton, agentButton]];
  [[[self tableViewController] navigationItem] setRightBarButtonItems:@[addAccountBtn]];

  [self reloadAllData];
}

- (void)reloadAllData {
  [[SSContainerManager sharedManager] loadSettings];
  [[SSContainerManager sharedManager] syncAccountsFromSystem];

  // Đồng bộ accounts từ SSAccountStore
  Class storeClass = objc_getClass("SSAccountStore");
  if (storeClass) {
    SSAccountStore *store = [storeClass defaultStore];
    NSMutableArray *allAccounts = [[store accounts] mutableCopy];
    NSIndexSet *localAccountIndexSet = [allAccounts indexesOfObjectsPassingTest:^BOOL(id object, NSUInteger index, BOOL *stop) {
      SSAccount *account = (SSAccount *)object;
      return [account isLocalAccount];
    }];
    [allAccounts removeObjectsAtIndexes:localAccountIndexSet];
    [self setAccounts:allAccounts];
  }

  [[[self tableViewController] tableView] reloadData];
}

- (void)dismissAnimated {
  [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 4;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  if (section == 0) {
    return @"⭐ TÀI KHOẢN ĐANG HOẠT ĐỘNG (ACTIVE)";
  } else if (section == 1) {
    return @"➕ THÊM TÀI KHOẢN MỚI (KHÔNG MẤT NICK CŨ)";
  } else if (section == 2) {
    return @"👥 DANH SÁCH TÀI KHOẢN APPLE ID ĐÃ LƯU (ĐỔI 1 CHẠM)";
  } else {
    return @"📦 VÙNG CHỨA ẢO (CRANE CONTAINERS)";
  }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
  if (section == 0) {
    NSString *activeID = [SSContainerManager sharedManager].activeAppleID;
    if (activeID.length > 0) {
      return [NSString stringWithFormat:@"Đang kích hoạt: %@. Mọi giao dịch In-App và tải app sẽ gắn liền với nick này.", activeID];
    }
    return @"Chưa có tài khoản Apple ID nào đăng nhập trên thiết bị.";
  } else if (section == 1) {
    return @"Bấm nút bên trên để lưu nick hiện tại và đăng nhập thêm nick mới mà KHÔNG bị đăng xuất, không làm mất token.";
  } else if (section == 2) {
    return @"Chạm vào bất kỳ tài khoản nào để chuyển đổi ngay lập tức (không bắt nhập OTP, 2FA hay mật khẩu). Vuốt sang trái để xóa khỏi danh sách.";
  } else {
    return @"Quản lý cô lập dữ liệu theo từng vùng chứa. Chuyển vùng chứa sẽ tự động liên kết với Apple ID tương ứng.";
  }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 0) {
    return 1;
  } else if (section == 1) {
    return 1; // Nút thêm tài khoản
  } else if (section == 2) {
    NSArray *vault = [SSContainerManager sharedManager].savedAccounts;
    return vault.count > 0 ? vault.count : 1;
  } else {
    return [[SSContainerManager sharedManager].containers count] + 1; // +1 cho nút Tạo vùng chứa mới
  }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *cellIdentifier = @"SSTableViewCell";
  SSTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
  cell.accessoryType = UITableViewCellAccessoryNone;

  if (indexPath.section == 0) {
    // Tài khoản đang hoạt động
    NSString *activeID = [SSContainerManager sharedManager].activeAppleID;
    if (activeID.length > 0) {
      [[cell textLabel] setText:activeID];
      SSContainer *activeC = [[SSContainerManager sharedManager] activeContainer];
      NSString *sub = [NSString stringWithFormat:@"Vùng chứa: %@ • DSID: %@", activeC.name, activeC.dsid.length > 0 ? activeC.dsid : @"Đã xác thực"];
      [[cell detailTextLabel] setText:sub];
      cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
      [[cell textLabel] setText:@"✨ Chưa đăng nhập Apple ID"];
      [[cell detailTextLabel] setText:@"Chạm vào mục bên dưới để đăng nhập nick mới"];
    }
  } else if (indexPath.section == 1) {
    // Nút thêm tài khoản
    [[cell textLabel] setText:@"➕ Đăng Nhập Thêm Tài Khoản Apple ID"];
    [[cell detailTextLabel] setText:@"Lưu nick hiện tại & hiển thị đăng nhập thêm nick"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  } else if (indexPath.section == 2) {
    // Danh sách tài khoản đã lưu
    NSArray<SSSavedAccount *> *vault = [SSContainerManager sharedManager].savedAccounts;
    if (vault.count == 0) {
      [[cell textLabel] setText:@"Chưa có tài khoản nào được lưu trong kho"];
      [[cell detailTextLabel] setText:@"Đăng nhập tài khoản để tự động lưu vĩnh viễn"];
    } else {
      SSSavedAccount *acc = vault[indexPath.row];
      [[cell textLabel] setText:acc.appleID];
      
      NSString *status = @"";
      if ([acc.appleID isEqualToString:[SSContainerManager sharedManager].activeAppleID]) {
        status = @"⭐ Đang sử dụng";
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      } else {
        status = @"Sẵn sàng đổi";
        cell.accessoryType = UITableViewCellAccessoryNone;
      }
      NSString *sub = [NSString stringWithFormat:@"%@ • DSID: %@", status, acc.dsid.length > 0 ? acc.dsid : @"N/A"];
      [[cell detailTextLabel] setText:sub];
    }
  } else {
    // Vùng chứa ảo
    NSArray<SSContainer *> *containers = [SSContainerManager sharedManager].containers;
    if (indexPath.row < containers.count) {
      SSContainer *c = containers[indexPath.row];
      BOOL isActive = [c.identifier isEqualToString:[SSContainerManager sharedManager].activeContainerID];
      
      NSString *title = c.name;
      if (c.isDefault) {
        title = [NSString stringWithFormat:@"%@ (Mặc định)", c.name];
      }
      [[cell textLabel] setText:title];

      NSString *sub = c.appleID.length > 0 ? [NSString stringWithFormat:@"Apple ID: %@", c.appleID] : @"✨ Vùng chứa sạch";
      [[cell detailTextLabel] setText:sub];

      if (isActive) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
    } else {
      // Dòng cuối: Tạo vùng chứa mới
      [[cell textLabel] setText:@"➕ Tạo Vùng Chứa Ảo Mới (Crane)"];
      [[cell detailTextLabel] setText:@"Tách biệt sandbox và tài khoản"];
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
  }

  return cell;
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  if (indexPath.section == 0) {
    // Chạm tài khoản đang hoạt động -> Không cần đổi
    return;
  } else if (indexPath.section == 1) {
    // Bấm đăng nhập thêm Apple ID mới
    [self promptAddNewAppleID];
  } else if (indexPath.section == 2) {
    // Đổi Apple ID 1-chạm
    NSArray<SSSavedAccount *> *vault = [SSContainerManager sharedManager].savedAccounts;
    if (indexPath.row < vault.count) {
      SSSavedAccount *target = vault[indexPath.row];
      [self executeAccountSwitchToAppleID:target.appleID];
    }
  } else {
    // Quản lý vùng chứa
    NSArray<SSContainer *> *containers = [SSContainerManager sharedManager].containers;
    if (indexPath.row < containers.count) {
      SSContainer *selected = containers[indexPath.row];
      [[SSContainerManager sharedManager] switchToContainer:selected error:nil];
      
      UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
      [feedback impactOccurred];

      [self refreshStoreFrontAndDismiss];
    } else {
      [self promptCreateNewContainer];
    }
  }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.section == 2) {
    NSArray<SSSavedAccount *> *vault = [SSContainerManager sharedManager].savedAccounts;
    if (indexPath.row < vault.count) {
      SSSavedAccount *acc = vault[indexPath.row];
      return ![acc.appleID isEqualToString:[SSContainerManager sharedManager].activeAppleID];
    }
  } else if (indexPath.section == 3) {
    NSArray<SSContainer *> *containers = [SSContainerManager sharedManager].containers;
    if (indexPath.row < containers.count) {
      SSContainer *c = containers[indexPath.row];
      return !c.isDefault && ![c.identifier isEqualToString:[SSContainerManager sharedManager].activeContainerID];
    }
  }
  return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
  if (editingStyle == UITableViewCellEditingStyleDelete) {
    if (indexPath.section == 2) {
      NSArray<SSSavedAccount *> *vault = [SSContainerManager sharedManager].savedAccounts;
      if (indexPath.row < vault.count) {
        SSSavedAccount *acc = vault[indexPath.row];
        [[SSContainerManager sharedManager] deleteAccountFromVault:acc.appleID];
        [tableView reloadData];
      }
    } else if (indexPath.section == 3) {
      NSArray<SSContainer *> *containers = [SSContainerManager sharedManager].containers;
      if (indexPath.row < containers.count) {
        SSContainer *c = containers[indexPath.row];
        [[SSContainerManager sharedManager] deleteContainer:c];
        [tableView reloadData];
      }
    }
  }
}

#pragma mark - Thực thi Đổi Tài Khoản & Làm Mới Giao Diện

- (void)executeAccountSwitchToAppleID:(NSString *)appleID {
  BOOL success = [[SSContainerManager sharedManager] switchToAccountWithAppleID:appleID error:nil];
  if (success) {
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [feedback impactOccurred];

    [self refreshStoreFrontAndDismiss];
  } else {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chưa Đồng Bộ" 
                                                                   message:[NSString stringWithFormat:@"Tài khoản '%@' chưa có phiên xác thực trong hệ thống. Hãy bấm 'Đăng Nhập Thêm Tài Khoản' để nạp phiên.", appleID] 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đồng Ý" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
  }
}

- (void)refreshStoreFrontAndDismiss {
  Class clientClass = objc_getClass("SKUIClientContext");
  if (clientClass) {
    id ctx = [clientClass defaultContext];
    if (ctx && [ctx respondsToSelector:@selector(applicationController)]) {
      id appCtrl = [ctx applicationController];
      if (appCtrl && [appCtrl respondsToSelector:@selector(_resetUserInterfaceAfterStoreFrontChange)]) {
        [appCtrl _resetUserInterfaceAfterStoreFrontChange];
      }
    }
  }
  [self dismissAnimated];
}

#pragma mark - Đăng Nhập Thêm Tài Khoản Mới (Không Mất Nick Cũ)

- (void)promptAddNewAppleID {
  // 1. Snapshot lưu giữ ngay tài khoản hiện tại vào Vault
  [[SSContainerManager sharedManager] syncAccountsFromSystem];

  UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"➕ Đăng Nhập Thêm Apple ID" 
                                                                 message:@"Tài khoản hiện tại đã được sao lưu vào kho (không bị đăng xuất, không mất token).\nBạn muốn tiến hành đăng nhập theo phương thức nào?" 
                                                          preferredStyle:UIAlertControllerStyleActionSheet];

  UIAlertAction *sysAuthAction = [UIAlertAction actionWithTitle:@"🔐 Mở Đăng Nhập Hệ Thống (Khuyên dùng)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [self triggerSystemSignInSheet];
  }];

  UIAlertAction *manualAction = [UIAlertAction actionWithTitle:@"✍️ Nhập Nhanh Email Tài Khoản" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [self promptManualAccountEntry];
  }];

  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil];

  [sheet addAction:sysAuthAction];
  [sheet addAction:manualAction];
  [sheet addAction:cancelAction];

  [self presentViewController:sheet animated:YES completion:nil];
}

- (void)triggerSystemSignInSheet {
  [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/StoreServices.framework"] load];
  Class authContextClass = objc_getClass("SSMutableAuthenticationContext");
  Class authReqClass = objc_getClass("SSAuthenticateRequest");

  if (authContextClass && authReqClass) {
    id context = [[authContextClass alloc] init];
    if ([context respondsToSelector:@selector(setPromptStyle:)]) {
      [context setPromptStyle:1]; // 1 = Sign in prompt
    }
    if ([context respondsToSelector:@selector(setCanCreateNewAccount:)]) {
      [context setCanCreateNewAccount:YES];
    }

    id request = [[authReqClass alloc] initWithAuthenticationContext:context];
    [request startWithAuthenticateResponseBlock:^(id response) {
      dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[StoreSwitcher] Kết quả đăng nhập thêm tài khoản: %@", response);
        [[SSContainerManager sharedManager] syncAccountsFromSystem];
        [self reloadAllData];
        [self refreshStoreFrontAndDismiss];
      });
    }];
  } else {
    // Fallback: Mở trang tài khoản của App Store
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://apps.apple.com/account"] options:@{} completionHandler:nil];
  }
}

- (void)promptManualAccountEntry {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Thêm Email Apple ID" 
                                                                 message:@"Nhập địa chỉ email Apple ID để ghi nhận vào kho lưu trữ:" 
                                                          preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
    textField.placeholder = @"example@icloud.com";
    textField.keyboardType = UIKeyboardTypeEmailAddress;
  }];

  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil];
  UIAlertAction *saveAction = [UIAlertAction actionWithTitle:@"Lưu Vào Kho" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSString *email = alert.textFields.firstObject.text;
    if (email.length > 0) {
      [[SSContainerManager sharedManager] saveAccountToVault:email dsid:@"" altDSID:@"" storeFront:@""];
      [self reloadAllData];
    }
  }];

  [alert addAction:cancelAction];
  [alert addAction:saveAction];
  [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Tạo Vùng Chứa Mới

- (void)promptCreateNewContainer {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"📦 Tạo Vùng Chứa Mới" 
                                                                 message:@"Nhập tên vùng chứa mới để tách biệt dữ liệu hộp cát:" 
                                                          preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
    textField.placeholder = [NSString stringWithFormat:@"Vùng chứa #%lu", (unsigned long)([SSContainerManager sharedManager].containers.count + 1)];
  }];

  UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil];
  UIAlertAction *createAction = [UIAlertAction actionWithTitle:@"Tạo & Kích Hoạt" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSString *name = alert.textFields.firstObject.text;
    SSContainer *newC = [[SSContainerManager sharedManager] createNewCleanContainerWithName:name];
    [[SSContainerManager sharedManager] switchToContainer:newC error:nil];
    
    [self refreshStoreFrontAndDismiss];
  }];

  [alert addAction:cancelAction];
  [alert addAction:createAction];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)openAppAgentDashboard {
  AppAgentDashboardController *dashboard = [[AppAgentDashboardController alloc] initWithStyle:UITableViewStyleGrouped];
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:dashboard];
  nav.modalPresentationStyle = UIModalPresentationPageSheet;
  [self presentViewController:nav animated:YES completion:nil];
}

@end