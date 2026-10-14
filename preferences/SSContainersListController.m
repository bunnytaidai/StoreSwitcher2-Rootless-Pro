#import "SSContainersListController.h"
#import "SSContainerDetailController.h"
#import "../SSContainerManager.h"

@implementation SSContainersListController

- (id)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];

        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"DANH SÁCH VÙNG CHỨA ẢO (CRANE STYLE)"];
        [group setProperty:@"Chạm vào một vùng chứa để cấu hình chi tiết, chỉnh sửa Keychain ID, email/mật khẩu Apple ID, cờ cách ly dữ liệu hộp cát hoặc sao lưu." forKey:@"footerText"];
        [specs addObject:group];

        // Nút thêm vùng chứa mới
        PSSpecifier *addBtn = [PSSpecifier preferenceSpecifierNamed:@"➕ Tạo Vùng Chứa Mới Sạch Sẽ"
                                                             target:self
                                                                set:NULL
                                                                get:NULL
                                                             detail:Nil
                                                               cell:PSButtonCell
                                                               edit:Nil];
        [addBtn setButtonAction:@selector(addNewContainer:)];
        [specs addObject:addBtn];

        // Danh sách các container
        PSSpecifier *listGroup = [PSSpecifier groupSpecifierWithName:@"CÁC VÙNG CHỨA ĐÃ TẠO"];
        [specs addObject:listGroup];

        NSArray *containers = [SSContainerManager sharedManager].containers;
        NSString *activeID = [SSContainerManager sharedManager].activeContainerID;

        for (SSContainer *c in containers) {
            BOOL isActive = [c.identifier isEqualToString:activeID];
            NSString *title = c.name ?: @"Vùng chứa";
            if (c.isDefault) {
                title = [NSString stringWithFormat:@"%@ (Mặc định)", title];
            }
            if (isActive) {
                title = [NSString stringWithFormat:@"✓ %@", title];
            }

            PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:title
                                                               target:self
                                                                  set:NULL
                                                                  get:NULL
                                                               detail:[SSContainerDetailController class]
                                                                 cell:PSLinkCell
                                                                 edit:Nil];
            [spec setProperty:c.identifier forKey:@"containerID"];
            [specs addObject:spec];
        }

        _specifiers = specs;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = @"📦 Quản Lý Vùng Chứa";
    [[SSContainerManager sharedManager] loadSettings];
    [self reloadSpecifiers];
}

- (void)addNewContainer:(PSSpecifier *)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Tạo Vùng Chứa Mới" 
                                                                   message:@"Vùng chứa mới sẽ được cô lập hoàn toàn, dữ liệu sạch và chưa có Apple ID đăng nhập." 
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = [NSString stringWithFormat:@"Vùng chứa #%lu", (unsigned long)([SSContainerManager sharedManager].containers.count + 1)];
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Tạo" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = alert.textFields.firstObject.text;
        [[SSContainerManager sharedManager] createNewCleanContainerWithName:name];
        [self reloadSpecifiers];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

@end
