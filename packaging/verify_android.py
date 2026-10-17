#!/usr/bin/env python3
"""Inspect APK identity, launcher resources, ARM64 code, alignment and signatures."""
from pathlib import Path
import argparse, hashlib, json, os, struct, subprocess, zipfile
parser=argparse.ArgumentParser()
parser.add_argument('--toolchain',type=Path,required=True)
parser.add_argument('--apk',type=Path,required=True)
args=parser.parse_args(); tool=args.toolchain.resolve(); apk=args.apk.resolve(); out=apk.parent
build=tool/'android-sdk/build-tools/35.0.1'; java=next((tool/'jdk').glob('*/Contents/Home'))
env=os.environ.copy();env['JAVA_HOME']=str(java)
results={}
for name,cmd in [
 ('badging',[str(build/'aapt2'),'dump','badging',str(apk)]),
 ('manifest',[str(build/'aapt'),'dump','xmltree',str(apk),'AndroidManifest.xml']),
 ('adaptive-icon',[str(build/'aapt'),'dump','xmltree',str(apk),'res/mipmap-anydpi-v26/icon.xml']),
 ('signature',[str(build/'apksigner'),'verify','--verbose','--print-certs',str(apk)]),
 ('alignment',[str(build/'zipalign'),'-c','-P','16','4',str(apk)])]:
 r=subprocess.run(cmd,env=env,capture_output=True,text=True)
 (out/(name+'.txt')).write_text(r.stdout+r.stderr)
 assert r.returncode==0,(name,r.stderr)
 results[name]=r.stdout
bad=results['badging']; manifest=results['manifest']
assert "name='com.lianziyu.game'" in bad and "application-label:'炼字狱'" in bad
assert "native-code: 'arm64-v8a'" in bad and 'application-debuggable' not in bad
assert 'android.intent.action.MAIN' in manifest and 'android.intent.category.LAUNCHER' in manifest
assert '"mobile"' in manifest and 'android:screenOrientation' in manifest
assert 'E: uses-permission' not in manifest
assert 'E: foreground' in results['adaptive-icon'] and 'E: monochrome' in results['adaptive-icon']
with zipfile.ZipFile(apk) as z:
 assert z.testzip() is None
 names=z.namelist()
 assert not any(n.startswith(('assets/docs/','assets/tests/','assets/shots/','assets/packaging/')) for n in names)
 assert all(n in names for n in ['assets/project.binary','assets/scenes/main.tscn.remap','lib/arm64-v8a/libgodot_android.so'])
 binary=z.read('lib/arm64-v8a/libgodot_android.so')
 assert binary[:4]==b'\x7fELF' and struct.unpack_from('<H',binary,18)[0]==183
 assert '炼字狱'.encode() in z.read('assets/project.binary')
 for file in ['icon.webp','icon_foreground.webp','icon_background.webp','icon_monochrome.webp']:
  (out/file).write_bytes(z.read('res/mipmap-xxxhdpi-v4/'+file))
 pack=out/'apk-resources-smoke.zip'
 with zipfile.ZipFile(pack,'w',compression=zipfile.ZIP_STORED) as p:
  for n in names:
   if n.startswith('assets/') and not n.startswith('assets/dexopt/'):
    p.writestr(n[len('assets/'):],z.read(n))
summary={'apk':str(apk),'size_bytes':apk.stat().st_size,'sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),
         'package':'com.lianziyu.game','version':'0.1.0','architecture':'arm64-v8a','signed':True,
         'zip_crc_valid':True,'alignment_16kb_valid':True,'permissions':[],
         'physical_device_tested':False,'resource_smoke_pack':str(pack)}
(out/'apk-validation.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2))
(out/'SHA256SUMS.txt').write_text(summary['sha256']+'  '+apk.name+'\n')
print(json.dumps(summary,ensure_ascii=False,indent=2))
