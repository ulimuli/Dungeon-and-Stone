# Dungeon & Stone — build verification

Checkpoint **0.9.0**, Godot4.5.1-stable, offline universal macOS runtime. Full campaign/final boss/endings remain unfinished.

- **51 source suites/14,298 checks**, zero failures, including800 generated layouts and80 wide-footprint samples.
- **31 actual compiled-app suites/5,680 checks**, zero failures; bundled executable/PCK gameplay hashes match tested source.
- `lipo` reports x86_64/arm64. Execution and title capture used Apple M1 Compatibility renderer; Intel execution is not claimed.
- Source frames36–41 show stats/equipment, anonymous senses, jump and Fire/Wind controls at100/120% text. Packaged title is screenshot14. Inspected for text/layout/target visibility issues.
- Strict deep local ad-hoc signature and DMG integrity checks passed. This is not Apple notarization.
- Short ordinary shutdown and Movie Maker capture can report a retained WAV/playback pair and orphan Master string. Audio lifecycle tests pass, but the diagnostic is unresolved; no script/parse failure was found.

Latest records: `verification/results.json`, `exported-results.json`, `startup-results.json` and `build-info-0.9.0.json`. Previous0.8 records are retained under `verification/checkpoints/0.8.0/`. These are assisted automated checks, not human campaign completion or natural difficulty.

The catalog contains101 project stats with consumers/informational summaries, not every novel substat. Unspecified qualitative effects, most coefficients, initial Fire acquisition and current Wind-only secondary scope are explicitly provisional. Content counts:6races,4areas,8species,5partial essence components,24items,12basic generated recruits,1spell,2spirit utilities; no completed campaign ending. Windows/Linux and physical controllers still need execution/playtesting.

The source ZIP passed CRC checks and clean extraction/import/startup plus71 stat integration checks. Gameplay source hashes matched the final working copy; metadata/documentation was finalized afterward without changing gameplay.
