#import "AppAgentDashboardController.h"
#import "AppAgentClient.h"

@interface AppAgentDashboardController ()
@property (nonatomic, strong) NSDictionary *registeredApps;
@property (nonatomic, strong) NSArray *appKeys;
@property (nonatomic, strong) NSArray *currentPackets;
@end

@implementation AppAgentDashboardController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"⚡ AppAgent Controller";
    
    UIBarButtonItem *refreshBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(loadApps)];
    self.navigationItem.rightBarButtonItem = refreshBtn;

    UIBarButtonItem *closeBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(dismissSelf)];
    self.navigationItem.leftBarButtonItem = closeBtn;

    [self loadApps];
}

- (void)dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)loadApps {
    self.registeredApps = [[AppAgentClient sharedClient] getRegisteredApps];
    self.appKeys = [self.registeredApps allKeys];
    [self.tableView reloadData];
}

#pragma mark - Table View DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.appKeys.count > 0 ? self.appKeys.count : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [NSString stringWithFormat:@"Các App đang chạy có Dylib (%lu)", (unsigned long)self.appKeys.count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"AppCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    if (self.appKeys.count == 0) {
        cell.textLabel.text = @"Chưa có App nào tiêm Dylib đang chạy";
        cell.detailTextLabel.text = @"Mở bất kỳ app nào đã tiêm AppAgent.dylib rồi bấm Làm mới";
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }

    NSString *bundleId = self.appKeys[indexPath.row];
    NSDictionary *info = self.registeredApps[bundleId];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ (%@)", info[@"appName"] ?: bundleId, info[@"pid"] ?: @"?"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"Port: %@ | %@", info[@"port"] ?: @"-", bundleId];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.appKeys.count == 0) return;

    NSString *bundleId = self.appKeys[indexPath.row];
    self.selectedBundleId = bundleId;

    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Điều khiển: %@", bundleId]
                                                                         message:@"Chọn hành động muốn thực hiện trên App:"
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];

    // 1. Xem danh sách Packets
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"📦 Xem Packets (IAP, Deeplink, API)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showPacketsForApp:bundleId];
    }]];

    // 2. Soi Objective-C Classes
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"🔍 Soi Classes & Methods" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showClassInspectorForApp:bundleId];
    }]];

    // 3. Quét & Bấm nút UI từ xa
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"📱 Điều khiển UI (Click Nút / Nhập Text)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showUIControllerForApp:bundleId];
    }]];

    // 4. Bật / Tắt Floating HUD Sniffer trên App
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"⚡ Bật/Tắt HUD Sniffer trên màn hình App" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[AppAgentClient sharedClient] toggleOverlayInApp:bundleId completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:success ? @"Đã gửi lệnh bật/tắt HUD!" : @"Lỗi kết nối App"];
            });
        }];
    }]];

    // 5. Gửi Popup Alert vào App
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"🔔 Bắn Popup Alert vào App" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self promptSendAlertToApp:bundleId];
    }]];

    // 6. Kích hoạt Deeplink URL Scheme
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"🔗 Mở Deeplink / URL Scheme" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self promptOpenUrlInApp:bundleId];
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];

    [self presentViewController:actionSheet animated:YES completion:nil];
}

#pragma mark - Actions

- (void)showPacketsForApp:(NSString *)bundleId {
    [[AppAgentClient sharedClient] fetchPacketsForBundleId:bundleId completion:^(NSArray *packets, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || packets.count == 0) {
                [self showToast:@"Chưa có packet nào được ghi nhận."];
                return;
            }

            self.currentPackets = packets;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Packets (%lu)", (unsigned long)packets.count]
                                                                           message:@"Chọn packet để xem chi tiết / Replay / Sửa:"
                                                                    preferredStyle:UIAlertControllerStyleActionSheet];

            for (NSDictionary *p in packets) {
                NSString *title = [NSString stringWithFormat:@"[%@] %@", p[@"timestamp"] ?: @"", p[@"title"] ?: @"Packet"];
                [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                    [self showPacketDetail:p inApp:bundleId];
                }]];
            }
            [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }];
}

- (void)showPacketDetail:(NSDictionary *)packet inApp:(NSString *)bundleId {
    NSString *pktId = packet[@"id"];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:packet options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:packet[@"title"] ?: @"Chi tiết Packet"
                                                                   message:jsonStr
                                                            preferredStyle:UIAlertControllerStyleAlert];

    // Nút Replay packet
    [alert addAction:[UIAlertAction actionWithTitle:@"▶️ Replay (Gửi lại)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[AppAgentClient sharedClient] replayPacketForBundleId:bundleId packetId:pktId completion:^(BOOL success, id response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:success ? @"Đã Replay Packet thành công!" : [NSString stringWithFormat:@"Replay thất bại: %@", error.localizedDescription]];
            });
        }];
    }]];

    // Nút Sửa payload
    [alert addAction:[UIAlertAction actionWithTitle:@"✏️ Sửa Payload" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self promptEditPacket:packet inApp:bundleId];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)promptEditPacket:(NSDictionary *)packet inApp:(NSString *)bundleId {
    NSString *pktId = packet[@"id"];
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:packet[@"payload"] ?: @{} options:NSJSONWritingPrettyPrinted error:nil];
    NSString *payloadStr = [[NSString alloc] initWithData:payloadData encoding:NSUTF8StringEncoding];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sửa Payload Packet"
                                                                   message:@"Nhập JSON payload mới:"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.text = payloadStr;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Lưu lại" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *newStr = alert.textFields.firstObject.text;
        NSData *d = [newStr dataUsingEncoding:NSUTF8StringEncoding];
        id parsed = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil] ?: newStr;

        [[AppAgentClient sharedClient] modifyPacketForBundleId:bundleId packetId:pktId newPayload:parsed completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:success ? @"Đã lưu payload mới thành công!" : @"Lỗi lưu payload"];
            });
        }];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showClassInspectorForApp:(NSString *)bundleId {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Soi Objective-C Classes"
                                                                   message:@"Nhập từ khóa tìm kiếm Class (VD: Account, Store, Purchase):"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Từ khóa class (để trống để lấy tất cả)";
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Tìm kiếm" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *keyword = alert.textFields.firstObject.text ?: @"";
        [[AppAgentClient sharedClient] fetchClassesForBundleId:bundleId keyword:keyword completion:^(NSArray *classes, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (classes.count == 0) {
                    [self showToast:@"Không tìm thấy class nào phù hợp"];
                    return;
                }

                UIAlertController *resAlert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Classes (%lu)", (unsigned long)classes.count]
                                                                                 message:@"Chọn Class để xem methods & properties:"
                                                                          preferredStyle:UIAlertControllerStyleActionSheet];

                for (NSString *clsName in classes) {
                    [resAlert addAction:[UIAlertAction actionWithTitle:clsName style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                        [[AppAgentClient sharedClient] inspectClassForBundleId:bundleId className:clsName completion:^(NSDictionary *classInfo, NSError *err) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                NSData *d = [NSJSONSerialization dataWithJSONObject:classInfo ?: @{} options:NSJSONWritingPrettyPrinted error:nil];
                                NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                                [self showAlertWithTitle:clsName message:s];
                            });
                        }];
                    }]];
                }
                [resAlert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:resAlert animated:YES completion:nil];
            });
        }];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showUIControllerForApp:(NSString *)bundleId {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Điều khiển UI App từ xa"
                                                                   message:@"Chọn hành động:"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [alert addAction:[UIAlertAction actionWithTitle:@"🖱️ Giả lập Bấm Nút (Click Button)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self promptClickButtonInApp:bundleId];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"⌨️ Giả lập Nhập Chữ (Input Text)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self promptInputTextInApp:bundleId];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"🌳 Dump cây giao diện (UI Hierarchy)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[AppAgentClient sharedClient] dumpUIForBundleId:bundleId completion:^(NSDictionary *uiTree, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSData *d = [NSJSONSerialization dataWithJSONObject:uiTree ?: @{} options:NSJSONWritingPrettyPrinted error:nil];
                NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
                [self showAlertWithTitle:@"UI Hierarchy" message:s];
            });
        }];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)promptClickButtonInApp:(NSString *)bundleId {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bấm nút từ xa"
                                                                   message:@"Nhập tiêu đề hoặc ID của nút bấm trên app:"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"VD: Mua, Đăng nhập, OK, Close";
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Bấm ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *btnName = alert.textFields.firstObject.text;
        [[AppAgentClient sharedClient] clickButtonForBundleId:bundleId textOrId:btnName completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:success ? @"Đã kích hoạt bấm nút thành công!" : @"Không tìm thấy nút"];
            });
        }];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)promptInputTextInApp:(NSString *)bundleId {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Nhập văn bản vào ô Input"
                                                                   message:@"Nhập ID/Placeholder ô nhập liệu và nội dung:"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Placeholder hoặc ID ô nhập";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Văn bản cần gõ vào";
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Nhập ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *target = alert.textFields[0].text;
        NSString *text = alert.textFields[1].text;
        [[AppAgentClient sharedClient] sendInputForBundleId:bundleId targetId:target text:text completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:success ? @"Đã nhập văn bản thành công!" : @"Không tìm thấy ô nhập liệu"];
            });
        }];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)promptSendAlertToApp:(NSString *)bundleId {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bắn Popup vào App"
                                                                   message:@"Nhập tiêu đề và nội dung thông báo:"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Tiêu đề Popup";
        tf.text = @"StoreSwitcher Alert";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Nội dung Popup";
        tf.text = @"Lệnh điều khiển từ Tweak đã được thực thi!";
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Gửi ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *t = alert.textFields[0].text;
        NSString *m = alert.textFields[1].text;
        [[AppAgentClient sharedClient] showAlertInApp:bundleId title:t message:m completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:success ? @"Đã bắn Popup vào App!" : @"Gửi thất bại"];
            });
        }];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)promptOpenUrlInApp:(NSString *)bundleId {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Mở Deeplink / URL Scheme"
                                                                   message:@"Nhập URL Scheme hoặc Deeplink:"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"VD: myapp://purchase?item=vip";
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Mở ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *u = alert.textFields.firstObject.text;
        [[AppAgentClient sharedClient] openUrlInApp:bundleId url:u completion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showToast:success ? @"Đã gửi lệnh mở URL!" : @"Thất bại"];
            });
        }];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showToast:(NSString *)msg {
    UIAlertController *toast = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:toast animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [toast dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
