#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script tự động quét file .deb và tạo APT Repository (Cydia, Sileo, Zebra) chuẩn RFC.
Hỗ trợ đầy đủ Packages, Packages.gz, Packages.bz2, Packages.xz và Release.
"""

import os
import io
import gzip
import bz2
import lzma
import hashlib
import tarfile
import shutil

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DEBS_DIR = os.path.join(BASE_DIR, "debs")
PACKAGES_DIR = os.path.join(BASE_DIR, "dist")

os.makedirs(DEBS_DIR, exist_ok=True)

# Copy file .deb mới từ packages/ sang debs/
if os.path.exists(PACKAGES_DIR):
    for f in os.listdir(PACKAGES_DIR):
        if f.endswith(".deb"):
            src = os.path.join(PACKAGES_DIR, f)
            dst = os.path.join(DEBS_DIR, f)
            shutil.copy2(src, dst)
            print(f"[+] Đồng bộ: {f} -> debs/")

def get_hash(filepath, algo):
    h = hashlib.new(algo)
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def extract_control_from_deb(deb_path):
    """Trích xuất file control từ Debian package (.deb)"""
    with open(deb_path, "rb") as f:
        magic = f.read(8)
        if magic != b"!<arch>\n":
            raise ValueError(f"File không đúng định dạng ar .deb: {deb_path}")
        
        while True:
            header = f.read(60)
            if len(header) < 60:
                break
            name = header[:16].decode('ascii', errors='ignore').strip().rstrip('/')
            size = int(header[48:58].decode('ascii', errors='ignore').strip())
            file_data = f.read(size)
            if size % 2 != 0:
                f.read(1) # padding byte
            
            if name.startswith("control.tar"):
                # Mở tar archive
                if name == "control.tar.gz":
                    tar_bytes = gzip.decompress(file_data)
                elif name == "control.tar.xz":
                    tar_bytes = lzma.decompress(file_data)
                elif name == "control.tar.bz2":
                    tar_bytes = bz2.decompress(file_data)
                else:
                    tar_bytes = file_data
                
                with tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:*") as tar:
                    for member in tar.getmembers():
                        if member.name in ("control", "./control"):
                            f_ctrl = tar.extractfile(member)
                            if f_ctrl:
                                return f_ctrl.read().decode('utf-8', errors='ignore').strip()
    return None

packages_entries = []
deb_files = sorted([f for f in os.listdir(DEBS_DIR) if f.endswith(".deb")])

for deb_name in deb_files:
    deb_path = os.path.join(DEBS_DIR, deb_name)
    ctrl = extract_control_from_deb(deb_path)
    if not ctrl:
        print(f"[-] Không đọc được control từ: {deb_name}")
        continue
    
    size = os.path.getsize(deb_path)
    md5 = get_hash(deb_path, "md5")
    sha1 = get_hash(deb_path, "sha1")
    sha256 = get_hash(deb_path, "sha256")
    rel_path = f"debs/{deb_name}"
    
    entry = f"{ctrl}\nFilename: {rel_path}\nSize: {size}\nMD5sum: {md5}\nSHA1: {sha1}\nSHA256: {sha256}\n"
    packages_entries.append(entry)

packages_content = "\n".join(packages_entries) + "\n"
packages_bytes = packages_content.encode("utf-8")

# 1. Ghi file Packages
packages_path = os.path.join(BASE_DIR, "Packages")
with open(packages_path, "wb") as f:
    f.write(packages_bytes)

# 2. Ghi file Packages.gz
with open(os.path.join(BASE_DIR, "Packages.gz"), "wb") as f:
    f.write(gzip.compress(packages_bytes))

# 3. Ghi file Packages.bz2
with open(os.path.join(BASE_DIR, "Packages.bz2"), "wb") as f:
    f.write(bz2.compress(packages_bytes))

# 4. Ghi file Packages.xz
with open(os.path.join(BASE_DIR, "Packages.xz"), "wb") as f:
    f.write(lzma.compress(packages_bytes))

# 5. Ghi file Release
release_info = [
    "Origin: StoreSwitcher Pro Repo",
    "Label: StoreSwitcher Pro",
    "Suite: stable",
    "Version: 2.3.0",
    "Codename: ios",
    "Architectures: iphoneos-arm64 iphoneos-arm",
    "Components: main",
    "Description: Official StoreSwitcher 2 Pro & AppAgent Repository by bunnytaidai",
    "MD5Sum:"
]

for p_name in ["Packages", "Packages.gz", "Packages.bz2", "Packages.xz"]:
    p_path = os.path.join(BASE_DIR, p_name)
    release_info.append(f" {get_hash(p_path, 'md5')} {os.path.getsize(p_path)} {p_name}")

release_info.append("SHA1:")
for p_name in ["Packages", "Packages.gz", "Packages.bz2", "Packages.xz"]:
    p_path = os.path.join(BASE_DIR, p_name)
    release_info.append(f" {get_hash(p_path, 'sha1')} {os.path.getsize(p_path)} {p_name}")

release_info.append("SHA256:")
for p_name in ["Packages", "Packages.gz", "Packages.bz2", "Packages.xz"]:
    p_path = os.path.join(BASE_DIR, p_name)
    release_info.append(f" {get_hash(p_path, 'sha256')} {os.path.getsize(p_path)} {p_name}")

release_content = "\n".join(release_info) + "\n"
with open(os.path.join(BASE_DIR, "Release"), "w", encoding="utf-8") as f:
    f.write(release_content)

# 6. Ghi file .nojekyll để GitHub Pages phục vụ file gz/bz2/xz
with open(os.path.join(BASE_DIR, ".nojekyll"), "w") as f:
    f.write("")

# 7. Sileo Native Repo config
sileo_json = """{
  "name": "StoreSwitcher Pro Repo",
  "icon": "https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/CydiaIcon.png",
  "description": "Kho tweak StoreSwitcher 2 Pro & AppAgent iOS 11 - 15.8.x Rootless / Rootful",
  "tintColor": "#00E676",
  "featured": {
    "banners": [
      {
        "title": "StoreSwitcher 2 Pro & AppAgent",
        "hideShadow": false,
        "url": "https://bunnytaidai.github.io/StoreSwitcher2-Rootless-Pro/",
        "package": "com.subdiox.storeswitcher2"
      }
    ]
  }
}
"""
with open(os.path.join(BASE_DIR, "sileo.json"), "w", encoding="utf-8") as f:
    f.write(sileo_json)

print(f"[✓] Đã tạo thành công APT Repo với {len(deb_files)} gói .deb!")
