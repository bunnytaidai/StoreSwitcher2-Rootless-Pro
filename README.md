# StoreSwitcher 2 Pro & AppAgent (v2.3.0)
### ⚡ Quick Apple ID Switcher, Sandbox In-App Manager, Live URL Sniffer, Objective-C Runtime Inspector & IPC Agent for iOS 11 - 15.8.x

Kho lưu trữ chính thức hỗ trợ **Rootless** (Dopamine, Palera1n) trên chip **A9 (iPhone 6s/6s Plus/SE 1)** và các dòng chip mới **A12+**, đồng thời hỗ trợ cả thiết bị **Rootful**.

---

## 🌐 1. Thêm Nguồn Vào Thiết Bị (APT Repository)

Địa chỉ nguồn chính thức:
```text
https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/
```

### Thao tác thêm nguồn 1 chạm trên iPhone:
- **⚡ Thêm vào Sileo**: [`sileo://source/https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/`](sileo://source/https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/)
- **⛵ Thêm vào Saily**: [`saily://add-source?url=https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/`](saily://add-source?url=https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/)
- **🦓 Thêm vào Zebra**: [`zbra://sources/add/https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/`](zbra://sources/add/https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/)
- **📦 Thêm vào Cydia**: [`cydia://url/https://cydia.saurik.com/api/share#?source=https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/`](cydia://url/https://cydia.saurik.com/api/share#?source=https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/)

---

## 📁 2. Hướng Dẫn Cài Đặt File `.deb` Bằng Filza File Manager

Nếu bạn không muốn thêm nguồn mà muốn cài file `.deb` thủ công:

1. Dùng trình duyệt Safari trên iPhone tải file `.deb`:
   👉 [**Tải file com.subdiox.storeswitcher2_2.3.0_iphoneos-arm64.deb**](https://github.com/bunnytaidai/StoreSwitcher2-Rootless-Pro/raw/main/debs/com.subdiox.storeswitcher2_2.3.0_iphoneos-arm64.deb)
2. Sau khi tải xong, bấm nút Share và chọn **Mở trong "Filza" (Open in Filza)**.
3. Chạm vào file `.deb` vừa tải trong Filza -> Chọn **Cài đặt (Install)** ở góc trên bên phải.
4. Màn hình Console của Filza sẽ hiển thị:
   ```text
   Selecting previously unselected package com.subdiox.storeswitcher2.
   (Reading database ... 2548 files and directories currently installed.)
   Preparing to unpack com.subdiox.storeswitcher2_2.3.0_iphoneos-arm64.deb ...
   Unpacking com.subdiox.storeswitcher2 (2.3.0) ...
   Setting up com.subdiox.storeswitcher2 (2.3.0) ...
   Mã thoát: 0
   ```
5. Khi thấy dòng **`Mã thoát: 0` (Exit code: 0)**, bấm nút **Khởi động lại SpringBoard (Respring)**. Tweak và Dylib sẽ kích hoạt ngay lập tức!

---

## 🛡️ 3. Cấu Hình Gói Phụ Thuộc (Dependencies - Đủ Mới Cài)

File `control` và hệ thống APT Repository được thiết lập các ràng buộc phụ thuộc nghiêm ngặt để đảm bảo tweak hoạt động 100% không bị văng app (crash):

```text
Package: com.subdiox.storeswitcher2
Name: StoreSwitcher 2 Pro & AppAgent
Depends: firmware (>= 11.0), mobilesubstrate (>= 0.9.5000) | ellekit, preferenceloader
Version: 2.3.0
Architecture: iphoneos-arm64
```

- **`firmware (>= 11.0)`**: Yêu cầu iOS 11.0 trở lên (hỗ trợ hoàn hảo iOS 15.8.8 trên iPhone 6s A9).
- **`mobilesubstrate | ellekit`**: Đảm bảo thiết bị đã cài Substrate hoặc ElleKit (trên Dopamine). Nếu thiếu, Sileo/Saily sẽ **chặn cài đặt hoặc tự động kéo ElleKit về cài trước**.
- **`preferenceloader`**: Thành phần hiển thị cài đặt tweak.
- **Script `postinst` & `prerm`**: Tự động phân quyền `chmod 0755` và làm mới tiến trình sau khi cài.

---

## 🧩 4. File `.dylib` Để Tiêm Vào App

File dynamic library độc lập được lưu trữ ngay tại thư mục gốc repository:
- **`AppAgent.dylib`**: Mach-O Universal FAT Binary (hỗ trợ cả **`arm64`** cho iPhone 6s A9 và **`arm64e`** cho chip mới).
- **`AppAgent.plist`**: File filter tự động nạp vào UIKit.

### Hai cách tiêm Dylib:
1. **Qua Cydia Substrate / ElleKit**: Tự động tiêm khi cài đặt gói `.deb`.
2. **Tiêm vào file IPA không cần Jailbreak (TrollStore / Sideloadly / Azule)**:
   ```bash
   azule -i OriginalApp.ipa -o InjectedApp.ipa -f AppAgent.dylib
   ```

---

## ⚡ 5. Điều Khiển Bằng Lệnh Terminal (`agentcli`)

Cài đặt tự động tại `/var/jb/usr/bin/agentcli`. Bạn có thể SSH vào iPhone hoặc mở **NewTerm**:

```bash
agentcli list                             # Liệt kê các app đang chạy có AppAgent
agentcli com.apple.AppStore packets       # Xem packet IAP, Deeplink, API đã bắt
agentcli com.apple.AppStore replay <id>   # Replay (gửi lại) packet
agentcli com.apple.AppStore classes       # Quét Objective-C Classes trong app
agentcli com.apple.AppStore inspect <cls> # Soi methods & properties của Class
agentcli com.apple.AppStore dump-ui       # Dump cây giao diện UI
agentcli com.apple.AppStore click "Nút"   # Bấm nút trên app từ xa
agentcli com.apple.AppStore overlay       # Bật/Tắt Live HUD Sniffer nổi trên app
```

---

## 📱 6. Điều Khiển Bằng Giao Diện Đồ Họa (GUI Tweak)

1. Mở App Store, bấm nút StoreSwitcher.
2. Bấm vào nút **`⚡ Agent`** ở góc trên bên trái thanh điều hướng để mở bảng điều khiển trực tiếp trên iPhone.
