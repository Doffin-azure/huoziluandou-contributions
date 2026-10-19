#!/usr/bin/env python3
"""Build a signed, offline ARM64 APK using a local Godot Android toolchain."""
from pathlib import Path
import argparse
import os
import secrets
import subprocess

project = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--toolchain', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--godot', type=Path, default=Path('/Applications/Godot.app/Contents/MacOS/Godot'))
args = parser.parse_args()
tools_dir = args.toolchain.resolve()
output = args.output.resolve()
output.parent.mkdir(parents=True, exist_ok=True)
java = next((tools_dir / 'jdk').glob('*/Contents/Home'))
template = tools_dir / 'android_release.apk'
assert template.is_file(), 'Missing official android_release.apk export template'
assert (tools_dir / 'android-sdk/build-tools/35.0.1/apksigner').is_file(), 'Missing Android build tools'
signing = tools_dir.parent / 'signing'
signing.mkdir(mode=0o700, exist_ok=True)
password_file = signing / 'release-password.txt'
if not password_file.exists():
    password_file.write_text(secrets.token_hex(24))
    password_file.chmod(0o600)
key = signing / 'lianziyu-release.keystore'
env = os.environ.copy()
env['JAVA_HOME'] = str(java)
env['ANDROID_HOME'] = str(tools_dir / 'android-sdk')
env['LIANZIYU_KEY_PASSWORD'] = password_file.read_text().strip()
if not key.exists():
    subprocess.run([str(java / 'bin/keytool'), '-genkeypair', '-keystore', str(key),
                    '-alias', 'lianziyu', '-keyalg', 'RSA', '-keysize', '2048',
                    '-validity', '10000', '-dname', 'CN=Lianziyu, O=Lianziyu',
                    '-storepass:env', 'LIANZIYU_KEY_PASSWORD',
                    '-keypass:env', 'LIANZIYU_KEY_PASSWORD'], env=env, check=True)
    key.chmod(0o600)
config = (project / 'packaging/android_export_presets.cfg.in').read_text()
(project / 'export_presets.cfg').write_text(config.replace('${LIANZIYU_ANDROID_TEMPLATE}', str(template)))
env['GODOT_ANDROID_KEYSTORE_RELEASE_PATH'] = str(key)
env['GODOT_ANDROID_KEYSTORE_RELEASE_USER'] = 'lianziyu'
env['GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD'] = env['LIANZIYU_KEY_PASSWORD']
subprocess.run([str(args.godot), '--headless', '--path', str(project), '--export-release',
                'Android', str(output), '--log-file', str(output.parent / 'export.log')],
               env=env, check=True)
assert output.is_file() and output.stat().st_size > 1000000, 'No APK was produced'
print('APK:', output)
