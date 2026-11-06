#!/usr/bin/env python3
"""Export a standalone Windows x86_64 package with official Godot4.5.1 template.
No installed Windows SDK, paid service or account required. Runs on macOS/Linux.
Execution verification is separate: scripts/verify_windows.py (Wine or native).
"""
import argparse, hashlib, json, os, re, shutil, struct, subprocess, tempfile, zipfile
from pathlib import Path
project=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot',default=os.environ.get('GODOT_BIN','godot'))
parser.add_argument('--template',type=Path,required=True)
parser.add_argument('--output',type=Path,default=project/'builds')
args=parser.parse_args()
template=args.template.resolve()
data=template.read_bytes()
pe=struct.unpack_from('<I',data,0x3c)[0]
if data[:2]!=b'MZ' or data[pe:pe+4]!=b'PE\0\0' or struct.unpack_from('<H',data,pe+4)[0]!=0x8664: parser.error('Expected official x86_64 PE template')
version=subprocess.check_output([args.godot,'--version'],text=True).strip()
if not version.startswith('4.5.1.'): parser.error('Godot4.5.1 required')
root=Path(tempfile.mkdtemp(prefix='dungeon-windows-'));stage=root/'project';package=root/'Dungeon-and-Stone-Windows'
shutil.copytree(project,stage,ignore=shutil.ignore_patterns('.godot','.git','builds','.cache','*.log'))
package.mkdir()
preset=stage/'export_presets.cfg'; text=preset.read_text();a=text.index('[preset.1.options]')
text=text[:a]+re.sub(r'^custom_template/(debug|release)=.*$',lambda m:'custom_template/'+m.group(1)+'='+json.dumps(str(template)),text[a:],flags=re.M);preset.write_text(text)
def run(command,log):
 result=subprocess.run(command,text=True,encoding="utf-8",errors="replace",stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
 (root/log).write_text(result.stdout)
 if result.returncode or re.search(r'SCRIPT ERROR:|Parse Error:|Failed to load script|Export failed',result.stdout):raise SystemExit(result.stdout[-6000:])
run([args.godot,'--headless','--path',str(stage),'--editor','--import','--quit'],'import.log')
exe=package/'Dungeon & Stone.exe'
run([args.godot,'--headless','--path',str(stage),'--export-release','Windows Desktop',str(exe)],'export.log')
if not exe.is_file() or not exe.with_suffix('.pck').is_file():raise SystemExit('Export did not create EXE + PCK')
legal=package/'Legal';legal.mkdir()
for name in ['LICENSE','GODOT_LICENSE.txt','GODOT_COPYRIGHT.txt','ASSET_LICENSES.md']:
 if (project/name).is_file():shutil.copy2(project/name,legal/name)
for name in ['PixelifySans-OFL.txt','VT323-OFL.txt']:shutil.copy2(project/'assets'/name,legal/name)
files={str(path.relative_to(project)):hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted((project/'game').glob('*')) if path.suffix in ['.gd','.json']}
version=re.search(r'^config/version="([^"]+)"',(project/'project.godot').read_text(),re.M).group(1)
record={'game':'Dungeon & Stone','version':version,'engine':'Godot4.5.1-stable','target':'Windows x86_64','signature':'unsigned development build','snapshot_sha256':files,'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'pck_sha256':hashlib.sha256(exe.with_suffix('.pck').read_bytes()).hexdigest()}
(package/'BUILD_INFO.json').write_text(json.dumps(record,indent=2)+'\n')
(package/'START_HERE.txt').write_text('DUNGEON & STONE '+version+' — UNFINISHED DEVELOPMENT BUILD\n\nExtract the entire ZIP to a local folder. Double-click Dungeon & Stone.exe.\nKeep Dungeon & Stone.pck beside the executable. Godot, internet, accounts and API keys are not required.\nWindows64-bit with OpenGL3.3-capable graphics is required. This build is unsigned.\n\nWASD/arrows move, E interacts, Space ends phase, I inventory, P party/stats, J journal, C camp, V jump, Esc pause. Click enemies to attack; right-click inspects. Controls/settings are remappable.\n\nNine areas across floors1–3,35 species,7 partial essence kits. No finished campaign/ending.\nSaves/settings: %APPDATA%/Godot/app_userdata/Dungeon & Stone/\nSee PROGRESS.md and TESTING.md in the source package for limits and evidence.\n')
args.output.mkdir(parents=True,exist_ok=True)
output=args.output/'Dungeon-and-Stone-Windows.zip';temporary=output.with_suffix('.zip.next')
with zipfile.ZipFile(temporary,'w',zipfile.ZIP_DEFLATED,compresslevel=7) as archive:
 for path in sorted(package.rglob('*')):
  if path.is_file():archive.write(path,str(Path(package.name)/path.relative_to(package)))
with zipfile.ZipFile(temporary) as archive:
 if archive.testzip():raise SystemExit('Windows archive CRC failed')
temporary.replace(output)
(args.output/'Dungeon-and-Stone-Windows-BUILD_INFO.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'package':str(package),'exe':str(exe),'archive':str(output),'build_root':str(root)},indent=2))
