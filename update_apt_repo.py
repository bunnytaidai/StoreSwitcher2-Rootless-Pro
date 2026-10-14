import os
import hashlib
import gzip
import bz2
import lzma
import tarfile
import io

REPO_DIR = os.path.dirname(os.path.abspath(__file__))
DEBS_DIR = os.path.join(REPO_DIR, "debs")

def get_hashes(filepath):
    with open(filepath, "rb") as f:
        data = f.read()
    return {
        "size": len(data),
        "md5": hashlib.md5(data).hexdigest(),
        "sha1": hashlib.sha1(data).hexdigest(),
        "sha256": hashlib.sha256(data).hexdigest(),
    }

def extract_control_from_deb(deb_path):
    # .deb is an ar archive. Format: '!<arch>\n' then members
    with open(deb_path, "rb") as f:
        magic = f.read(8)
        if magic != b"!<arch>\n":
            raise ValueError(f"Not an ar archive: {deb_path}")
        while True:
            header = f.read(60)
            if len(header) < 60:
                break
            name = header[0:16].decode("ascii", errors="ignore").strip()
            size_str = header[48:58].decode("ascii", errors="ignore").strip()
            size = int(size_str)
            data = f.read(size)
            if size % 2 != 0:
                f.read(1) # padding byte

            if name.startswith("control.tar"):
                # can be control.tar.gz, control.tar.xz, control.tar.zst
                stream = io.BytesIO(data)
                mode = "r:*"
                with tarfile.open(fileobj=stream, mode=mode) as tar:
                    for member in tar.getmembers():
                        if member.name.endswith("control") or member.name == "./control":
                            cf = tar.extractfile(member)
                            if cf:
                                return cf.read().decode("utf-8", errors="replace")
    return ""

def main():
    print(f"Scanning debs in {DEBS_DIR}...")
    deb_files = sorted([f for f in os.listdir(DEBS_DIR) if f.endswith(".deb")])
    packages_entries = []

    for deb_name in deb_files:
        deb_path = os.path.join(DEBS_DIR, deb_name)
        h = get_hashes(deb_path)
        control_content = extract_control_from_deb(deb_path)
        
        # Clean control content
        lines = [line.strip() for line in control_content.strip().splitlines() if line.strip()]
        
        entry = "\n".join(lines)
        entry += f"\nFilename: debs/{deb_name}"
        entry += f"\nSize: {h['size']}"
        entry += f"\nMD5sum: {h['md5']}"
        entry += f"\nSHA1: {h['sha1']}"
        entry += f"\nSHA256: {h['sha256']}\n"
        
        packages_entries.append(entry)
        print(f"  + Added {deb_name} ({h['size']} bytes, SHA256: {h['sha256'][:12]}...)")

    packages_text = "\n".join(packages_entries) + "\n"
    packages_bytes = packages_text.encode("utf-8")

    # Write Packages
    pkg_file = os.path.join(REPO_DIR, "Packages")
    with open(pkg_file, "wb") as f:
        f.write(packages_bytes)

    # Write Packages.gz
    gz_file = os.path.join(REPO_DIR, "Packages.gz")
    with gzip.open(gz_file, "wb") as f:
        f.write(packages_bytes)

    # Write Packages.bz2
    bz2_file = os.path.join(REPO_DIR, "Packages.bz2")
    with bz2.open(bz2_file, "wb") as f:
        f.write(packages_bytes)

    # Write Packages.xz
    xz_file = os.path.join(REPO_DIR, "Packages.xz")
    with lzma.open(xz_file, "wb") as f:
        f.write(packages_bytes)

    print("Generated Packages, Packages.gz, Packages.bz2, Packages.xz.")

    # Calculate hashes of Packages files for Release
    targets = ["Packages", "Packages.gz", "Packages.bz2", "Packages.xz"]
    file_hashes = {}
    for t in targets:
        file_hashes[t] = get_hashes(os.path.join(REPO_DIR, t))

    release_content = """Origin: StoreSwitcher Pro Repo
Label: StoreSwitcher Pro
Suite: stable
Version: 2.4.0
Codename: ios
Architectures: iphoneos-arm64 iphoneos-arm
Components: main
Description: Official StoreSwitcher 2 Pro & AppAgent Repository by bunnytaidai
MD5Sum:
"""
    for t in targets:
        fh = file_hashes[t]
        release_content += f" {fh['md5']} {fh['size']} {t}\n"

    release_content += "SHA1:\n"
    for t in targets:
        fh = file_hashes[t]
        release_content += f" {fh['sha1']} {fh['size']} {t}\n"

    release_content += "SHA256:\n"
    for t in targets:
        fh = file_hashes[t]
        release_content += f" {fh['sha256']} {fh['size']} {t}\n"

    rel_file = os.path.join(REPO_DIR, "Release")
    with open(rel_file, "w", encoding="utf-8") as f:
        f.write(release_content)

    print("Updated Release file with all checksums successfully!")

if __name__ == "__main__":
    main()
