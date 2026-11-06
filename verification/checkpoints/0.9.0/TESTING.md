# Dungeon & Stone testing

Godot 4.5.1, macOS Apple M1 Compatibility renderer. Updated 2026-11-05. Automated simulation, graphical scene input, rendered inspection, exported startup and human playtesting are distinct kinds of evidence.

## Commands

From the source project, with the Godot executable available:

```sh
export GODOT_BIN=/path/to/Godot
"$GODOT_BIN" --headless --path . --editor --import --quit
python3 scripts/run_tests.py --godot "$GODOT_BIN"
"$GODOT_BIN" --path . -- --smoke
```

`run_tests.py` runs the full800-map sweep and graphical tests, saves logs plus hashes in `verification/results.json`, and fails on engine/script errors or timeout. `--headless-only` skips graphical suites; it cannot establish real graphical input behavior. Individual suites run with `--script res://tests/NAME_test.gd`; add `--headless` for non-graphical suites.

Set `GODOT_BIN` to your local Godot 4.5.1 executable, or put `godot` on PATH. Normal source launch uses `--path .`. Explicit `-- --dev` enables assisted supply/essence/encounter tools; using them marks state assisted. These are not normal progression.

## Executed results (0.9)

| Suite | Checks | Evidence / limits |
| --- | ---: | --- |
| content | 219 | 219 checks; 0 failures; 8 spawnable species; 5 obtainable essences |
| reference_content | 83 | 83 checks; 0 failures; 9 researched essences; 5 researched areas |
| character_art | 437 | 437 checks; 0 failures; contact sheet /Users/lukastroger/Documents/Codex/2026-11-02/al/outputs/dungeon-and-stone/verification/character-art-contact-sheet.png |
| city_life | 334 | 334 checks, 0 failures. Service routing, generated identities and deterministic provisional appearances. |
| city_simulation | 160 | 160 checks, 0 failures. Actual wrappers/services, generated recruitment routing and cosmetic persistence. No player save slots used. |
| reference | 249 | 249 checks, 0 failures. Runtime coverage uses assisted fixtures; combat numbers and geography remain provisional. |
| combat_rules | 46 | 46 checks, 0 failures. Current numerical algorithms and interactions; combat coefficients remain provisional. No save files used. |
| essence_lifetime | 36 | 36 checks, 0 failures. Thirty-minute lifetimes on a minute-resolution simulation clock; fixtures isolate rules, not balance. |
| world | 4830 | 4830 checks, 0 failures; 800 maps across Crystal Cave, Goblin Forest, Land of the Dead and Black Rock Mountain |
| progression_magic | 127 | 127 checks, 0 failures. Assisted arenas/XP boundaries; actual recruitment, kills, casts, rounds and JSON restore. |
| save_validation | 701 | 701 checks, 0 failures; encoded/decoded real snapshots, malformed structure, IDs, maps, nested tags and nonmutation. No save files written. |
| campaign_persistence | 55 | 55 checks, 0 failures. Checksum-valid structural corruption, healthy backup preservation, atomic refusal and rejected-restore RNG conservation; slot 97 restored. |
| settings_validation | 126 | 126 checks; 0 failures |
| adventurer_generation | 512 | 512 checks, 0 failures. Twelve persistent generated identities, two per race; cosmetic RNG only. No player saves used. |
| companion_identity | 1451 | 1451 checks; 0 failures. Generated campaign/city/recruit identities, JSON saves, death and mage restrictions; assisted fixtures, no player saves. |
| essence_preservation | 167 | 167 checks, 0 failures. Assisted rule fixtures, actual recruitment/shop/sealing/absorption/storage/selling/JSON restore; no normal save files written. |
| clock_progression | 110 | 110 checks, 0 failures. Actual action/camp/food/portal rules and schema2-to3 JSON migration; grid timing is estimated, no human balance claim. |
| expanded_essence | 114 | 114 checks, 0 failures. Partial sourced components; grid timings/range/drop estimate are not canonical coefficients. Assisted fixtures, no player saves. |
| racial_rules | 168 | 168 checks; 0 failures. Purchased Undying1 only; not six complete racial trees. |
| racial_integration | 33 | 33 checks, 0 failures. Actual city fee, recovery, race guards, JSON and bench persistence; numerical conversion is provisional. |
| dungeon_width | 406 | 406 checks, 0 failures;80 seeded wide-route maps,3x3 footprint connectivity and legacy/large saves. |
| audio_lifecycle | 6 | 6 checks, 0 failures. Actual local playback/crossfade shutdown; silence via zero volume, no settings or save writes. |
| turn_safety | 45 | 45 checks, 0 failures. Guard/incapacitation, stationary enemy field and life-state save invariants; assisted arenas. |
| numbered_rules | 42 | 42 checks; 0 failures. |
| numbered_catalog | 75 | 75 checks, 0 failures. 3 bundled researched definitions; 1000 synthetic rows test validator capacity only. |
| beastman_progression | 244 | 244 checks, 0 failures. Actual purchase, absorption, sealing, destructive ritual, attacks and JSON/bench persistence; assisted funds/drops/level; numeric estimates remain provisional. |
| numbered_integration | 221 | 221 checks, 0 failures. Assisted funds/arenas; actual market, gear, hits, protection, knockback, technique routing, transfer, JSON/bench persistence and innate fear. Numerical coefficients remain provisional. |
| profession_rules | 175 | 175 checks; 0 failures. Basic human magic entry only; other careers remain unsupported. |
| profession_integration | 223 | 223 checks, 0 failures. Actual assessment, tuition, spell use and JSON/bench persistence; assisted funding/aptitude seeds; basic Human magic only. |
| stat_catalog | 518 | 518 checks, 0 failures. All101 declared stats have live consumers or informational indices; verified relationships and provisional qualitative/numerical interpretations are disclosed separately. |
| stat_rules | 93 | 93 checks, 0 failures. Generic fixture registry; stacking is an explicit implementation rule. |
| stat_integration | 121 | 121 checks, 0 failures. Artificial modifiers verify consumers; coefficients remain explicit reconstruction rules. |
| stat_combat_rules | 160 | 160 checks, 0 failures. Point conversions and critical eligibility are reconstruction estimates. |
| stat_physiology | 170 | 170 checks, 0 failures. Pure helpers; provisional qualitative effects and numerical coefficients are explicit; context helpers grant no spirit acquisition. |
| stat_mental_rules | 192 | 192 checks, 0 failures. Confirmed and provisional effects labeled separately; numerical curves are estimates. No save files used. |
| stat_expansion | 112 | 112 checks, 0 failures. Synthetic fixtures verify combat, resources and evidence-based awareness; coefficients remain estimates. |
| stat_indices | 111 | 111 checks, 0 failures. Informational estimated summaries only; source-verified coefficients are labeled separately. |
| spirit_rules | 62 | 62 checks, 0 failures. Contract lesson and all numerical conversions remain explicit reconstruction choices. |
| stat_remaining_integration | 71 | 71 checks, 0 failures. Actual consumers and persistence under assisted fixtures; provisional mechanics are not novel-exact rules. |
| spirit_stones | 104 | 104 checks, 0 failures. Pure contract/guidance rules; actual market/combat integration is covered separately; Wind scope, compressed price and guidance coefficients are explicit reconstruction choices. |
| spirit_stone_integration | 138 | 138 checks, 0 failures. Actual market, commands, combat, clock and save validation exercised; funds and seed selection are explicit test assistance. |
| city_map | 141 | 141 checks, 0 failures. Authored geometry and native mouse/key/controller events; no service simulation claims. |
| ui_input | 36 | 36 checks, 0 failures. Parsed keyboard/mouse events and scene-tree geometry; not human or screenshot testing. |
| city_ui | 67 | 67 checks, 0 failures. Real parsed input, actual services and isolated slot98; no human playtest claim. |
| magic_ui | 91 | 91 checks, 0 failures. Parsed keyboard/mouse, actual scene geometry and graphical targeting capture when available. |
| preservation_ui | 155 | 155 checks, 0 failures. Actual parsed mouse/keyboard confirmation and recipient flow; assisted drop/supply fixtures, not a human playthrough. |
| expansion_ui | 29 | 29 checks, 0 failures. Parsed sanctuary/map controls and rendered expanded cave/golem; assisted fixtures. |
| racial_ui | 246 | 246 checks, 0 failures. Parsed real market/equipment/seal/ritual/cancel/removal/fear/protection controls at100/120%; assisted funding and bound essence; slot99/settings restored. |
| stat_ui | 91 | 91 checks, 0 failures. Actual STATS/toggle/hover/preview/equip controls at100/120%; assisted modifier fixture; all registered stats have consumers, with provisional effects disclosed; settings/slot99 restored. |
| stat_senses_ui | 6 | 6 checks, 0 failures. Rendered anonymous sound/danger fixture at100/120%; no parsed input or human playthrough claim; no save/settings writes. |
| stat_actions_ui | 189 | 189 checks, 0 failures. Actual jump targeting and spirit confirmation controls at100/120%; assisted modifier fixture; all registered stats have consumers, with provisional effects disclosed; settings/slot99 restored. |

**51 source suites/14,298 checks, 31 compiled-app suites/5,680 checks, zero failures.** See versioned records and `verification/results.json`/`exported-results.json`. Fixtures supply funds, encounters, modifiers and favorable seeds; these are not extra content, natural balance or a human campaign. Normal player slots1–3 are not written. Test slots96–99/settings are preserved/restored. The racial/stat UI suites now place durable test backups in `user://test_backups/` rather than relying on this workspace's scratch path. An earlier aborted slot99 fixture had an unrecoverable in-memory backup; only its verified isolated fixture was removed, with normal slots untouched.

## Rendered checks

Source smoke captures seventeen screens; new preservation captures20–26 cover the compact city without companion figures, generated recruitment, sealing, filled inventory and opening at100/120%. Screens27–31 add expanded geometry, zoomed maps, the controller telegraph and sanctuary. The full-layout capture deliberately grants exploration knowledge for inspection only. The spell UI suite adds `screenshots/19-ice-spear-targeting.png`. Inspected city, customization, enlarged pack/settings, party, target grid, status and portal screens. Modal backgrounds are opaque, titles/Close remain visible, sprite drawing is clipped to map bounds and native 24/32px scaling is preserved. The exported title is captured separately after packaging. Source captures grant companions/essences for layout, not ordinary obtainability/balance.

## Manual checks and known limits

Create each race, customize, recruit different roles, compare/equip items, enter the Labyrinth, explore with keyboard and mouse, inspect enemies, fight, break contact, rest through closure, sell loot, prepare for the next opening and reload each supported state. Check that companions can be manually selected and cannot act while paralyzed. Inspect actual audio category/mute changes and reduced motion. Repeat on a physical controller.

Full source-correct racial progression, a source-scale economy, rifts/deeper floors, bosses/ending, faithful taxes, further generated-companion professional/relationship progression and ordinary balance remain unfinished. The minute-resolution clock is integrated; waiting versus movement resource/status cadence and action/recovery balance still require calibration. Numerical estimates are documented. An unassisted full campaign and all-ending tests are unavailable because that campaign is not implemented. Ordinary graphical startup/shutdown and the audio lifecycle suite pass; Godot Movie Maker capture still emits a WAV/playback ObjectDB warning at shutdown. This capture-only issue is unresolved.

## Packaging

```sh
bash scripts/build_macos.sh
```

Set `GODOT_BIN` and `GODOT_MACOS_TEMPLATE` to the Godot executable and matching official macOS template. Defaults are `godot` on PATH and `.cache/godot-macos-template.zip`; output goes to `builds/`. The script imports a snapshot, exports the official universal runtime, embeds notices/hashes, normalizes plist XML, ad-hoc signs/verifies, executes 20 headless startup frames and verifies the DMG. Build/sign in `/private/tmp` because cloud Documents metadata can invalidate app signatures. Run the actual packaged gameplay checks after export:

```sh
python3 scripts/verify_exported.py --app "/path/to/Dungeon & Stone.app"
```

This verifies the exported gameplay hashes match source, loads the bundled compiled PCK and executes the external assisted suites. Results and PCK/executable hashes are recorded in `verification/exported-results.json`; see BUILD_REPORT.md for the completed build evidence. These headless compiled tests do not establish graphical input or human balance. No Apple notarization or Windows/Linux execution is claimed.

Source packaging is reproducible: `python3 scripts/package_source.py --output builds/Dungeon-and-Stone-source.zip`. It writes a temporary archive, verifies CRCs and required files, then replaces the output; Git data, caches, saves and export credentials are excluded.

## 0.8 stat and action inspection

Screens32–35 cover racial/Numbered/profession controls;36–37 show resolved stats and equipment comparison;38 anonymous sound/danger;39 jump targeting with all three techniques at enlarged text;40 Fairy spirit controls. Frames were inspected for clipping/overlap and hidden-identity leakage. The command row reserves26pixels before the log at enlarged text. The actual packaged title is screenshot14.

Short ordinary exported startup now reproduces the WAV/playback resource warning also seen during Movie Maker capture; an orphan Master string remains. No script/parse error or gameplay/save blocker was observed. Audio lifecycle coverage is6checks, not proof that every backend shutdown warning is eliminated. Physical controllers, natural balance, all accessibility combinations, full campaign/endings, Windows/Linux and notarization remain unverified or unfinished.

## 0.9 additional-affinity checks

Spirit Stone pure rules104checks, actual integration138checks, and the enlarged parsed action UI cover market/item/currency/RNG conservation; cancelled/failed/successful attempts; Wind bow eligibility; one Natural Energy charge on hit or miss; secondary-proc exclusions; Fire deadline depletion; zero-capacity recalculation; JSON/bench/rejoin persistence; malformed-save nonmutation. Screenshot41 shows live Wind controls after stale failure-notice clearing. Contract seed selection/funds are assisted. Exact10% odds are sourced; Wind-only scope, +10 Accuracy and1 energy/shot are estimates. Source and actual compiled behavior pass; normal difficulty remains untested.

## Clean source extraction (0.9)

The distributed source ZIP was extracted into a new temporary directory without `.godot` or workspace caches. Godot4.5.1 imported it, the project launched for12 headless frames, and `stat_remaining_integration_test.gd` passed71 checks. Every gameplay `.gd`/`.json` matched the working copy. `verification/clean-source-results.json` records this separate evidence. The final repack changes documentation/verification metadata only; gameplay files remain identical.
