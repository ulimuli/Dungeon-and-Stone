#!/usr/bin/env python3
"""Create an atomic, CRC-checked source ZIP without caches, saves or credentials."""
import argparse
from pathlib import Path
import zipfile

project = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=project / 'builds/Dungeon-and-Stone-source.zip')
args = parser.parse_args()
output = args.output.resolve()
output.parent.mkdir(parents=True, exist_ok=True)
temporary = output.with_name(output.name + '.next')
skip_dirs = {'.git', '.godot', '.cache', 'builds', '__pycache__', 'saves'}
skip_names = {'.DS_Store', '.export_credentials.cfg', 'settings.json'}
with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED, compresslevel=7) as archive:
    for path in sorted(project.rglob('*')):
        relative = path.relative_to(project)
        if not path.is_file() or any(part in skip_dirs for part in relative.parts):
            continue
        if path in (output, temporary) or path.name in skip_names or path.suffix in {'.log', '.tmp', '.bak', '.pyc', '.zip', '.dmg'}:
            continue
        if relative.parts[0] == 'screenshots' and path.suffix == '.import':
            continue
        archive.write(path, str(Path(project.name) / relative))
with zipfile.ZipFile(temporary) as archive:
    if archive.testzip() is not None:
        raise SystemExit('Source archive failed CRC verification; previous archive preserved.')
    for required in ['project.godot', 'LICENSE', 'PROGRESS.md', 'game/simulation.gd', 'scripts/run_tests.py']:
        if str(Path(project.name) / required) not in archive.namelist():
            raise SystemExit('Source archive missing ' + required)
    print('Verified source archive:', len(archive.namelist()), 'files')
temporary.replace(output)
print(output)
