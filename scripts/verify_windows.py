#!/usr/bin/env python3
"""Verify actual Windows export hashes and run compiled gameplay suites.
Use --wine /path/to/wine on macOS/Linux, omit on native Windows. This does
not substitute for native graphics/controller/human Windows playtesting.
"""
import argparse, hashlib, json, os, re, subprocess, time
from pathlib import Path
project=Path(__file__).resolve().parent.parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--package',type=Path,required=True)
parser.add_argument('--wine',help='Wine executable; omit on Windows')
args=parser.parse_args()
package=args.package.resolve();exe=package/'Dungeon & Stone.exe';pack=exe.with_suffix('.pck')
build=json.loads((package/'BUILD_INFO.json').read_text())
for key,path in [('exe_sha256',exe),('pck_sha256',pack)]:
 if hashlib.sha256(path.read_bytes()).hexdigest()!=build[key]:parser.error('Export hash mismatch: '+path.name)
for path,digest in build['snapshot_sha256'].items():
 if hashlib.sha256((project/path).read_bytes()).hexdigest()!=digest:parser.error('Export does not match current gameplay: '+path)
def target_path(path):
 return 'Z:'+str(path.resolve()).replace('\\','/') if args.wine else str(path.resolve())
results=[];log_dir=project/'verification';log_dir.mkdir(exist_ok=True)
env=os.environ.copy();env['WINEDEBUG']='-all'
for name in ['content','reference','combat_rules','clock_progression','save_validation','early_floor_integration','early_monster_integration','third_floor_content','third_floor_rules','third_floor_integration','third_floor_ui']:
 command=([args.wine] if args.wine else [])+[str(exe),'--headless','--audio-driver','Dummy','--main-pack',target_path(pack),'--script',target_path(project/'tests'/(name+'_test.gd'))]
 start=time.monotonic()
 try:
  run=subprocess.run(command,text=True,encoding="utf-8",errors="replace",stdout=subprocess.PIPE,stderr=subprocess.STDOUT,env=env,timeout=240)
  output=run.stdout;passed=run.returncode==0 and not re.search(r'SCRIPT ERROR:|Parse Error:|ERROR:',output)
 except subprocess.TimeoutExpired as error: output=str(error.stdout or '')+'\nTimeout';passed=False
 (log_dir/('windows-'+name+'.log')).write_text(output)
 count=re.search(r'(\d+)\s+(?:checks|assertions)[,;]?\s+(\d+)\s+failures',output)
 record={'suite':name,'passed':passed,'seconds':round(time.monotonic()-start,2)}
 if count:record.update(checks=int(count.group(1)),failures=int(count.group(2)))
 results.append(record);print(('PASS ' if passed else 'FAIL ')+name+': '+str(record.get('checks','no summary')),flush=True)
 if not passed:print(output[-5000:],flush=True)
record={'version':build['version'],'runtime':'actual Windows x86_64 EXE/PCK via Wine; not native Windows' if args.wine else 'actual Windows x86_64 EXE/PCK on Windows','all_passed':all(r['passed'] for r in results),'source_gameplay_hashes_match':True,'exe_sha256':build['exe_sha256'],'pck_sha256':build['pck_sha256'],'suites':results}
(log_dir/'windows-results.json').write_text(json.dumps(record,indent=2)+'\n')
raise SystemExit(0 if record['all_passed'] else 1)
