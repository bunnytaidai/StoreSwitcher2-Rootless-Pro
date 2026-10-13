#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
StoreSwitcher 2 Pro - Debian Package (.deb) & APT Repo Builder
Hỗ trợ iOS 15.x Rootless (iphoneos-arm64 / Dopamine / Palera1n)
Đóng gói chuẩn Debian ar archive không phụ thuộc dpkg-deb trên Windows.
"""

import os
import sys
import io
import time
import gzip
import tarfile
import hashlib
import shutil

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def get_control_field(field_name, default=""):
    control_path = os.path.join(BASE_DIR, "control")
    if os.path.exists(control_path):
        with open(control_path, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith(f"{field_name}:"):
                    return line.split(":", 1)[1].strip()
    return default

PKG_NAME = get_control_field("Package", "com.subdiox.storeswitcher2")
PKG_VERSION = get_control_field("Version", "2.2.1")
PKG_ARCH = get_control_field("Architecture", "iphoneos-arm64")
DEB_FILENAME = f"{PKG_NAME}_{PKG_VERSION}_{PKG_ARCH}.deb"

OUTPUT_PACKAGES_DIR = os.path.join(BASE_DIR, "packages")
OUTPUT_REPO_DIR = os.path.join(BASE_DIR, "repo")
DEBS_DIR = os.path.join(OUTPUT_REPO_DIR, "debs")

os.makedirs(OUTPUT_PACKAGES_DIR, exist_ok=True)
os.makedirs(DEBS_DIR, exist_ok=True)

def create_ar_archive(output_path, files):
    """
    Tạo tệp ar format chuẩn (Debian .deb container).
    Mỗi file trong `files` là tuple: (name, bytes_data, mode)
    """
    with open(output_path, "wb") as f:
        # Magic header của định dạng ar
        f.write(b"!<arch>\n")
        
        for name, data, mode in files:
            # File header (60 bytes)
            # name: 16 bytes, mod_time: 12 bytes, uid: 6 bytes, gid: 6 bytes, mode: 8 bytes, size: 10 bytes, magic: 2 bytes
            name_padded = (name + "/").ljust(16)[:16].encode('ascii')
            mtime = str(int(time.time())).ljust(12)[:12].encode('ascii')
            uid = b"0".ljust(6)
            gid = b"0".ljust(6)
            mode_oct = oct(mode).ljust(8)[:8].encode('ascii')
            size_str = str(len(data)).ljust(10)[:10].encode('ascii')
            fmagic = b"`\n"
            
            header = name_padded + mtime + uid + gid + mode_oct + size_str + fmagic
            f.write(header)
            f.write(data)
            
            # Căn chỉnh chẵn byte (2-byte alignment)
            if len(data) % 2 != 0:
                f.write(b"\n")

def build_control_tar():
    """Tạo control.tar.gz chứa control, postinst, prerm"""
    control_src = os.path.join(BASE_DIR, "control")
    with open(control_src, "rb") as f:
        control_data = f.read()

    postinst_src = os.path.join(BASE_DIR, "DEBIAN", "postinst")
    postinst_data = b""
    if os.path.exists(postinst_src):
        with open(postinst_src, "rb") as f:
            postinst_data = f.read().replace(b"\r\n", b"\n")

    prerm_src = os.path.join(BASE_DIR, "DEBIAN", "prerm")
    prerm_data = b""
    if os.path.exists(prerm_src):
        with open(prerm_src, "rb") as f:
            prerm_data = f.read().replace(b"\r\n", b"\n")

    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        # 1. ./control
        ti = tarfile.TarInfo(name="./control")
        ti.size = len(control_data)
        ti.mode = 0o644
        ti.uid = ti.gid = 0
        ti.uname = ti.gname = "root"
        ti.mtime = int(time.time())
        tar.addfile(ti, io.BytesIO(control_data))

        # 2. ./postinst
        if postinst_data:
            ti = tarfile.TarInfo(name="./postinst")
            ti.size = len(postinst_data)
            ti.mode = 0o755
            ti.uid = ti.gid = 0
            ti.uname = ti.gname = "root"
            ti.mtime = int(time.time())
            tar.addfile(ti, io.BytesIO(postinst_data))

        # 3. ./prerm
        if prerm_data:
            ti = tarfile.TarInfo(name="./prerm")
            ti.size = len(prerm_data)
            ti.mode = 0o755
            ti.uid = ti.gid = 0
            ti.uname = ti.gname = "root"
            ti.mtime = int(time.time())
            tar.addfile(ti, io.BytesIO(prerm_data))

    return buf.getvalue()

def build_data_tar():
    """Tạo data.tar.gz chứa cấu trúc rootless /var/jb/..."""
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        def add_dir(path, mode=0o755):
            ti = tarfile.TarInfo(name=path)
            ti.type = tarfile.DIRTYPE
            ti.mode = mode
            ti.uid = ti.gid = 0
            ti.uname = ti.gname = "root"
            ti.mtime = int(time.time())
            tar.addfile(ti)

        def add_file(arcname, local_path, mode=0o644):
            if not os.path.exists(local_path):
                return
            with open(local_path, "rb") as f:
                content = f.read()
            ti = tarfile.TarInfo(name=arcname)
            ti.size = len(content)
            ti.mode = mode
            ti.uid = ti.gid = 0
            ti.uname = ti.gname = "root"
            ti.mtime = int(time.time())
            tar.addfile(ti, io.BytesIO(content))

        # Thư mục gốc
        add_dir("./")
        add_dir("./Library")
        add_dir("./Library/MobileSubstrate")
        add_dir("./Library/MobileSubstrate/DynamicLibraries")
        add_dir("./Library/Application Support")
        add_dir("./Library/Application Support/StoreSwitcher")
        add_dir("./var")
        add_dir("./var/mobile")
        add_dir("./var/mobile/Library")
        add_dir("./var/mobile/Library/StoreSwitcher")

        # 1. Filter plist nạp vào AppStore
        add_file("./Library/MobileSubstrate/DynamicLibraries/StoreSwitcher.plist",
                 os.path.join(BASE_DIR, "StoreSwitcher.plist"), 0o644)

        # 2. Icons
        icons_dir = os.path.join(BASE_DIR, "layout", "Library", "Application Support", "StoreSwitcher")
        if os.path.exists(icons_dir):
            for icon in os.listdir(icons_dir):
                add_file(f"./Library/Application Support/StoreSwitcher/{icon}",
                         os.path.join(icons_dir, icon), 0o644)

        # 3. Control Station Web & API Daemon
        add_file("./var/mobile/Library/StoreSwitcher/storeswitcher_api.py",
                 os.path.join(BASE_DIR, "storeswitcher_api.py"), 0o755)
        add_file("./var/mobile/Library/StoreSwitcher/control_panel.html",
                 os.path.join(BASE_DIR, "control_panel.html"), 0o644)
        add_file("./var/mobile/Library/StoreSwitcher/preview.html",
                 os.path.join(BASE_DIR, "preview.html"), 0o644)

        # 4. File cấu hình mặc định an toàn (tránh lỗi khi mở app)
        default_cfg = b'{"autoFillPassword":true,"bypassReauth":true,"autoConfirm":true,"targetPackage":"chrome30tb"}'
        ti = tarfile.TarInfo(name="./var/mobile/Library/StoreSwitcher/config.json")
        ti.size = len(default_cfg)
        ti.mode = 0o600
        ti.uid = ti.gid = 0
        ti.uname = ti.gname = "root"
        ti.mtime = int(time.time())
        tar.addfile(ti, io.BytesIO(default_cfg))

    return buf.getvalue()

def build_deb_package():
    print(f"[*] Đang đóng gói tệp Debian package: {DEB_FILENAME}...")
    
    debian_binary = b"2.0\n"
    control_tar_gz = build_control_tar()
    data_tar_gz = build_data_tar()

    files = [
        ("debian-binary", debian_binary, 0o644),
        ("control.tar.gz", control_tar_gz, 0o644),
        ("data.tar.gz", data_tar_gz, 0o644)
    ]

    target_deb = os.path.join(OUTPUT_PACKAGES_DIR, DEB_FILENAME)
    create_ar_archive(target_deb, files)
    
    # Sao chép vào repo/debs/ để sẵn sàng làm Cydia/Sileo Repo
    repo_deb = os.path.join(DEBS_DIR, DEB_FILENAME)
    shutil.copy2(target_deb, repo_deb)

    deb_size = os.path.getsize(target_deb)
    with open(target_deb, "rb") as f:
        deb_bytes = f.read()
    md5 = hashlib.md5(deb_bytes).hexdigest()
    sha1 = hashlib.sha1(deb_bytes).hexdigest()
    sha256 = hashlib.sha256(deb_bytes).hexdigest()

    print(f"[✓] Đã tạo thành công file .deb: {target_deb}")
    print(f"    • Dung lượng: {deb_size} bytes")
    print(f"    • MD5: {md5}")
    print(f"    • SHA256: {sha256}")
    
    return target_deb, deb_size, md5, sha1, sha256

def build_cydia_sileo_repo(deb_size, md5, sha1, sha256):
    """Tạo các file chỉ mục Packages, Packages.gz và Release cho Cydia/Sileo Repo"""
    print("[*] Đang khởi tạo cấu trúc Cydia / Sileo APT Repository...")
    
    with open(os.path.join(BASE_DIR, "control"), "r", encoding="utf-8") as f:
        control_text = f.read().strip()

    package_entry = f"{control_text}\n"
    package_entry += f"Filename: debs/{DEB_FILENAME}\n"
    package_entry += f"Size: {deb_size}\n"
    package_entry += f"MD5sum: {md5}\n"
    package_entry += f"SHA1: {sha1}\n"
    package_entry += f"SHA256: {sha256}\n\n"

    # 1. Packages
    packages_path = os.path.join(OUTPUT_REPO_DIR, "Packages")
    with open(packages_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(package_entry)

    # 2. Packages.gz
    packages_gz_path = os.path.join(OUTPUT_REPO_DIR, "Packages.gz")
    with gzip.open(packages_gz_path, "wb") as f:
        f.write(package_entry.encode("utf-8"))

    # 3. Release file
    release_content = (
        "Origin: StoreSwitcher 2 Pro Repo\n"
        "Label: StoreSwitcher2\n"
        "Suite: stable\n"
        "Version: 2.2.0\n"
        "Codename: ios\n"
        "Architectures: iphoneos-arm64\n"
        "Components: main\n"
        "Description: Kho lưu trữ chính thức StoreSwitcher 2 Pro cho iOS 15 Rootless (iPhone 6s, Dopamine, Palera1n).\n"
    )
    release_path = os.path.join(OUTPUT_REPO_DIR, "Release")
    with open(release_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(release_content)

    # 4. Sao chép CydiaIcon nếu có
    icon_src = os.path.join(BASE_DIR, "layout", "Library", "Application Support", "StoreSwitcher", "switcher@2x.png")
    if os.path.exists(icon_src):
        shutil.copy2(icon_src, os.path.join(OUTPUT_REPO_DIR, "CydiaIcon.png"))

    # 5. Tạo trang web chào mừng Sileo/Zebra (index.html)
    index_html_content = f"""<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>StoreSwitcher 2 Pro • Official APT Repo</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0b0f19; color: #fff; margin: 0; padding: 20px; display: flex; justify-content: center; align-items: center; min-height: 100vh; }}
    .card {{ background: rgba(15, 23, 42, 0.9); border: 1px solid rgba(255,255,255,0.1); border-radius: 18px; padding: 28px; max-width: 460px; width: 100%; box-shadow: 0 20px 50px rgba(0,0,0,0.6); text-align: center; }}
    h1 {{ font-size: 22px; font-weight: 800; margin-bottom: 6px; background: linear-gradient(135deg, #a855f7, #38bdf8); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }}
    p {{ font-size: 13px; color: #94a3b8; line-height: 1.5; }}
    .btn {{ display: inline-flex; align-items: center; justify-content: center; gap: 8px; width: 100%; padding: 14px; margin-top: 12px; border-radius: 12px; font-weight: 700; text-decoration: none; font-size: 14px; transition: transform 0.15s; box-sizing: border-box; }}
    .btn-sileo {{ background: linear-gradient(135deg, #007aff, #00c6ff); color: #fff; }}
    .btn-zebra {{ background: linear-gradient(135deg, #8b5cf6, #ec4899); color: #fff; }}
    .btn-deb {{ background: rgba(255,255,255,0.08); color: #e2e8f0; border: 1px solid rgba(255,255,255,0.15); }}
    .btn:hover {{ transform: translateY(-2px); }}
    .tag {{ background: rgba(16, 185, 129, 0.2); color: #34d399; font-size: 11px; padding: 4px 10px; border-radius: 20px; font-weight: 700; display: inline-block; margin-bottom: 12px; }}
  </style>
</head>
<body>
  <div class="card">
    <div class="tag">● iOS 15.0 - 15.8.8 Rootless Ready</div>
    <h1>StoreSwitcher 2 Pro Repo</h1>
    <p>Kho Cydia & Sileo chính thức của Tweak StoreSwitcher 2 Pro (Tráo nick RAM, Quản lý Sandbox In-App, Live Sniffer URL Scheme & SQLite Realtime).</p>
    
    <a class="btn btn-sileo" href="sileo://source/https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/">
      <span>⚡</span> Thêm Nguồn vào Sileo
    </a>
    <a class="btn btn-zebra" href="zbra://sources/add/https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/">
      <span>🦓</span> Thêm Nguồn vào Zebra
    </a>
    <a class="btn btn-deb" href="debs/{DEB_FILENAME}">
      <span>📥</span> Tải Trực Tiếp File .DEB ({PKG_VERSION})
    </a>
  </div>
</body>
</html>"""
    with open(os.path.join(OUTPUT_REPO_DIR, "index.html"), "w", encoding="utf-8") as f:
        f.write(index_html_content)

    print("[✓] Đã tạo thành công APT Repo (Packages, Packages.gz, Release, index.html)!")

if __name__ == "__main__":
    deb_path, size, md5, sha1, sha256 = build_deb_package()
    build_cydia_sileo_repo(size, md5, sha1, sha256)
    print("\n[🎉] HOÀN TẤT BIÊN DỊCH VÀ ĐÓNG GÓI DEB:")
    print(f"     1. File .deb: {deb_path}")
    print(f"     2. Sileo/Cydia Repo: {OUTPUT_REPO_DIR}")
