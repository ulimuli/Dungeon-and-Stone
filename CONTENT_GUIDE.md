# Dungeon & Stone content guide

Use normal source names and stable snake_case IDs. Original-novel passages take priority over secondary summaries. Record URLs and evidence status beside each entry. Unknown numerical values must be marked, not described as verified rules. Do not copy chapter prose or comic panels into the asset catalog.

## Playable catalogs

`GameContent` supplies six races, an Adventurer starting profile, twenty item definitions, twelve neutral companion templates, one spell and two institutions. `ReferenceRuntime` enables four areas, eight species and five partial essence components. `ReferenceContent` additionally records unfinished research; its rows are not automatically enabled.

Items require name, kind, slot, nonnegative price/weight, description and provenance. Weapons/armor use actual range/power/armor/requirements; consumables must dispatch an implemented effect. Check the inventory/equipment/consumption paths and conservation on rejection. Material definitions require an actual obtainability source before counting them as obtainable.

Companions use neutral stable IDs and generated personal identities, as requested by the user. Add supported race/equipment/spell templates to `companions()` and generation automatically adds a unique saved offer. Never reintroduce the novel’s named companions as playable recruits. Do not claim the generated name vocabulary is a canonical racial language. Fees, timing, gear and attributes are provisional. Set `profession` explicitly; spells alone do not imply wizard restrictions. City operators are unnamed service representatives; appearance is visual interpretation. CityLife accepts only allowed service/open actions. Unsupported quest or relationship mechanics are not inferred.

Essence definitions retain source rank, passive/active effects, source stats, required resolver mechanics and uncertainty. Research zeroes mean unspecified. Implement conditional weapon requirements, targeting, cost, cooldown, duration, stacking, drawbacks and triggers before setting playable. Add tests for rejection without consumption, interaction boundaries, recursion and save restoration. Loose-drop position/expiry must survive transitions. Each enabled essence automatically receives a filled test-tube item definition. Empty tubes are a `supply`; filled tubes are recovered `material` items with `contained_essence`. Test sealing failure conservation, mage restrictions, no empty refund, extraction/storage/restore and explicit UI confirmation. Neither item alone adds a new essence family to content totals.

Spell definitions have effect, damage type, target/range, mana cost and cooldown. `techniques()` presents a common action list while keeping mana separate from Soul Power. Ice Spear is single-target cold damage; numerical parameters remain unverified.

Areas require source identity, floor and deadline, supported enemy IDs and meaningful portal connections. World generation must validate every walkable component, reachable portals, safe arrivals and legal placements across many seeds. A named region with generated geometry is not a source-exact map.

## Art and validation

CharacterArt's option catalog defines compatible modular appearance fields. Appearance uses independent seeds and a bounded cache. Keep sprites at native 24/32px and portraits64px; integer-scale them. CityMap owns visual geometry and selection only. Preserve readable silhouettes and reduced motion.

Run content and reference-content tests after changes. Run affected simulation tests for consequential mechanics and graphical tests for UI changes. Rebuild the content manifest from actual enabled catalogs; count only integrated, reachable content in progress reports. See `TESTING.md` and `ASSET_LICENSES.md`.

A documented passive-only essence may have an empty active effect when its passive resolver exists; do not display a fake0-cost technique or map filtered action indices to the wrong slot. Keep unknown kit components explicit. New map generation uses96×64; save validation also supports legacy38×25. Test large fog dictionaries and minimum3-wide route footprints before changing geometry. Racial progression must have a source-supported acquisition path, actual saved consequences and transactional currency checks; an unused six-race catalog is not progress.

## Numbered Items

Add a source-verified entry to `game/numbered_items.json`, using a stable ID and unique novel number. Copy a matching existing row and supply normal equipment metadata, exact name/number, sources and explicit estimate notes. Current passive operations are `seal_essence`, `damage_reduction` and `extra_weapon_damage`; active sequences support `cleanse`, `status_immunity` and `knockback`, with radius/target fields. Dwarf duration scaling is an explicit per-item parameter, never an automatic multiplier on ordinary weapon damage. Ritual operations require an implemented, sourced resolver.

All equipped items pass through shared rules. A new row using supported operations needs no item-specific combat/UI/save function. Add an operation only when an actual novel mechanic requires it, then test that operation’s boundaries and interactions. Preserve fractional mitigation and global item cooldowns when moving equipment between characters. Unsupported operations and malformed provenance fail validation. Update the actual content manifest/count assertion after integrating and testing obtainable content; never count research-only rows or the1,000 synthetic validation fixtures as game content.

Run `tests/numbered_catalog_test.gd`, `tests/numbered_integration_test.gd`, `tests/beastman_progression_test.gd` and the full suite after changes. Inspect the actual item/confirmation UI. Human profession changes also require active/bench persistence, aptitude conservation, resource and calendar tests.

## Shared stats and modifiers

Read `STAT_REFERENCE.md` before adding a numeric bonus. Its102 registered project IDs now have consumers or informational index calculations. Qualitative estimates and source-confirmed directions remain distinct; the catalog is not every novel stat. Add ordinary equipment/essence/racial bonuses using the same shape:

```json
{"modifiers":[{"stat":"attack","op":"add","value":8},{"stat":"attack","op":"multiply","value":1.25},{"stat":"armor","op":"add","value":3}]}
```

`add` gives a flat amount. `increase:0.25` contributes+25% to the summed increase pool. `multiply:1.25` is an independent×1.25 factor. `at_least` supplies a lower result bound. Content adapters generate stable IDs and source labels; directly saved actor rows must supply unique `id` and `source`. Distinct rows can share a source, but never an ID. No unknown stats, NaN/Inf or overflow are accepted. `base_stats` supplies intrinsic overrides, such as a weapon's reach; do not use an additive reach bonus to replace an intrinsic range.

Keep novel resistance points separate from `*_damage_reduction` percentages. Most formulas and numeric bounds are estimated and explicitly documented; do not turn a sourced aggregate-index coefficient into combat mitigation. Only import fully verified essence attribute packages; retain unknown packages as unknown. Cataloguing a name does not implement its mechanic. A new stat needs a real consumer, tooltip explanation, source/estimate metadata and consequential integration coverage before marking it live. Stateful mechanics still use the effect pipeline.

Regenerate the readable master list after editing the registry:

```sh
"$GODOT_BIN" --headless --path . --script res://scripts/export_stat_reference.gd
```

Run `stat_catalog`, `stat_rules`, `stat_integration` and `stat_ui` suites plus affected combat/persistence suites. Check that source breakdowns and equipment previews match actual results without granting free recovery or altering RNG.

Registry rows also define `aggregate_group`, `aggregate_weight` and `combat_index_weight`. Keep documented aggregate weights separate from damage percentages. A group/combat index is an informational output, not an attack buff. Add real modifiers to underlying stats when adding equipment. Physical dependencies resolve raw inputs→morphology→primary attributes→secondary stats→indices. Never run a provider twice or reapply equipment at the index stage.

Provisional effects are permitted for unrecorded rules, but must supply `known_effect`, `provisional_effect` and honest estimate metadata. Do not describe those interpretations as sourced novel formulas. Existing weapon `weapon_style` tags distinguish slashing/blunt/piercing/ranged for shared damage rules. Natural Energy is a separate current resource, gated by a real saved spirit contract; numeric capacity alone cannot grant a spirit.

Spirit Stones use the ordinary market/inventory supply plus `SpiritStones` acquisition/guidance rules. Failed attempts consume the item, invalid/cancelled/duplicate commands do not. Keep the exact10% roll separate from provisional affinity selection and the compressed price. Wind Accuracy is a conditional combat modifier; pay Natural Energy once per attempted normal bow shot, never in a recursive on-hit trigger. Test Fire depletion, zero-capacity recalculation, rest, equipment changes and JSON/benched persistence when adding affinities. Current content count24 includes this actual purchasable supply, not synthetic validator rows.

## Homeland points and rituals

Add setting/semantic data through `HomelandCatalog`, keeping stable point IDs and source URLs. Each row separates short in-world dialogue from estimate notes; authored operators must not impersonate novel companions. Geometry/slots/collision live in `HomelandMap.layout_for`; validate every point has a reachable free neighbor. Keep companion sprites out of central Rafdonia. Provisional locations must set `provisional_location`.

Add a rite only after its actual rules and persistence exist. `HomelandRules.interact` describes it without charging; `perform` rechecks and invokes the existing owner. New multi-choice rites use the shared choice→confirmation flow and optional choice_id. Save fields and delayed confirmations need rejection/nonmutation tests. Dragon effects use the shared StatSources pipeline; do not multiply equipment for Earth or weapon attacks for Volcano. Add future skill consumers explicitly and disclose grid conversion estimates.


## Early-floor extension points (0.12)

Add sourced identities and explicit unknown fields to EarlyFloorContent/ThirdFloorContent, then enable them in ReferenceRuntime. Do not infer full essence attributes from a monster name. A new ordinary species must have an actual region pool or environmental spawn and valid mana-stone rank item. Event species such as Carnivaro count only when their actual event can spawn them. Essence adapters automatically add a filled tube item; include this in totals.

New third-floor habitats require real terrain rules, broad connected generation, safe neutral connection sites and explicit FloorConnections routes. Compass grid placement/itinerary compression must remain labelled estimates unless directly supported. Add ThirdFloorWorld and actual Sim travel/JSON tests; merely adding a named region row is insufficient. Do not turn the central fourth-floor landmark into a fake ending.

Shared modifiers express Frenzy/field penalties; new stat bonuses belong in the master registry pipeline. New qualitative defenses belong in reusable context-aware helpers, with pre-RNG rejection and secondary-proc tests. Add actual UI interaction/frame checks at100/120% text. Original32px sprites must resolve in main's third-floor sprite fallback. Document missing full kits and evidence in research/third-floor-monsters.md.
