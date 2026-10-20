"""Build, deploy and capture on Android without manual APK installation.

Uses the user's SDK/AVD. Never uninstalls the app or clears its data.
The x86_64 emulator build is separate from phone delivery APKs.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import zipfile
from legacy_manifest import repair_manifest

ROOT = Path(__file__).resolve().parents[2]
CONFIG_PATH = Path(__file__).with_name("local.json")
LOCAL_CONFIG = json.loads(CONFIG_PATH.read_text(encoding="utf-8")) if CONFIG_PATH.exists() else {}
PACKAGE = "com.huozi.game"
AVD = "Huozi_API_35"
PROFILES = {"phone-720": (1600, 720, 320), "phone-1080": (2400, 1080, 440),
            "phone-1440": (3200, 1440, 560), "user-screenshot": (2436, 1120, 480),
            "compact": (1280, 720, 320), "tablet": (1920, 1200, 240)}
# Share the researched resolutions and synthetic display densities with UI checks.
SCREEN_PROFILES = ROOT / "tests/fixtures/mobile_screen_profiles.json"
if SCREEN_PROFILES.is_file():
    PROFILES.update({p["id"]: (*p["pixels"], round(p["density"] * 160))
                     for p in json.loads(SCREEN_PROFILES.read_text(encoding="utf-8"))["profiles"]})
NO_WINDOW = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0


def run(command, check=True, **kwargs):
    return subprocess.run([str(x) for x in command], check=check, creationflags=NO_WINDOW, **kwargs)


def find_godot(explicit):
    candidates = [explicit, os.environ.get("GODOT_EXE"), shutil.which("godot")]
    candidates += sorted((Path(os.environ.get("LOCALAPPDATA", "")) / "Programs/Godot").glob("*/Godot*console.exe"), reverse=True)
    return next((Path(c) for c in candidates if c and Path(c).is_file()), None)


def source_fingerprint():
    digest = hashlib.sha256()
    paths = [ROOT / "project.godot", Path(__file__), Path(__file__).with_name("legacy_manifest.py")]
    for folder in ["src", "scenes", "assets", "data", "resources"]:
        paths += [p for p in (ROOT / folder).rglob("*") if p.is_file()]
    for path in sorted(paths):
        stat = path.stat()
        digest.update(f"{path.relative_to(ROOT).as_posix()}:{stat.st_size}:{stat.st_mtime_ns}\n".encode())
    return digest.hexdigest()


def build(args, arch, sdk, env):
    godot = find_godot(args.godot)
    if not godot:
        raise RuntimeError("Godot not found. Set GODOT_EXE or use --godot PATH.")
    version = run([godot, "--version"], capture_output=True, text=True).stdout.strip()
    match = re.match(r"(\d+\.\d+(?:\.\d+)?)\.(stable|rc\d*|beta\d*)", version)
    if not match:
        raise RuntimeError("Cannot resolve Godot export template version: " + version)
    template = Path(os.environ["APPDATA"]) / "Godot/export_templates" / (match[1]+"."+match[2]) / "android_release.apk"
    if not template.is_file():
        raise RuntimeError("Missing release export template: " + str(template))
    output = ROOT / "build/android/dev" / arch
    output.mkdir(parents=True, exist_ok=True)
    apk = output / "huozi-dev.apk"
    presets = ROOT / "export_presets.cfg"
    original = presets.read_bytes() if presets.exists() else None
    text = original.decode("utf-8-sig") if original else ""
    index = max([int(n) for n in re.findall(r"\[preset\.(\d+)\]", text)] + [-1]) + 1
    # Use a dedicated preset and restore the exact original bytes afterwards.
    extra = f'''
[preset.{index}]
name="Android Automatic Test"
platform="Android"
runnable=false
export_filter="all_resources"
include_filter="data/*.json,data/balance/*.json,assets/taopunk/attacks/*.json,assets/events/art_manifest.json,assets/relics/icons/manifest.json,assets/fonts/*-OFL.txt,assets/fonts/sources.json"
exclude_filter="docs/*,tests/*,shots/*,prototypes/*,build/*,tools/*,data/import/*"
export_path="{apk.as_posix()}"
script_export_mode=2
[preset.{index}.options]
gradle_build/use_gradle_build=false
architectures/armeabi-v7a=false
architectures/arm64-v8a={str(arch == 'arm64-v8a').lower()}
architectures/x86=false
architectures/x86_64={str(arch == 'x86_64').lower()}
version/code=2026102001
version/name="2026.10.20-phone-layout"
package/unique_name="{PACKAGE}"
package/name="炼字狱"
package/signed=true
screen/immersive_mode=true
screen/edge_to_edge=false
user_data_backup/allow=false
permissions/internet=false
command_line/extra_args="{'--rendering-method gl_compatibility' if arch == 'x86_64' else ''}"
'''
    injected = (text.rstrip() + "\n" + extra).encode("utf-8")
    lock = output.parent / ".export.lock"
    key = Path(os.environ["APPDATA"]) / "Godot/keystores/debug.keystore"
    if not key.exists():
        raise RuntimeError("Missing local Godot test keystore: " + str(key))
    env = env | {"GODOT_ANDROID_KEYSTORE_RELEASE_PATH": str(key),
                 "GODOT_ANDROID_KEYSTORE_RELEASE_USER": "androiddebugkey",
                 "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD": "android"}
    with lock.open("x"):
        pass
    try:
        presets.write_bytes(injected)
        print("Building", arch, "APK; log:", output / "export.log", flush=True)
        with (output / "export.log").open("wb") as log:
            run([godot, "--headless", "--path", ROOT, "--export-release", "Android Automatic Test", apk], env=env, stdout=log, stderr=subprocess.STDOUT)
    finally:
        if presets.read_bytes() == injected:
            if original is None:
                presets.unlink()
            else:
                presets.write_bytes(original)
        else:
            print("Export settings changed externally; preserved current file.", file=sys.stderr)
        lock.unlink(missing_ok=True)
    fixed = output / "unsigned.apk"
    with zipfile.ZipFile(apk) as source, zipfile.ZipFile(template) as base, zipfile.ZipFile(fixed, "w") as dest:
        for item in source.infolist():
            if item.filename.startswith("META-INF/"):
                continue
            data = source.read(item)
            if item.filename == "AndroidManifest.xml":
                data, _ = repair_manifest(data)
            dest.writestr(item, data)
        icon = "res/mipmap-anydpi-v26/themed_icon.xml"
        if icon not in source.namelist():
            dest.writestr(base.getinfo(icon), base.read(icon))
    build_tools = sorted((sdk / "build-tools").glob("*"), key=lambda p: tuple(int(n) for n in re.findall(r"\d+", p.name)), reverse=True)[0]
    run([build_tools / "zipalign.exe", "-f", "-P", "16", "4", fixed, apk], env=env)
    signing_env = env | {"HUOZI_LOCAL_TEST_PASSWORD": "android"}
    run(["cmd", "/c", build_tools / "apksigner.bat", "sign", "--ks", key, "--ks-key-alias", "androiddebugkey", "--ks-pass", "env:HUOZI_LOCAL_TEST_PASSWORD", "--v4-signing-enabled", "false", apk], env=signing_env)
    with (output / "signature.log").open("wb") as log:
        run(["cmd", "/c", build_tools / "apksigner.bat", "verify", "--verbose", apk], env=env, stdout=log, stderr=subprocess.STDOUT)
    run([build_tools / "zipalign.exe", "-c", "-P", "16", "4", apk], env=env)
    (output / "source.json").write_text(json.dumps({"fingerprint": source_fingerprint()}), encoding="utf-8")
    return apk


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--sdk", type=Path, default=Path(os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME") or str(Path(os.environ["LOCALAPPDATA"]) / "Android/Sdk")))
    p.add_argument("--godot", default=LOCAL_CONFIG.get("godot"))
    p.add_argument("--java", type=Path, default=Path(os.environ.get("JAVA_HOME") or LOCAL_CONFIG.get("java") or str(Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Android/Android Studio/jbr")))
    p.add_argument("--serial", help="ADB serial, required if multiple devices are connected")
    p.add_argument("--avd", default=AVD)
    p.add_argument("--apk", type=Path, help="Deploy an existing APK instead of building")
    p.add_argument("--rebuild", action="store_true", help="Rebuild the game before deployment")
    p.add_argument("--profile", choices=PROFILES, help="Emulator-only display override; reused without rebuilding the APK")
    p.add_argument("--reset-display", action="store_true", help="Reset emulator display overrides")
    p.add_argument("--capture", action="store_true", help="Capture the current Android screen; does not restart the game")
    p.add_argument("--logs", action="store_true", help="Stream game process logcat; Ctrl+C stops streaming")
    p.add_argument("--perf", action="store_true", help="Record 15 seconds of logcat/CPU/GFX evidence while reproducing a stall")
    p.add_argument("--headless-emulator", action="store_true")
    args = p.parse_args()
    if not (args.java / "bin/java.exe").is_file():
        raise RuntimeError("JDK not found. Set JAVA_HOME, use --java, or set java in tools/android/local.json.")
    sdk = args.sdk.resolve()
    adb = sdk / "platform-tools/adb.exe"
    if not adb.is_file():
        raise RuntimeError("ADB not found: " + str(adb))
    env = os.environ.copy()
    env["ANDROID_SDK_ROOT"] = str(sdk)
    env["JAVA_HOME"] = str(args.java)
    env["PATH"] = str(args.java / "bin") + os.pathsep + env["PATH"]

    def connected():
        output = run([adb, "devices"], capture_output=True, text=True).stdout
        return [line.split()[0] for line in output.splitlines() if re.match(r"^\S+\s+device$", line.strip())]

    devices = connected()
    if not devices and not args.serial:
        emulator = sdk / "emulator/emulator.exe"
        if not emulator.is_file():
            raise RuntimeError("Install Android Emulator in Android Studio SDK Manager first.")
        available = run([emulator, "-list-avds"], capture_output=True, text=True).stdout.splitlines()
        if args.avd not in available:
            raise RuntimeError(f"Create AVD {args.avd} in Android Studio Device Manager first. Available: {available}")
        folder = ROOT / "build/android/dev"
        folder.mkdir(parents=True, exist_ok=True)
        command = [str(emulator), "-avd", args.avd, "-gpu", "auto", "-no-boot-anim", "-scale", "0.4"]
        if args.headless_emulator:
            command += ["-no-window"]
        with (folder / "emulator.log").open("ab") as log:
            subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT, creationflags=NO_WINDOW)
        print("Starting Android emulator…", flush=True)
        deadline = time.monotonic() + 240
        while time.monotonic() < deadline:
            devices = connected()
            if devices:
                break
            time.sleep(2)
        if not devices:
            raise RuntimeError("Emulator did not connect; see build/android/dev/emulator.log")
    serial = args.serial or (devices[0] if len(devices) == 1 else None)
    if not serial:
        raise RuntimeError("Multiple Android devices. Select one with --serial: " + ", ".join(devices))
    cmd = [adb, "-s", serial]

    def shell(*parts):
        return run(cmd + ["shell", *parts], capture_output=True, text=True, encoding="utf-8", errors="replace").stdout.strip()

    deadline = time.monotonic() + 180
    while shell("getprop", "sys.boot_completed") != "1":
        if time.monotonic() > deadline:
            raise RuntimeError("Android did not finish booting.")
        time.sleep(2)
    print("Device:", serial, shell("getprop", "ro.product.model"), flush=True)
    if args.profile or args.reset_display:
        if shell("getprop", "ro.kernel.qemu") != "1":
            raise RuntimeError("Display profiles are limited to emulators; physical phone settings are not changed.")
        if args.reset_display:
            shell("wm", "size", "reset")
            shell("wm", "density", "reset")
        else:
            width, height, dpi = PROFILES[args.profile]
            shell("wm", "size", f"{height}x{width}")
            shell("wm", "density", str(dpi))
        shell("settings", "put", "system", "accelerometer_rotation", "0")
        shell("settings", "put", "system", "user_rotation", "1")
        time.sleep(2)
    if args.logs:
        pid = shell("pidof", PACKAGE)
        if not pid:
            raise RuntimeError("Game is not running. Launch it first.")
        run(cmd + ["logcat", "--pid=" + pid])
        return
    now = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    evidence = ROOT / "shots/android" / now
    if args.capture:
        evidence.mkdir(parents=True, exist_ok=True)
        with (evidence / "screen.png").open("wb") as out:
            run(cmd + ["exec-out", "screencap", "-p"], stdout=out)
        (evidence / "display.txt").write_text(shell("wm", "size") + "\n" + shell("wm", "density"), encoding="utf-8")
        print("Android screenshot:", evidence / "screen.png")
        return
    if args.perf:
        evidence.mkdir(parents=True, exist_ok=True)
        print("Reproduce the return-to-menu stall now; recording for 15 seconds…", flush=True)
        # SurfaceView/Vulkan frame times are not fully represented by gfxinfo.
        shell("dumpsys", "gfxinfo", PACKAGE, "reset")
        with (evidence / "logcat.txt").open("wb") as log:
            proc = subprocess.Popen(cmd + ["logcat", "-T", "1"], stdout=log, stderr=subprocess.STDOUT, creationflags=NO_WINDOW)
            try:
                (evidence / "cpu-start.txt").write_text(shell("dumpsys", "cpuinfo"), encoding="utf-8")
                time.sleep(15)
                (evidence / "cpu-end.txt").write_text(shell("dumpsys", "cpuinfo"), encoding="utf-8")
                (evidence / "gfxinfo.txt").write_text(shell("dumpsys", "gfxinfo", PACKAGE, "framestats"), encoding="utf-8")
            finally:
                proc.terminate()
                proc.wait(timeout=10)
        print("Performance evidence:", evidence, "(use Android Studio System Trace for native render timing)")
        return
    abi = shell("getprop", "ro.product.cpu.abi")
    if abi not in ["arm64-v8a", "x86_64"]:
        raise RuntimeError("Unsupported device ABI: " + abi)
    arch = abi
    apk = args.apk.resolve() if args.apk else ROOT / "build/android/dev" / arch / "huozi-dev.apk"
    source_state = apk.parent / "source.json"
    changed = not args.apk and (not source_state.is_file() or json.loads(source_state.read_text(encoding="utf-8")).get("fingerprint") != source_fingerprint())
    if args.rebuild or not apk.is_file() or changed:
        apk = build(args, arch, sdk, env)
    digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    state_file = ROOT / "build/android/dev/deployed.json"
    state_file.parent.mkdir(parents=True, exist_ok=True)
    state = json.loads(state_file.read_text(encoding="utf-8")) if state_file.exists() else {}
    installed = run(cmd + ["shell", "pm", "path", PACKAGE], check=False, capture_output=True, text=True).stdout.strip()
    if state.get(serial) != digest or not installed:
        # -r retains application data; no uninstall, clear, or downgrade flags.
        run(cmd + ["install", "-r", apk])
        state[serial] = digest
        state_file.write_text(json.dumps(state, indent=2), encoding="utf-8")
    else:
        print("APK unchanged; skipping installation.", flush=True)
    component = shell("cmd", "package", "resolve-activity", "--brief", PACKAGE).splitlines()[-1]
    if "/" not in component:
        raise RuntimeError("Cannot resolve game launcher: " + component)
    shell("am", "force-stop", PACKAGE)
    print(shell("am", "start", "-W", "-n", component), flush=True)
    print("Ready. --rebuild updates code; --profile changes display; --capture saves the current screen.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
    except (RuntimeError, subprocess.CalledProcessError, OSError) as error:
        print("Android test failed:", error, file=sys.stderr)
        sys.exit(1)
