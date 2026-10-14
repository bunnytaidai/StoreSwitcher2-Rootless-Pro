# HƯỚNG DẪN KIẾN TRÚC VÀ SỬ DỤNG HỆ THỐNG AGENT DYLIB & TWEAK

Hệ thống được thiết kế theo mô hình **Agent - Controller IPC** hai chiều hiện đại, giải quyết toàn bộ các yêu cầu:
1. **`AppAgent.dylib`**: Dynamic Library được tiêm trực tiếp vào các App mục tiêu (Sandbox/UIKit).
2. **`StoreSwitcher` (Tweak)**: Tích hợp bảng điều khiển đồ hoạ (GUI) ngay trên iPhone để quản lý, soi và điều khiển các app đã tiêm.
3. **`agentcli` (Terminal Tool)**: Công cụ dòng lệnh cài đặt tại `/usr/bin/agentcli` cho phép điều khiển app từ Terminal (SSH hoặc NewTerm) mọi lúc mọi nơi.

---

## 1. CƠ CHẾ GIAO TIẾP HAI CHIỀU (IPC ARCHITECTURE)
- Khi một App bất kỳ (đã tiêm `AppAgent.dylib`) khởi động, dylib tự động mở một **POSIX Socket Loopback HTTP/JSON REST Server** tại `127.0.0.1:<port>`.
- App sẽ tự động ghi danh thông tin (Bundle ID, Tên App, PID, Port IPC) vào file:
  - `/var/mobile/Library/Preferences/com.agent.registered_apps.plist` (hoặc `/tmp/com.agent.registered_apps.plist`).
- Cả **Tweak** và **Terminal Tool** (`agentcli`) đều đọc registry này để kết nối tới app, gửi lệnh điều khiển và nhận kết quả tức thì (Real-time 2-way).

---

## 2. CÁC TÍNH NĂNG CHÍNH CỦA FILE `AppAgent.dylib`

### A. Bắt, Lưu & Giám Sát Packets (IAP Sandbox, Deeplink, Network API)
- **StoreKit / In-App Purchase Hook**:
  - Tự động bắt sự kiện `-[SKPaymentQueue addPayment:]` (Product ID, Số lượng, Simulator Sandbox Flag).
  - Tự động bắt sự kiện `paymentQueue:updatedTransactions:` (Trạng thái Mua thành công, Thất bại, Khôi phục, Transaction ID, Base64 App Store Receipt).
- **URL Scheme & Deeplink Hook**:
  - Bắt cả Deeplink đi ra (Outgoing `openURL:options:completionHandler:`) và Deeplink đi vào (Incoming `application:openURL:options:`).
- **Network API HTTP/HTTPS Hook**:
  - Bắt toàn bộ URL API, Headers, Method, Request JSON Body và Response Data trả về từ máy chủ.

### B. Chỉnh Sửa & Gửi Lại (Replay) Packet
- **Replay API**: Cho phép gửi lại request mạng với tham số cũ hoặc tham số đã sửa đổi trực tiếp từ bên trong ngữ cảnh của App (chạy với đầy đủ Cookie/Session/Headers của App).
- **Replay IAP**: Ép app nạp lại gói sản phẩm StoreKit vào `SKPaymentQueue`.
- **Replay Deeplink**: Ép app mở lại luồng URL Scheme.
- **Sửa đổi Payload (Tamper)**: Cho phép sửa lại JSON Body của packet trước khi Replay.

### C. Khám Phá Runtime (Classes & Methods Inspection)
- Quét toàn bộ danh sách Objective-C Classes trong app (`objc_getClassList`).
- Tìm kiếm Class theo từ khóa (VD: `Account`, `Store`, `Login`, `Purchase`).
- Liệt kê toàn bộ:
  - Instance Methods & Class Methods (kèm Type Encodings).
  - Properties & Thuộc tính của Class.
- Cho phép thực thi hàm động (`invokeMethod`) từ xa.

### D. Điều Khiển Giao Diện (UI Automation & Overlay)
- **Dump UI Hierarchy**: Xuất cây giao diện (UIWindow, Root View Controller, Subviews, Nút bấm, Ô nhập liệu, Nhãn).
- **Click Nút Từ Xa**: Tìm kiếm nút bấm theo Tiêu đề (`title`) hoặc `accessibilityIdentifier` và kích hoạt sự kiện `UIControlEventTouchUpInside`.
- **Nhập Liệu Từ Xa**: Điền chữ tự động vào `UITextField` / `UITextView`.
- **Bắn Alert Thông Báo**: Tạo `UIAlertController` hiển thị đè lên trên app mục tiêu.
- **Floating HUD Sniffer**: Bật một cửa sổ nổi màu xanh neon (`UIWindowLevelAlert`) ngay trong app để theo dõi packet nhảy thời gian thực.

---

## 3. ĐIỀU KHIỂN BẰNG LỆNH TERMINAL (`agentcli`)

Bạn có thể SSH vào iPhone hoặc mở ứng dụng **NewTerm** trên iPhone và gõ:

```bash
# 1. Xem hướng dẫn sử dụng
agentcli help

# 2. Liệt kê các App đang chạy đã tiêm Dylib
agentcli list

# 3. Xem trạng thái và thông tin của 1 app (dùng Bundle ID hoặc tên app)
agentcli com.apple.AppStore status

# 4. Xem danh sách các Packet vừa bắt được (IAP, Deeplink, API)
agentcli com.apple.AppStore packets

# 5. Gửi lại (Replay) một packet theo ID
agentcli com.apple.AppStore replay <packet_id>

# 6. Sửa payload của một packet
agentcli com.apple.AppStore modify <packet_id> '{"productId":"com.app.vip","quantity":1}'

# 7. Quét danh sách Class trong app theo từ khóa
agentcli com.apple.AppStore classes Account

# 8. Soi chi tiết Methods & Properties của một Class
agentcli com.apple.AppStore inspect AppStore.AccountViewController

# 9. Dump toàn bộ cây giao diện UI của app
agentcli com.apple.AppStore dump-ui

# 10. Giả lập bấm một nút trên app
agentcli com.apple.AppStore click "Đăng nhập"

# 11. Nhập văn bản vào ô tìm kiếm hoặc form
agentcli com.apple.AppStore input "SearchField" "Tên tài khoản"

# 12. Bắn một Popup Alert vào app
agentcli com.apple.AppStore alert "Thông báo" "Lệnh điều khiển từ xa thành công!"

# 13. Bật/Tắt Floating HUD Sniffer trực tiếp trên màn hình App
agentcli com.apple.AppStore overlay

# 14. Ép app mở một Deeplink / URL Scheme
agentcli com.apple.AppStore open-url "itms-apps://"
```

---

## 4. ĐIỀU KHIỂN BẰNG GIAO DIỆN ĐỒ HOẠ (GUI TRÊN TWEAK)

1. Mở App Store hoặc ứng dụng kích hoạt StoreSwitcher.
2. Bấm vào nút chuyển tài khoản StoreSwitcher.
3. Ở góc trên bên trái màn hình sẽ xuất hiện nút **`⚡ Agent`**.
4. Bấm vào **`⚡ Agent`** để mở **AppAgent Controller Dashboard**:
   - Hiển thị danh sách các App đang chạy có Dylib.
   - Chạm vào bất kỳ App nào để mở Action Menu:
     - 📦 **Xem Packets**: Xem danh sách các gói tin IAP, Deeplink, API; bấm vào gói tin để xem chi tiết, sửa JSON payload hoặc bấm **Replay (Gửi lại)** ngay lập tức.
     - 🔍 **Soi Classes & Methods**: Tìm kiếm Class và xem toàn bộ hàm/thuộc tính.
     - 📱 **Điều khiển UI**: Bấm nút từ xa, nhập text, dump UI.
     - ⚡ **Bật/Tắt HUD Sniffer**: Kích hoạt bảng nổi màu xanh hiển thị log ngay trên màn hình app đó.
     - 🔔 **Bắn Popup Alert vào App**: Nhập tiêu đề/nội dung để hiển thị trên app.
     - 🔗 **Mở Deeplink / URL Scheme**: Gửi URL để app mở.

---

## 5. CÁCH TIÊM `AppAgent.dylib` VÀO APP

### Cách 1: Tiêm tự động bằng Cydia Substrate / ElleKit (Jailbreak)
- File `AppAgent.plist` đã được cấu hình với Filter `com.apple.UIKit`.
- Khi cài đặt gói `.deb` được build từ Theos, MobileSubstrate sẽ tự động nạp `AppAgent.dylib` vào các ứng dụng UIKit khi chúng khởi động.

### Cách 2: Tiêm vào file IPA không cần Jailbreak (Sideload / TrollStore)
- Bạn có thể lấy file `AppAgent.dylib` đã biên dịch và tiêm vào bất kỳ file `.ipa` nào bằng các công cụ như:
  - **Azule**: `azule -i original.ipa -o injected.ipa -f AppAgent.dylib`
  - **Sideloadly / AltStore**: Thêm dylib vào mục Tweak Injection khi cài đặt IPA.
  - Do code hoàn toàn sử dụng Objective-C Runtime thuần và POSIX Sockets, dylib hoạt động độc lập và hoàn hảo ngay cả trên thiết bị Non-Jailbreak chạy qua TrollStore!
