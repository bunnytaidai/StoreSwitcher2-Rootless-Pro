# StoreSwitcher 2 Pro & AppAgent (v2.4.0)
### ⚡ Crane-Style Virtual Containers, Multi Apple ID Switcher with Anti-Leak Daemon Protection, 3D Touch Shortcut, In-App Agent & Settings Integration for iOS 11 - 15.8.x

Kho lưu trữ chính thức hỗ trợ **Rootless** (Dopamine, Palera1n) trên chip **A9 (iPhone 6s/6s Plus/SE 1)** và các dòng chip mới **A10 - A15 (iPhone 7 đến 13 Pro Max)**, đồng thời tương thích cả thiết bị **Rootful**.

---

## 🌐 1. Thêm Nguồn Vào Thiết Bị (APT Repository cho Sileo & Saily)

Địa chỉ kho nguồn APT chính thức:
```text
https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/
```

### Thao tác thêm nguồn 1 chạm trực tiếp trên iPhone:
- **⚡ Thêm vào Sileo**: [`sileo://source/https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/`](sileo://source/https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/)
- **⛵ Thêm vào Saily**: [`saily://add-source?url=https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/`](saily://add-source?url=https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/)
- **🦓 Thêm vào Zebra**: [`zbra://sources/add/https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/`](zbra://sources/add/https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/)
- **📦 Thêm vào Cydia**: [`cydia://url/https://cydia.saurik.com/api/share#?source=https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/`](cydia://url/https://cydia.saurik.com/api/share#?source=https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/)

---

## 📁 2. Tải Trực Tiếp File Cài Đặt `.deb` (v2.4.0)

Bản phát hành chính thức mới nhất:
- 👉 [**com.subdiox.storeswitcher2_2.4.0_iphoneos-arm64.deb**](https://github.com/bunnytaidai/StoreSwitcher2-Rootless-Pro/raw/main/debs/com.subdiox.storeswitcher2_2.4.0_iphoneos-arm64.deb) *(422 KB, SHA256: `7a9e282dca3c...`)*

### Hướng dẫn cài đặt bằng Filza File Manager:
1. Mở Safari trên iPhone, bấm link tải file deb ở trên.
2. Chọn **Mở trong Filza (Open in Filza)**.
3. Chạm vào file `com.subdiox.storeswitcher2_2.4.0_iphoneos-arm64.deb` -> Chọn **Cài đặt (Install)** ở góc trên bên phải.
4. Chờ Filza chạy script tự động phân quyền `postinst` và hiển thị `Mã thoát: 0`.
5. Bấm **Khởi động lại SpringBoard (Respring)** để tweak và dylib kích hoạt hoàn tất.

---

## 🛡️ 3. Danh Sách Gói Phụ Thuộc (Dependencies - Đủ Mới Cài)

Gói `.deb` đã được cấu hình chặt chẽ trong file `control`:
```text
Package: com.subdiox.storeswitcher2
Name: StoreSwitcher 2 Pro & AppAgent
Depends: firmware (>= 11.0), ellekit | mobilesubstrate (>= 0.9.5000), preferenceloader
Version: 2.4.0
Architecture: iphoneos-arm64
```
- **`firmware (>= 11.0)`**: Hỗ trợ từ iOS 11.0 đến iOS 15.8.x.
- **`ellekit` (hoặc `mobilesubstrate`)**: Nền tảng hook function cần thiết cho Dopamine Rootless và Rootful. Sileo/Saily sẽ tự động kéo ElleKit về nếu thiết bị chưa cài đặt.
- **`preferenceloader`**: Thành phần nạp menu cấu hình tweak vào trong ứng dụng Cài đặt (Settings) gốc của iOS.

---

## 🚀 4. Hệ Thống 7 Tab Trung Tâm Điều Khiển Chuyên Sâu (Trong Cài Đặt Tweak)

Sau khi cài đặt, mở **Cài đặt (Settings)** -> kéo xuống tìm **StoreSwitcher Pro**:

1. **Tab 1: 📦 Quản Lý Vùng Chứa Ảo (Crane Style)**:
   - Tạo vùng chứa mới sạch sẽ, cô lập dữ liệu hộp cát, tách biệt thông báo và Keychain ID.
   - Cơ chế bảo vệ phiên đăng nhập: Không kill daemon vô tội vạ, giữ nguyên token/session AuthKit/StoreKit giúp tài khoản không bao giờ bị văng hay bắt nhập lại mật khẩu/OTP 2FA.
   - Thêm nút **"➕ Đăng nhập thêm Apple ID mới"**: Lưu trữ snapshot nick hiện tại vào két an toàn (`accounts_vault.json`) và mở hộp thoại đăng nhập thêm nick mới mà không cần đăng xuất.
2. **Tab 2: 🎯 Quản Lý App Tiêm Dylib (Beacon IPC Báo Về Thật)**:
   - Quét thời gian thực qua cơ chế Heartbeat Beacon IPC (`/var/mobile/Library/Application Support/StoreSwitcher/injected_beacons/`).
   - Tuyệt đối chỉ hiển thị các app **thực sự đã load `AppAgent.dylib`** và đang chạy (có kiểm tra `kill(pid, 0)`).
   - Đọc chi tiết PID thật, Bundle ID, Sandbox path, Receipt status và Port điều khiển ngầm.
3. **Tab 3: ⚡ Tự Động Đổi Nick (Dev Code Runner)**:
   - Cấu hình kịch bản tự động chuyển đổi giữa các nick Apple ID đã lưu và thực thi chuỗi hành động ngầm.
4. **Tab 4: 📡 Thu Bắt & Replay Packet (Network Sniffer)**:
   - Bắt gói tin HTTPS StoreKit/In-App, trích xuất Header, Cookie, Token và cho phép phát lại (Replay) kịch bản request.
5. **Tab 6: 💳 Quản Lý Gói Đăng Ký (StoreKit Native Sheet)**:
   - Gọi popup quản lý gói đăng ký Subscription **thật 100% của Apple** (`SKAccountPageViewController` / `itms-apps://apps.apple.com/account/subscriptions`).
   - Các tham số Bundle ID, Product ID, Service Title, Tier, Price, Expiration Date được liên kết chính xác từ tài khoản hệ thống và StoreKit receipt.
6. **Tab 7: ✈️ Quản Lý Link TestFlight**:
   - Quản lý link `itms-beta://`, tự động theo dõi và nhận slot tham gia thử nghiệm beta app ngầm.

---

## 📲 5. Hướng Dẫn Dùng `AppAgent.dylib` Cho Máy Chưa Jailbreak (Ký 7 Ngày)

Bạn hoàn toàn có thể sử dụng `AppAgent.dylib` trên các thiết bị không Jailbreak (ví dụ: iPhone 13 Pro Max iOS 16/17):

1. **Tiêm Dylib vào IPA**:
   - Dùng công cụ **TrollFools** (trực tiếp trên iPhone) hoặc **Sideloadly / Azule / optool** (trên máy tính) để tiêm file `AppAgent.dylib` vào file IPA của App mục tiêu.
2. **Ký chứng chỉ & Cài đặt**:
   - Ký bằng tài khoản Apple ID miễn phí (chứng chỉ 7 ngày) qua Sideloadly / AltStore / Scarlet / Esign.
3. **Quyền hạn hoạt động của Dylib trong App**:
   - Chạy trực tiếp một Server ngầm (HTTP/WebSocket) trên cổng `9090` trong mạng Wi-Fi LAN.
   - Có toàn quyền đọc `StoreKit Products`, trích xuất `sandboxReceipt`, đọc database SQLite nội bộ và bắt trọn gói tin mạng.
   - Nhận lệnh API từ xa (từ iPhone 6s hoặc PC) để tự động bấm nút, gọi mua gói Subscription và kích hoạt popup thanh toán Apple chính chủ.

---

## 🛠️ Biên Dịch Mã Nguồn (Build from Source)

Yêu cầu môi trường Theos (hỗ trợ Linux / WSL / macOS):
```bash
# Thiết lập biến môi trường THEOS
export THEOS=/opt/theos

# Biên dịch toàn bộ Tweak, Dylib, Tool CLI và Preferences Bundle
make clean all

# Đóng gói file deb rootless chuẩn -Zgzip
python3 package_rootless.py

# Cập nhật danh mục kho APT (Packages, Packages.gz, Release)
python3 update_apt_repo.py
```

---

## 👨‍💻 Tác Giả & Bản Quyền
- **StoreSwitcher 2 Core**: Original by subdiox & 0xkuj.
- **Rootless Pro & In-App Agent System**: Phát triển và tối ưu bởi **bunnytaidai**.
