import os
import shutil
import subprocess

PROJECT_DIR = "/mnt/c/Users/Antidv/Desktop/StoreSwitcher2-master"
PKG_DIR = "/tmp/pkg_rootless"
DEB_OUT = os.path.join(PROJECT_DIR, "debs", "com.subdiox.storeswitcher2_2.4.0_iphoneos-arm64.deb")

# 1. Clean & recreate
if os.path.exists(PKG_DIR):
    shutil.rmtree(PKG_DIR)

dirs = [
    f"{PKG_DIR}/DEBIAN",
    f"{PKG_DIR}/var/jb/usr/lib/TweakInject",
    f"{PKG_DIR}/var/jb/usr/bin",
    f"{PKG_DIR}/var/jb/Library/Application Support/StoreSwitcher",
    f"{PKG_DIR}/var/jb/Library/PreferenceLoader/Preferences",
    f"{PKG_DIR}/var/jb/Library/PreferenceBundles/StoreSwitcher.bundle"
]
for d in dirs:
    os.makedirs(d, exist_ok=True)

# 2. DEBIAN control & scripts
shutil.copy(f"{PROJECT_DIR}/control", f"{PKG_DIR}/DEBIAN/control")
if os.path.exists(f"{PROJECT_DIR}/layout/DEBIAN/postinst"):
    shutil.copy(f"{PROJECT_DIR}/layout/DEBIAN/postinst", f"{PKG_DIR}/DEBIAN/postinst")
    os.chmod(f"{PKG_DIR}/DEBIAN/postinst", 0o755)
if os.path.exists(f"{PROJECT_DIR}/layout/DEBIAN/prerm"):
    shutil.copy(f"{PROJECT_DIR}/layout/DEBIAN/prerm", f"{PKG_DIR}/DEBIAN/prerm")
    os.chmod(f"{PKG_DIR}/DEBIAN/prerm", 0o755)

# 3. Tweaks & Binaries
shutil.copy(f"{PROJECT_DIR}/.theos/obj/debug/StoreSwitcher.dylib", f"{PKG_DIR}/var/jb/usr/lib/TweakInject/StoreSwitcher.dylib")
shutil.copy(f"{PROJECT_DIR}/StoreSwitcher.plist", f"{PKG_DIR}/var/jb/usr/lib/TweakInject/StoreSwitcher.plist")

shutil.copy(f"{PROJECT_DIR}/.theos/obj/debug/AppAgent.dylib", f"{PKG_DIR}/var/jb/usr/lib/TweakInject/AppAgent.dylib")
shutil.copy(f"{PROJECT_DIR}/AppAgent.plist", f"{PKG_DIR}/var/jb/usr/lib/TweakInject/AppAgent.plist")

shutil.copy(f"{PROJECT_DIR}/.theos/obj/debug/agentcli", f"{PKG_DIR}/var/jb/usr/bin/agentcli")
os.chmod(f"{PKG_DIR}/var/jb/usr/bin/agentcli", 0o755)

# 4. Application Support Assets
for f in ["switcher@1x.png", "switcher@2x.png", "switcher@3x.png"]:
    src = f"{PROJECT_DIR}/layout/Library/Application Support/StoreSwitcher/{f}"
    if os.path.exists(src):
        shutil.copy(src, f"{PKG_DIR}/var/jb/Library/Application Support/StoreSwitcher/{f}")

# 5. PreferenceLoader
shutil.copy(f"{PROJECT_DIR}/layout/Library/PreferenceLoader/Preferences/StoreSwitcher.plist", f"{PKG_DIR}/var/jb/Library/PreferenceLoader/Preferences/StoreSwitcher.plist")
if os.path.exists(f"{PROJECT_DIR}/layout/Library/PreferenceLoader/Preferences/StoreSwitcher.png"):
    shutil.copy(f"{PROJECT_DIR}/layout/Library/PreferenceLoader/Preferences/StoreSwitcher.png", f"{PKG_DIR}/var/jb/Library/PreferenceLoader/Preferences/StoreSwitcher.png")

# 6. PreferenceBundle (compiled StoreSwitcher with 5 tabs)
bundle_src = f"{PROJECT_DIR}/.theos/obj/debug/StoreSwitcher.bundle"
if not os.path.exists(bundle_src):
    bundle_src = f"{PROJECT_DIR}/preferences/.theos/obj/debug/StoreSwitcher.bundle"
bundle_dst = f"{PKG_DIR}/var/jb/Library/PreferenceBundles/StoreSwitcher.bundle"
for item in os.listdir(bundle_src):
    s = os.path.join(bundle_src, item)
    d = os.path.join(bundle_dst, item)
    if os.path.isfile(s):
        shutil.copy(s, d)
        if item == "StoreSwitcher":
            os.chmod(d, 0o755)

shutil.copy(f"{PROJECT_DIR}/preferences/Resources/Root.plist", f"{bundle_dst}/Root.plist")

# 7. Package deb
if os.path.exists(DEB_OUT):
    os.remove(DEB_OUT)

res = subprocess.run(["dpkg-deb", "-b", "-Zgzip", PKG_DIR, DEB_OUT], capture_output=True, text=True)
print("dpkg-deb stdout:", res.stdout)
print("dpkg-deb stderr:", res.stderr)

if res.returncode == 0:
    print(f"SUCCESS: Package built at {DEB_OUT} ({os.path.getsize(DEB_OUT)} bytes)")
else:
    print("FAILED to build deb!")
