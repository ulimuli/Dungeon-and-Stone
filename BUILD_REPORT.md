# Dungeon & Stone — build verification

Checkpoint0.12.0,2026-11-06. Godot4.5.1-stable. Unfinished early-floor reconstruction; no complete campaign, final boss or endings.

- **69 source suites/27,410 checks**, all passed, including actual parsed graphical controls at100/120% text,800 baseline maps,100 early-floor maps,80 third-floor maps and80 broad-footprint samples.
- **48 compiled macOS suites/17,638 checks**, all passed using the actual universal executable/PCK. Gameplay hashes match source. Tests execute on AppleM1; Intel architecture is present, but execution is not claimed. Two headless UI harnesses were corrected to avoid writing screenshot directories into read-only packs; passing prior suites were retained only for the identical PCK hash.
- **11 compiled Windows suites/2,428 checks**, all passed using actual x86_64 Windows EXE/PCK under Wine11.0 on macOS. Native Windows graphics/hardware/controller testing is not established by Wine. GitHub read-only CI can build/test on a Windows runner separately; its result is not included in these local totals.
- Clean source ZIP CRC passed; fresh extraction imported, started and passed602 content/environment/actual progression-save checks, with identical gameplay hashes.
- Source frames47–58 inspect first-floor map/Den/flowers/torch/DeathFiend and all four third-floor terrain/refuge/map screens at100/120% text. Actual packaged title rendered and inspected. All14 third-floor32px monster silhouettes inspected. This is assisted automated coverage, not an unassisted human campaign playthrough.
- Universal macOS ad-hoc signature/deep strict verification and DMG integrity passed. Windows PE AMD64/template CRC and ZIP CRC passed. Neither Apple notarization nor Windows code signing is supplied.
- Known noncritical native short-shutdown WAV/playback ObjectDB diagnostic remains unresolved. No script/parse failure or tested critical save/progression defect remains. Full species kits, omitted habitats/rituals and campaign are explicitly incomplete.

## Artifacts and evidence

`Dungeon-and-Stone-macOS.dmg`, `Dungeon-and-Stone-macOS.zip`, `Dungeon-and-Stone-Windows.zip`, source ZIP, build manifests, launch text and SHA256SUMS are in the parent output directory. Windows ZIP contains EXE+PCK, launch instructions and Legal; extract all together. Final source/documentation repacking preserves tested gameplay hashes. Corresponding evidence lives in verification/results.json, exported-results.json, windows-results.json, clean-source-results.json and build-info-0.12.0.json.

Publication destination: https://github.com/ulimuli/Dungeon-and-Stone/releases/tag/v0.12.0 . This report records local build evidence; GitHub source/release publication is verified separately at the destination. The optional workflow has contents:read only and uploads run artifacts. It cannot publish releases or modify the repository.

Counts:6races,6racial city locations/36points/18localNPCroles,9dungeonareas,35species,7partialessences,29items,12generatedrecruits,1spell,3NumberedItems,102sharedregisteredstats,0completebosses/quests/endings. Unknown complete kits do not count as finished systems.
