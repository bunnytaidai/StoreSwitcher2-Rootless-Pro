# HƯỚNG DẪN CHI TIẾT SỬ DỤNG HỆ THỐNG AGENT DYLIB, TWEAK & APT REPOSITORY

Hệ thống được thiết kế theo mô hình **Agent - Controller IPC** hai chiều hiện đại, giải quyết toàn bộ các yêu cầu:
1. **`AppAgent.dylib`**: Dynamic Library được tiêm trực tiếp vào các App mục tiêu (Sandbox/UIKit).
2. **`StoreSwitcher` (Tweak)**: Tích hợp bảng điều khiển đồ hoạ (GUI) ngay trên iPhone để quản lý, soi và điều khiển các app đã tiêm.
3. **`agentcli` (Terminal Tool)**: Công cụ dòng lệnh cài đặt tại `/var/jb/usr/bin/agentcli` cho phép điều khiển app từ Terminal (SSH hoặc NewTerm) mọi lúc mọi nơi.
4. **APT Repository (Sileo / Saily / Zebra / Filza)**: Phục vụ cài đặt tự động với đầy đủ gói phụ thuộc.

---

## 1. THÊM NGUỒN VÀO SILEO, SAILY, ZEBRA, CYDIA

- **Địa chỉ kho nguồn APT**:
  ```text
  https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/
  ```

- **Thêm 1 chạm từ trình duyệt Safari trên iPhone**:
  - **Sileo**: `sileo://source/https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/`
  - **Saily**: `saily://add-source?url=https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/`
  - **Zebra**: `zbra://sources/add/https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/`
  - **Cydia**: `cydia://url/https://cydia.saurik.com/api/share#?source=https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/`

---

## 2. HƯỚNG DẪN CÀI ĐẶT FILE `.DEB` BẰNG FILZA FILE MANAGER

1. Mở Safari trên iPhone, tải file deb v2.3.0:
   `https://github.com/bunnytaidai/StoreSwitcher2-Rootless-Pro/raw/main/debs/com.subdiox.storeswitcher2_2.3.0_iphoneos-arm64.deb`
2. Chọn **Mở trong Filza (Open in Filza)**.
3. Bấm vào file `.deb` -> Chọn **Cài đặt (Install)** ở góc trên bên phải màn hình.
4. Chờ Filza chạy script tự động phân quyền `postinst` và hiển thị `Mã thoát: 0`.
5. Bấm **Khởi động lại SpringBoard (Respring)**.

---

## 3. CƠ CHẾ BẢO ĐẢM ĐỦ GÓI PHỤ THUỘC MỚI CHO CÀI (DEPENDENCIES CONTROL)

Gói `.deb` đã được cấu hình chặt chẽ trong file `control`:
```text
Depends: firmware (>= 11.0), mobilesubstrate (>= 0.9.5000) | ellekit, preferenceloader
```
- Khi cài qua Sileo/Saily: Trình quản lý gói sẽ tự động kiểm tra:
  - Nếu máy chưa cài **ElleKit** (hoặc MobileSubstrate), Sileo/Saily sẽ **tự động thêm ElleKit vào hàng đợi để tải và cài đặt cùng lúc**.
  - Nếu thiết bị không thỏa mãn điều kiện firmware hoặc thiếu nền tảng hook, trình quản lý sẽ chặn lại để bảo vệ máy khỏi lỗi văng springboard.

---

## 4. VỊ TRÍ VÀ CÁCH TIÊM FILE `AppAgent.dylib` VÀO APP

- **Vị trí file dylib đã biên dịch**: Nằm ngay tại thư mục gốc repository:
  `AppAgent.dylib` (Universal FAT Mach-O: hỗ trợ cả `arm64` cho chip A9 iPhone 6s và `arm64e`).
- **Cách tiêm vào file .ipa (Không cần Jailbreak / Sideloadly / TrollStore)**:
  - Mở Sideloadly -> Kéo file IPA -> Chọn Advanced Options -> Inject dylibs -> Chọn `AppAgent.dylib` -> Start.
  - Hoặc bằng Azule: `azule -i target.ipa -o injected.ipa -f AppAgent.dylib`.

---

## 5. BẢNG LỆNH TERMINAL (`agentcli`)

Cài đặt sẵn tại `/var/jb/usr/bin/agentcli`. Bạn có thể SSH vào iPhone hoặc mở **NewTerm**:

```bash
agentcli list                             # Liệt kê các app đang chạy có AppAgent
agentcli com.apple.AppStore packets       # Xem packet IAP, Deeplink, API đã bắt
agentcli com.apple.AppStore replay <id>   # Replay (gửi lại) packet
agentcli com.apple.AppStore modify <id> '{...}' # Sửa payload packet
agentcli com.apple.AppStore classes       # Quét Objective-C Classes trong app
agentcli com.apple.AppStore inspect <cls> # Soi methods & properties của Class
agentcli com.apple.AppStore dump-ui       # Dump cây giao diện UI
agentcli com.apple.AppStore click "Nút"   # Bấm nút trên app từ xa
agentcli com.apple.AppStore input "ID" "text" # Nhập chữ vào ô input từ xa
agentcli com.apple.AppStore alert "Tiêu đề" "Nội dung" # Bắn Popup Alert vào app
agentcli com.apple.AppStore overlay       # Bật/Tắt Live HUD Sniffer nổi trên app
agentcli com.apple.AppStore open-url "url" # Kích hoạt mở Deeplink
```
