# StoreSwitcher 2 Pro (iOS 15 Rootless Pro)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: iOS 15.0 - 15.8.8](https://img.shields.io/badge/Platform-iOS%2015.0%20--%2015.8.8%20Rootless-blue.svg)](https://github.com/bunnytaidai/StoreSwitcher2-Rootless-Pro)
[![Architecture: arm64](https://img.shields.io/badge/Architecture-iphoneos--arm64-green.svg)](https://github.com/bunnytaidai/StoreSwitcher2-Rootless-Pro)
[![Package Version: 2.2.0](https://img.shields.io/badge/Version-2.2.0-purple.svg)](https://github.com/bunnytaidai/StoreSwitcher2-Rootless-Pro/releases)

Tweak chuyển đổi tài khoản Apple ID siêu tốc, tráo nick ngầm trên RAM (Soft Swap), gọi Native GUI Quản lý mục đăng ký Sandbox TestFlight, Live Sniffer bắt URL Scheme/Deep Link và đồng bộ cơ sở dữ liệu SQLite hai chiều thời gian thực qua WebSocket.

Được tối ưu hóa chuyên biệt cho **iPhone 6s chip Apple A9 chạy iOS 15.8.8 Rootless** (Dopamine, Palera1n, XinaA15).

---

## ⚡ Các Tính Năng Cốt Lõi

1. **Tráo Nick Ngầm Trên RAM (Zero Disk Write Soft Swap):**
   - Giả lập con trỏ tài khoản `activeAccount` của `SSAccountStore` trực tiếp trên bộ nhớ RAM.
   - Tuyệt đối không ghi đè `Accounts3.sqlite` và không kill tiến trình `akd`, triệt tiêu 100% cảnh báo phiên đăng nhập hết hạn và bypass 2FA OTP.
2. **Gọi Native GUI Quản Lý Mục Đăng Ký Sandbox:**
   - Kích hoạt trực tiếp Native Sheet của iOS thông qua StoreKit 2 URL Scheme:
     `itms-apps://apps.apple.com/account/manage-subscriptions`
   - Hiển thị đầy đủ thông số gói đăng ký: Logo, Tên gói, Nhà phát triển, Chu kỳ, Quyền lợi chi tiết và popup xác nhận mua StoreKit 2.
3. **Cấu Hình Chọn Gói Mua Chi Tiết (In-App Target Packages):**
   - **Google AI Ultra (30 TB) - Google Chrome:** 5.500.000 đ/tháng (30TB lưu trữ Google One, Gemini 1.5 Pro AI).
   - **GitHub Copilot Pro Monthly:** 999.000 đ/tháng (AI Pair Programmer, Claude 3.5 Sonnet & GPT-4o).
   - **VIP Tester Pass (Sandbox):** $4.99/tháng (Ưu tiên tải trước bản thử nghiệm).
   - **Custom In-App:** Cho phép nhập tùy ý Product ID và Bundle ID.
4. **Bộ Thu & Bắt URL Scheme / Deep Link Thời Gian Thực (Live Sniffer):**
   - Nút Master BẬT/TẮT thu bắt liên tục các thao tác mở link từ cả bên trong và bên ngoài Tweak (App Store, Cài đặt Settings, TestFlight, Safari, SpringBoard...).
   - Bảng bóc tách, giải mã từng tham số: Scheme, Host, Path, Action, Bundle ID, Product Identifier.
5. **Cơ Sở Dữ Liệu SQLite & Bảo Mật chmod 0600:**
   - Lưu trữ toàn bộ tài khoản, Token AuthKit, DSID, AltDSID và nhật ký giao dịch trong `storeswitcher.db`.
   - Phân quyền nghiêm ngặt `chmod 0600` chống rò rỉ dữ liệu sang ứng dụng Sandbox khác.
6. **Kênh Truyền WebSocket 2 Chiều (Port 8096) & REST API (Port 8095):**
   - Đồng bộ thời gian thực giữa iPhone và Bảng điều khiển Web (`control_panel.html`) mà không cần tải lại trang.

---

## 📦 Cài Đặt Gói .DEB (Không Bao Giờ Bị Lỗi Phụ Thuộc)

Gói `.deb` đã được chuẩn hóa với các trường dependencies an toàn nhất cho mọi bản Jailbreak Rootless:

```control
Package: com.subdiox.storeswitcher2
Name: StoreSwitcher 2 (iOS 15 Rootless Pro)
Depends: firmware (>= 15.0), ellekit | mobilesubstrate (>= 0.9.5000), preferenceloader
Recommends: sqlite3, curl
Version: 2.2.0
Architecture: iphoneos-arm64
Section: Tweaks
```

### Cách 1: Thêm Nguồn (Repo) Trực Tiếp Vào Sileo / Zebra
1. Mở ứng dụng **Sileo** hoặc **Zebra** trên iPhone.
2. Vào mục **Nguồn (Sources)** -> Bấm **+ (Thêm)**.
3. Nhập URL Repo:
   ```text
   https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/
   ```
4. Tìm kiếm `StoreSwitcher 2` và bấm **Cài đặt (Get -> Install)**.

### Cách 2: Cài Đặt Trực Tiếp File .deb
1. Tải file deb mới nhất trong thư mục `packages/`:
   - [`com.subdiox.storeswitcher2_2.2.0_iphoneos-arm64.deb`](packages/com.subdiox.storeswitcher2_2.2.0_iphoneos-arm64.deb)
2. Mở bằng **Filza File Manager** hoặc chạy lệnh Terminal:
   ```bash
   dpkg -i com.subdiox.storeswitcher2_2.2.0_iphoneos-arm64.deb
   killall -9 AppStore
   ```

---

## 🛠️ Biên Dịch Bằng Theos (Dành Cho Lập Trình Viên)

Nếu bạn muốn tự biên dịch dylib từ mã nguồn trên máy Mac hoặc trực tiếp trên iPhone:

```bash
# Đảm bảo đã export biến môi trường THEOS
export THEOS=/var/jb/var/mobile/theos
export THEOS_PACKAGE_SCHEME=rootless

# Biên dịch và đóng gói deb
make clean
make package FINALPACKAGE=1
```

Hoặc sử dụng công cụ đóng gói nhanh Python độc lập:
```bash
py build_deb.py
```

---

## 📱 Cấu Trúc Thư Mục Rootless Trên iPhone (/var/jb)

```text
/var/jb/
├── Library/
│   ├── MobileSubstrate/DynamicLibraries/
│   │   ├── StoreSwitcher.dylib     # Hook Engine ElleKit
│   │   └── StoreSwitcher.plist     # Filter com.apple.AppStore
│   └── Application Support/
│       └── StoreSwitcher/          # Icon & Assets
└── var/mobile/Library/StoreSwitcher/
    ├── storeswitcher.db            # Cơ sở dữ liệu SQLite (chmod 0600)
    ├── storeswitcher_api.py        # REST API (8095) & WebSocket (8096)
    ├── control_panel.html          # Bảng điều khiển Control Station
    └── config.json                 # Cấu hình lưu trữ
```

---

## 👤 Tác Giả & Bản Quyền

- **Original Author:** subdiox
- **Rootless Pro & In-App Sniffer Upgrade:** [Rabbit_Supper (bunnytaidai)](https://github.com/bunnytaidai)
- **License:** MIT License
