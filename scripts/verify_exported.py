#!/usr/bin/env python3
"""Exercise compiled macOS gameplay resources with external assisted test harnesses."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--app', required=True, type=Path, help='Path to an exported Dungeon & Stone.app')
parser.add_argument('--suite', action='append', help='Run only named suites; merge with matching existing PCK results.')
args = parser.parse_args()
project = Path(__file__).resolve().parent.parent
app = args.app.resolve()
try:
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    executable = app / 'Contents/MacOS' / info['CFBundleExecutable']
    packs = list((app / 'Contents/Resources').glob('*.pck'))
    if len(packs) != 1:
        raise ValueError('Expected exactly one bundled PCK')
    pack = packs[0]
    build = json.loads((app / 'Contents/Resources/BUILD_INFO.json').read_text())
except (OSError, ValueError, KeyError) as error:
    parser.error(str(error))
if info.get('CFBundleShortVersionString') != build['version'] or info.get('CFBundleVersion') != build['version']:
    parser.error('Exported application version does not match build manifest')
# Prove the external tests exercise the same game modules as this checkout.
for path, digest in build['snapshot_sha256'].items():
    if path.startswith('game/') and path.endswith(('.gd', '.json')):
        if hashlib.sha256((project / path).read_bytes()).hexdigest() != digest:
            parser.error('Exported gameplay does not match source: ' + path)
log_dir = project / 'verification'
log_dir.mkdir(exist_ok=True)
results = []
suite_names = ['companion_identity', 'essence_preservation', 'progression_magic', 'combat_rules', 'reference', 'magic_ui', 'clock_progression', 'expanded_essence', 'racial_integration', 'dungeon_width', 'audio_lifecycle', 'turn_safety', 'numbered_rules', 'numbered_catalog', 'beastman_progression', 'numbered_integration', 'profession_rules', 'profession_integration', 'stat_catalog', 'stat_rules', 'stat_integration', 'stat_combat_rules', 'stat_physiology', 'stat_mental_rules', 'stat_expansion', 'stat_senses_ui', 'stat_indices', 'spirit_rules', 'stat_remaining_integration', 'spirit_stones', 'spirit_stone_integration', 'homeland_catalog', 'homeland_rules', 'homeland_integration', 'dragon_blessing_rules', 'homeland_ceremonies', 'homeland_map', 'early_floor_content', 'early_floor_world', 'early_monster_rules', 'early_floor_integration', 'early_monster_integration', 'early_floor_ui', 'third_floor_content', 'third_floor_world', 'third_floor_rules', 'third_floor_integration', 'third_floor_ui']
for name in (args.suite or suite_names):
    if name not in suite_names: parser.error("Unknown suite: "+name)
    command = [str(executable), '--headless', '--audio-driver', 'Dummy', '--main-pack', str(pack), '--log-file', str(log_dir / ('exported-' + name + '-engine.log')), '--script', str(project / 'tests' / (name + '_test.gd'))]
    started = time.monotonic()
    try:
        run = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180 if name=='early_floor_world' else 90)
        output = run.stdout
        passed = run.returncode == 0 and not re.search(r'SCRIPT ERROR:|Parse Error:|ERROR:', output)
    except subprocess.TimeoutExpired as error:
        output = str(error.stdout or '') + '\nExported suite exceeded 90 seconds.'
        passed = False
    (log_dir / ('exported-' + name + '.log')).write_text(output)
    counts = re.search(r'(\d+)\s+(?:checks|assertions)[,;]?\s+(\d+)\s+failures', output)
    result = {'suite': name, 'passed': passed, 'seconds': round(time.monotonic() - started, 2)}
    if counts:
        result.update(checks=int(counts.group(1)), failures=int(counts.group(2)))
    results.append(result)
    print(('PASS ' if passed else 'FAIL ') + name + ': ' + str(result.get('checks', 'no summary')) + ' checks', flush=True)
    if not passed:
        print(output[-5000:], flush=True)
record = {'version': build['version'], 'runtime': 'exported universal app; external assisted harnesses, compiled PCK gameplay resources', 'all_passed': all(s['passed'] for s in results), 'suites': results, 'pck_sha256': hashlib.sha256(pack.read_bytes()).hexdigest(), 'executable_sha256': hashlib.sha256(executable.read_bytes()).hexdigest(), 'source_gameplay_hashes_match': True}
if args.suite:
    previous_path=log_dir/'exported-results.json'
    if previous_path.is_file():
        previous=json.loads(previous_path.read_text())
        if previous.get('pck_sha256')==record['pck_sha256']:
            updated={row['suite']:row for row in previous['suites']}
            updated.update({row['suite']:row for row in results})
            record['suites']=[updated[name] for name in suite_names if name in updated]
            record['all_passed']=len(record['suites'])==len(suite_names) and all(row['passed'] for row in record['suites'])
(log_dir / 'exported-results.json').write_text(json.dumps(record, indent=2) + '\n')
sys.exit(0 if record['all_passed'] else 1)
