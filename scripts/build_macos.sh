#!/bin/bash
# Reproducible offline export from a source snapshot. Requires Godot 4.5.1,
# the matching official macOS template, Python 3, and the macOS command tools.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT_EXECUTABLE="${GODOT_BIN:-$(command -v godot || true)}"
MACOS_TEMPLATE="${GODOT_MACOS_TEMPLATE:-$PROJECT_DIR/.cache/godot-macos-template.zip}"
OUTPUT_DIR="${DUNGEON_BUILD_OUTPUT:-$PROJECT_DIR/builds}"

if [[ ! -x "$GODOT_EXECUTABLE" ]]; then
    echo "Godot executable missing. Set GODOT_BIN to the Godot 4.5.1 executable." >&2
    exit 1
fi
if [[ ! -f "$MACOS_TEMPLATE" ]]; then
    echo "macOS template missing: $MACOS_TEMPLATE" >&2
    echo "Download it with: python3 '$SCRIPT_DIR/fetch_macos_template.py' --output '$MACOS_TEMPLATE'" >&2
    exit 1
fi
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This build script uses macOS ditto and codesign. Run on macOS." >&2
    exit 1
fi
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
# Sign outside cloud-backed Documents: its file provider can recreate FinderInfo
# immediately after xattr cleanup, causing codesign to reject an otherwise valid app.
BUILD_DIR="$(mktemp -d /private/tmp/dungeon-and-stone-build.XXXXXX)"
STAGE_DIR="$BUILD_DIR/project"
PACKAGE_DIR="$BUILD_DIR/package"
mkdir -p "$PACKAGE_DIR"
echo "Building source snapshot in $BUILD_DIR"

# The active checkout is never rewritten by the build. The absolute custom
# template path is written only into the temporary snapshot's preset.
python3 - "$PROJECT_DIR" "$STAGE_DIR" "$MACOS_TEMPLATE" <<'PY'
from pathlib import Path
import re
import shutil
import sys

source, stage, template = map(Path, sys.argv[1:])
shutil.copytree(source, stage, ignore=shutil.ignore_patterns('.godot', '.git', 'builds', '.cache', '*.log'))
preset = stage / 'export_presets.cfg'
text = preset.read_text()
version_match = re.search(r'^config/version="([0-9]+\.[0-9]+\.[0-9]+)"$', (stage / 'project.godot').read_text(), re.M)
if not version_match: raise SystemExit('project.godot must define config/version')
for key in ('application/short_version', 'application/version'):
    text = re.sub(rf'^{re.escape(key)}=.*$', f'{key}="{version_match.group(1)}"', text, flags=re.M)
escaped = str(template.resolve()).replace('\\', '\\\\').replace('"', '\\"')
for variant in ('debug', 'release'):
    text = re.sub(rf'^custom_template/{variant}=.*$', f'custom_template/{variant}="{escaped}"', text, flags=re.M)
preset.write_text(text)
# The universal exporter validates both GPU import families even for this
# game's uncompressed pixel textures and Compatibility renderer.
project_file = stage / 'project.godot'
settings = project_file.read_text()
for option in ('textures/vram_compression/import_s3tc_bptc', 'textures/vram_compression/import_etc2_astc'):
    settings = re.sub(rf'^{re.escape(option)}=.*\n?', '', settings, flags=re.M)
    settings = settings.replace('[rendering]\n', f'[rendering]\n{option}=true\n', 1)
project_file.write_text(settings)
PY

"$GODOT_EXECUTABLE" --headless --path "$STAGE_DIR" --log-file "$BUILD_DIR/import.log" --editor --import --quit
if grep -Eq 'SCRIPT ERROR:|Parse Error:|Failed to load script' "$BUILD_DIR/import.log"; then
    echo "Import found a script error. See $BUILD_DIR/import.log" >&2
    exit 1
fi
"$GODOT_EXECUTABLE" --headless --path "$STAGE_DIR" --log-file "$BUILD_DIR/export.log" --export-release "macOS" "$PACKAGE_DIR/Dungeon & Stone.app"
if grep -Eq 'SCRIPT ERROR:|Parse Error:|Failed to load script|Export failed' "$BUILD_DIR/export.log"; then
    echo "Export failed. See $BUILD_DIR/export.log" >&2
    exit 1
fi
APP_DIR="$PACKAGE_DIR/Dungeon & Stone.app"
test -d "$APP_DIR/Contents/MacOS"
# Godot 4.5.1 substitutes the game title into this XML without escaping '&'.
# Normalize the exported plist before signing, preserving the actual game name.
python3 - "$APP_DIR/Contents/Info.plist" <<'PY'
from pathlib import Path
import plistlib
import re
import sys

path = Path(sys.argv[1])
xml = re.sub(r'&(?!amp;|lt;|gt;|quot;|apos;|#\d+;|#x[0-9a-fA-F]+;)', '&amp;', path.read_text())
data = plistlib.loads(xml.encode('utf-8'))
path.write_bytes(plistlib.dumps(data, fmt=plistlib.FMT_XML, sort_keys=False))
PY
mkdir -p "$APP_DIR/Contents/Resources/Legal"
python3 - "$STAGE_DIR" "$PACKAGE_DIR/BUILD_INFO.json" "$APP_DIR/Contents/Resources/BUILD_INFO.json" <<'PY'
from pathlib import Path
import hashlib
import json
import re
import sys

stage, manifest, embedded = map(Path, sys.argv[1:])
files = {}
for source_file in sorted(stage.rglob('*')):
    relative = source_file.relative_to(stage)
    if source_file.is_file() and '.godot' not in relative.parts and source_file.suffix in ('.gd', '.tscn', '.godot', '.json'):
        files[str(relative)] = hashlib.sha256(source_file.read_bytes()).hexdigest()
version = re.search(r'^config/version="([^"]+)"$', (stage / 'project.godot').read_text(), re.M).group(1)
record = json.dumps({'game': 'Dungeon & Stone', 'version': version, 'engine': 'Godot 4.5.1-stable', 'target': 'macOS universal x86_64 + arm64', 'signature': 'local ad-hoc; not notarized', 'snapshot_sha256': files}, indent=2)+'\n'
manifest.write_text(record)
embedded.write_text(record)
PY
for legal in LICENSE GODOT_LICENSE.txt GODOT_COPYRIGHT.txt ASSET_LICENSES.md; do
    if [[ -f "$STAGE_DIR/$legal" ]]; then
        cp "$STAGE_DIR/$legal" "$APP_DIR/Contents/Resources/Legal/$legal"
    fi
done
for font_license in PixelifySans-OFL.txt VT323-OFL.txt; do
    if [[ -f "$STAGE_DIR/assets/$font_license" ]]; then
        cp "$STAGE_DIR/assets/$font_license" "$APP_DIR/Contents/Resources/Legal/$font_license"
    fi
done
# Adding the visible legal folder changes the sealed bundle. Re-sign with an
# explicitly local ad-hoc signature; no developer identity or account is used.
# Finder metadata can be inherited by copied legal files. Clear attributes
# only inside this newly generated temporary app before sealing its signature.
/usr/bin/xattr -cr "$APP_DIR"
/usr/bin/codesign --force --deep --sign - --timestamp=none "$APP_DIR"
/usr/bin/codesign --verify --deep --strict "$APP_DIR"

cat > "$PACKAGE_DIR/START_HERE.txt" <<'EOF'
DUNGEON & STONE — DEVELOPMENT BUILD

Open the DMG, then Dungeon & Stone.app. Alternatively unzip the ZIP in a local
folder outside cloud-backed Documents/Desktop. No Godot installation, internet, account, or
API key is required. The app contains Intel x86_64 and Apple Silicon arm64
runtime binaries. This is an unfinished reconstruction checkpoint, with six
playable race profiles and nine implemented Labyrinth areas across floors1–3. New expeditions use
96x64 maps with three-to-five-wide corridors. Older active expeditions keep their
saved layout until returning to the city. It is not yet
the complete novel game. Consult PROGRESS.md in the source distribution for
verified features and outstanding work.

START PLAYING
Choose New Game, a race/background and save slot. Begin in your racial home;
click people/landmarks to approach and interact, or walk beside them and press E.
Use RAFDONIA to return to city services and LANDS to visit racial areas.
Prepare, recruit and customize in the city, then enter Crystal
Cave through Dimensional Square. WASD/arrows move; click enemies to attack; right-click
inspects. E interacts, Space ends the party phase, Tab selects an ally,
1-3 target techniques, I inventory, P status, J journal, Escape pause.
Controls can be remapped in Settings.

Survivors return automatically when their floor closes (Crystal Cave:
168 hours). Arrival portals are not instant exits. Carry food and use Rest
outside combat to advance eight hours. Confirm essence absorption before
its 30-minute expiry. Character death is permanent.

The app is ad-hoc signed for local execution. It is not Apple-notarized.
If a downloaded copy is blocked by Gatekeeper, use the macOS Privacy &
Security settings' Open Anyway action after attempting to launch it.

Saves: ~/Library/Application Support/Godot/app_userdata/Dungeon & Stone/
Licenses: Dungeon & Stone.app/Contents/Resources/Legal/

The source project and build instructions are provided separately.
EOF

# Launch the real exported runtime (not the editor) and allow 20 frames for
# startup. Persistent player saves are not modified by this title-screen check.
EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP_DIR/Contents/Info.plist")"
"$APP_DIR/Contents/MacOS/$EXECUTABLE_NAME" --headless --audio-driver Dummy --log-file "$BUILD_DIR/runtime.log" --quit-after 20
if grep -Eq 'SCRIPT ERROR:|Parse Error:|Failed to load script|Failed loading resource|No loader found' "$BUILD_DIR/runtime.log"; then
    echo "Exported runtime smoke failed. See $BUILD_DIR/runtime.log" >&2
    exit 1
fi

ZIP_PATH="$BUILD_DIR/Dungeon-and-Stone-macOS.zip"
/usr/bin/ditto -c -k --sequesterRsrc "$PACKAGE_DIR" "$ZIP_PATH"
DMG_PATH="$BUILD_DIR/Dungeon-and-Stone-macOS.dmg"
/usr/bin/hdiutil create -volname "Dungeon & Stone" -srcfolder "$PACKAGE_DIR" -ov -format UDZO "$DMG_PATH"
/usr/bin/hdiutil verify "$DMG_PATH"
# Publish containers, not a loose app: a cloud-backed output folder may attach
# FinderInfo to app bundles and invalidate the otherwise verified signature.
python3 - "$OUTPUT_DIR" "$ZIP_PATH" "$DMG_PATH" "$PACKAGE_DIR/START_HERE.txt" "$PACKAGE_DIR/BUILD_INFO.json" <<'PY_PUBLISH'
from pathlib import Path
import shutil
import sys

output, archive, image, readme, manifest = map(Path, sys.argv[1:])
for source, name in [(archive, archive.name), (image, image.name), (readme, 'Dungeon-and-Stone-START_HERE.txt'), (manifest, 'Dungeon-and-Stone-BUILD_INFO.json')]:
    staging = output / (name + '.next')
    shutil.copyfile(source, staging)
    staging.replace(output / name)
print(f'Verified offline app packaged: {output / image.name}')
print(f'ZIP alternative: {output / archive.name}')
PY_PUBLISH
echo "Build logs retained: $BUILD_DIR"
