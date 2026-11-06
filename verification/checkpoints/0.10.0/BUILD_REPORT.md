# Dungeon & Stone — build verification

Checkpoint **0.10.0**, Godot4.5.1-stable, offline universal macOS runtime. The full campaign/final boss/endings remain unfinished.

- **58 source suites/19,776 checks**, zero failures, including800 generated layouts and80 wide-footprint samples. The final ceremony suite was extended and rerun after the full pass; gameplay stayed unchanged.
- **37 actual compiled-app suites/10,146 checks**, zero failures; bundled executable/PCK gameplay hashes match tested source.
- x86_64/arm64 universal runtime. Execution/title capture used Apple M1 Compatibility renderer; Intel execution is not claimed.
- All six homeland maps and source frames42–46 were inspected, including100/120% text, weapon choice and Dragon blessings/confirmation. The actual packaged title is screenshot14.
- Strict deep local ad-hoc signature and DMG integrity checks passed; this is not Apple notarization.
- Short ordinary shutdown and Movie Maker capture retain the known WAV/playback ObjectDB warning and orphan Master string. No new script/parse error was found; the shutdown diagnostic is unresolved.

Latest records: `verification/results.json`, `exported-results.json`, `startup-results.json` and `build-info-0.10.0.json`. Prior0.9 evidence is archived under `verification/checkpoints/0.9.0/`. Tests use assisted funds/levels/arenas; natural difficulty and human campaign completion are not established.

Counts:6race profiles,6city/homeland locations with36points/18local NPC roles,4dungeon areas,8species,5partial essence components,24items,12basic generated recruits,1spell,2spirit utilities,3Dragon blessing choices and1one-time weapon ceremony. The102 shared project stats have consumers/informational summaries; this is not the complete novel stat vocabulary. Racial trees and the campaign remain unfinished. Dwarf geography, visitor rights and ritual access/grid conversions are explicitly provisional.

The source ZIP passed CRC verification and clean extraction/import/startup plus513 homeland/ceremony checks. Evidence is recorded separately in `verification/clean-source-results.json`; final documentation/verification repacking preserves gameplay hashes.
