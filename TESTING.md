# Dungeon & Stone — testing

Godot4.5.1-stable. Checkpoint0.12.0. All69source suites/27,410checks,48compiled macOS suites/17,638checks and11actual Windows EXE suites/2,428checks underWine passed. These are assisted automated checks. No full campaign/ending exists to test. No native Windows or physical-controller claim follows from Wine/synthetic input.

## Commands

```sh
python3 scripts/run_tests.py --godot /absolute/path/to/Godot
python3 scripts/verify_exported.py --app '/absolute/path/to/Dungeon & Stone.app'
python3 scripts/verify_windows.py --wine /absolute/path/to/wine --package /absolute/path/to/Dungeon-and-Stone-Windows
# On Windows itself, omit --wine.
python3 scripts/package_source.py --output /absolute/path/to/Dungeon-and-Stone-source.zip
```

Build Windows using scripts/build_windows.py and the official template fetched by scripts/fetch_windows_template.py. EXE/PCK stay together. Build macOS with GODOT_BIN, GODOT_MACOS_TEMPLATE and DUNGEON_BUILD_OUTPUT environment variables then bash scripts/build_macos.sh. The build script uses an isolated snapshot and local temporary signing directory.

Compiled verification rejects gameplay-hash mismatches. verify_exported.py --suite NAME reruns a selected external harness and merges results only for the identical PCK hash; every expected suite must be present for all_passed. Headless UI tests skip screenshot-directory creation/capture in read-only compiled packs. Full source graphical tests capture/inspect frames separately. Current results are JSON records in verification/; historical checkpoints are archived beneath verification/checkpoints/.

## Current source suites

| Suite | Checks | Pass |
| --- | ---: | --- |
| content | 280 | yes |
| reference_content | 83 | yes |
| character_art | 437 | yes |
| city_life | 336 | yes |
| city_simulation | 165 | yes |
| reference | 249 | yes |
| combat_rules | 46 | yes |
| essence_lifetime | 36 | yes |
| world | 4830 | yes |
| progression_magic | 127 | yes |
| save_validation | 743 | yes |
| campaign_persistence | 55 | yes |
| settings_validation | 126 | yes |
| adventurer_generation | 512 | yes |
| companion_identity | 1451 | yes |
| essence_preservation | 167 | yes |
| clock_progression | 110 | yes |
| expanded_essence | 114 | yes |
| racial_rules | 168 | yes |
| racial_integration | 33 | yes |
| dungeon_width | 406 | yes |
| audio_lifecycle | 6 | yes |
| turn_safety | 45 | yes |
| numbered_rules | 42 | yes |
| numbered_catalog | 75 | yes |
| beastman_progression | 248 | yes |
| numbered_integration | 221 | yes |
| profession_rules | 175 | yes |
| profession_integration | 223 | yes |
| stat_catalog | 521 | yes |
| stat_rules | 93 | yes |
| stat_integration | 121 | yes |
| stat_combat_rules | 160 | yes |
| stat_physiology | 170 | yes |
| stat_mental_rules | 192 | yes |
| stat_expansion | 112 | yes |
| stat_indices | 111 | yes |
| spirit_rules | 62 | yes |
| stat_remaining_integration | 71 | yes |
| spirit_stones | 104 | yes |
| spirit_stone_integration | 138 | yes |
| homeland_catalog | 289 | yes |
| homeland_rules | 122 | yes |
| homeland_integration | 319 | yes |
| dragon_blessing_rules | 279 | yes |
| homeland_ceremonies | 194 | yes |
| early_floor_content | 313 | yes |
| early_floor_world | 4597 | yes |
| early_monster_rules | 136 | yes |
| early_floor_integration | 229 | yes |
| early_monster_integration | 141 | yes |
| third_floor_content | 199 | yes |
| third_floor_world | 1173 | yes |
| third_floor_rules | 93 | yes |
| third_floor_integration | 229 | yes |
| city_map | 141 | yes |
| ui_input | 36 | yes |
| city_ui | 67 | yes |
| magic_ui | 91 | yes |
| preservation_ui | 155 | yes |
| expansion_ui | 29 | yes |
| racial_ui | 246 | yes |
| stat_ui | 91 | yes |
| stat_senses_ui | 6 | yes |
| stat_actions_ui | 189 | yes |
| homeland_map | 3260 | yes |
| homeland_ui | 1010 | yes |
| early_floor_ui | 291 | yes |
| third_floor_ui | 121 | yes |

## Third-floor coverage and limits

Actual Sim commands exercise Den/Hill/Orc/Witch/Estuary/Dead/Cave travel, destination anchors, one clock, closed lower-floor rejection,15day extraction, field statuses/modifiers, cabin entry/expiry/protection/scaled camp, Eye pursuit, dry mound camping, Wraith/Frogman/Orc/Tusk combat, physical essence absorption/activation, JSON restoration and repeated summon cleanup. Actual first-kill rewards reach55XP/level3 without farming. Pure fixtures separately check field/hut/tide endpoints and generator topology across80seeds. UI tests parse real E/button/cabin/route actions at100/120% text and preserve player slots1–3/settings through isolated slot95.

Assisted placement, funds, revealed maps, synthetic arenas and chosen rare-drop seeds are deliberate fixtures. They prove interaction rules, not natural expedition difficulty or exact novel geography. Summons cannot earn rewards or supply capacity, and expired ones are pruned. Source/compiled tests reject script errors even when a suite prints zero assertion failures.

## Manual checks still needed

New character and full natural expeditions across all six races; long-play difficulty/economy; physical keyboard/controller layouts; native Windows OpenGL3.3 graphics/audio and Intel Mac execution; all accessibility/device combinations. Check frozen/saved UI transitions, low-water/food warnings, lower-floor expiry, purple-tree remaining time and actual elemental counters. Confirm every whole-species kit from sources before calling it complete.

Known: short native shutdown may log WAV/playback ObjectDB leaks; isolated lifecycle suite passes but this diagnostic is unresolved. No current tested critical save/progression crash is known. Bosses, crafting recipes, full third-floor geography/rifts/Riakis and endings remain unavailable rather than falsely counted as verified.
