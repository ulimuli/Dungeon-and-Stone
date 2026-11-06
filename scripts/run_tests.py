#!/usr/bin/env python3
"""Run the current consequential-rule and graphical scene suites with real Godot."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

project = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
parser.add_argument('--headless-only', action='store_true', help='Skip actual graphical input/layout suites.')
args = parser.parse_args()
headless = ['content', 'reference_content', 'character_art', 'city_life', 'city_simulation', 'reference', 'combat_rules', 'essence_lifetime', 'world', 'progression_magic', 'save_validation', 'campaign_persistence', 'settings_validation', 'adventurer_generation', 'companion_identity', 'essence_preservation', 'clock_progression', 'expanded_essence', 'racial_rules', 'racial_integration', 'dungeon_width', 'audio_lifecycle', 'turn_safety', 'numbered_rules', 'numbered_catalog', 'beastman_progression', 'numbered_integration', 'profession_rules', 'profession_integration', 'stat_catalog', 'stat_rules', 'stat_integration', 'stat_combat_rules', 'stat_physiology', 'stat_mental_rules', 'stat_expansion', 'stat_indices', 'spirit_rules', 'stat_remaining_integration', 'spirit_stones', 'spirit_stone_integration', 'homeland_catalog', 'homeland_rules', 'homeland_integration', 'dragon_blessing_rules', 'homeland_ceremonies', 'early_floor_content', 'early_floor_world', 'early_monster_rules', 'early_floor_integration', 'early_monster_integration', 'third_floor_content', 'third_floor_world', 'third_floor_rules', 'third_floor_integration']
graphical = ['city_map', 'ui_input', 'city_ui', 'magic_ui', 'preservation_ui', 'expansion_ui', 'racial_ui', 'stat_ui', 'stat_senses_ui', 'stat_actions_ui', 'homeland_map', 'homeland_ui', 'early_floor_ui', 'third_floor_ui']
try:
    version = subprocess.run([args.godot, '--version'], text=True, capture_output=True, check=True)
except (OSError, subprocess.CalledProcessError) as error:
    parser.error(f'Cannot execute Godot: {error}. Set GODOT_BIN or --godot to the executable.')
if not version.stdout.strip().startswith('4.5.1.'):
    parser.error('Use Godot 4.5.1 for reproducible verification.')
log_dir = project / 'verification'
log_dir.mkdir(exist_ok=True)
results = []
for name in headless + ([] if args.headless_only else graphical):
    command = [args.godot]
    if name in headless:
        command += ['--headless']
    command += ['--path', str(project), '--log-file', str(log_dir / (name + '-engine.log')), '--script', f'res://tests/{name}_test.gd']
    started = time.monotonic()
    try:
        run = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=450 if name == 'world' else 180 if name in ['save_validation','early_floor_world'] else 90)
        output = run.stdout
        passed = run.returncode == 0 and not re.search(r'SCRIPT ERROR:|Parse Error:|ERROR:', output)
    except subprocess.TimeoutExpired as error:
        output = str(error.stdout or '') + '\nTest exceeded its suite time limit.'
        passed = False
    (log_dir / (name + '.log')).write_text(output)
    summaries = [line for line in output.splitlines() if re.search(r'checks|assertions|TEST', line, re.I)]
    counts = re.search(r'(\d+)\s+(?:checks|assertions)[,;]?\s+(\d+)\s+failures', output)
    result = {'suite': name, 'passed': passed, 'seconds': round(time.monotonic() - started, 2), 'summary': summaries[-1] if summaries else output[-500:]}
    if counts:
        result.update(checks=int(counts.group(1)), failures=int(counts.group(2)))
    results.append(result)
    print(('PASS ' if passed else 'FAIL ') + name + ': ' + result['summary'], flush=True)
    if not passed:
        print(output[-6000:], flush=True)
files = {str(p.relative_to(project)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(project.rglob('*')) if p.is_file() and '.godot' not in p.relative_to(project).parts and (p.parent.name == 'game' and p.suffix in ['.gd', '.json'] or p.name in ['project.godot', 'main.tscn'])}
record = {'game': 'Dungeon & Stone', 'scope': 'automated rules and scene input; not human playtesting or campaign completion', 'all_passed': all(r['passed'] for r in results), 'suites': results, 'tested_runtime_sha256': files}
(log_dir / 'results.json').write_text(json.dumps(record, indent=2) + '\n')
sys.exit(0 if record['all_passed'] else 1)
