# Dungeon & Stone architecture

Godot 4.5.1 with typed GDScript. `main.tscn` starts a Control-based 640×360 scene. Simulation state is authoritative; presentation issues commands and reads results.

| Module | Responsibility |
| --- | --- |
| `game/stat_catalog.gd` | Canonical stat IDs, metadata, bounds, sources and explicit live/research status. |
| `game/stat_rules.gd` | Pure deterministic generic modifier evaluation and validation, with per-source breakdowns. |
| `game/stat_sources.gd` | Content adapters, actor sources, status contributions, derived stats and legacy display projection. |
| `game/simulation.gd` | Campaign/unit state, derived stats, combat and effects, AI, inventory/economy, travel/time, recruitment and serialization. |
| `game/content.gd` | Six race profiles, neutral starting profile, items, neutral adventurer templates, spells and institutions; validation. |
| `game/content_reference.gd` | Source evidence, chapter leads, unresolved fields and research-only definitions. |
| `game/reference_runtime.gd` | Explicitly enables supported areas/species/essences and supplies marked provisional numbers. |
| `game/racial_rules.gd` | Validates the irreversible purchased Undying I path and supplies its explicitly estimated natural-recovery bonus. |
| `game/world.gd` | 96×64 packed-room maps, three-/five-wide connections, loops, safe arrivals, legacy geography, connectivity, path geometry and line of sight. |
| `game/adventurer_names.gd` / `game/recruitment.gd` | Campaign-seeded unique names/looks; twelve saved offers; numerical template data always comes from code. |
| `game/city_life.gd` | NPC records and authorized service routing. The simulation owns charges and recruitment. |
| `game/city_map.gd` | Native pixel city drawing, locations, NPC hotspots, keyboard/controller focus and cosmetic animation. |
| `game/character_art.gd` | Seeded modular portraits and directional sprites, normalization and bounded texture cache. |
| `game/main.gd` | Screens, compact HUD, overlays, targeting, inspection, customization, input and feedback. |
| `game/save_validation.gd` | Structural/content checks for save payloads before restoration. |
| `game/persistence.gd` | Versioned JSON envelopes, SHA256 integrity, atomic replacement, backup recovery and settings. |
| `game/audio.gd` | Offline effects and city/dungeon ambience, volume/mute and crossfades. |

## Commands and effects

Presentation calls `move_unit`, `attack`, `use_technique`, `interact`, `camp`, `equip`, `buy`, `sell`, `recruit`, `absorb`, `seal_essence`, `absorb_sealed` and service commands. Mode, target, inventory, resources and restrictions are checked before changes. Techniques route essence effects through SP and spells through mana. Central hit/resistance/status/trigger methods explain outcomes in the log. Status order is explicit; depth is capped at four. `resolving_round` prevents companion commands from recursively advancing rounds.

State stores stable entity/content IDs, hero/party, inventory/storage, expedition loot, journal, time, maps and per-area memory. Physical essence drops retain absolute deadlines and area/position. Legacy quarter-hour absolute clocks/deadlines multiply by15 once after raw validation; cooldown/status/terrain round counters do not. A derived count cache is rebuilt from valid physical drops. Cosmetic choices never advance combat/loot RNG. Generated identity records persist in `recruits`; death is also recorded by stable `fallen_ids`, so changing names never revives an adventurer. Benched companions retain full validated unit state, preventing dismissal from deleting gear/essences or healing injuries. Companion records remain available to the recruitment menu; none are drawn on the city map. Hired/dead recruits cannot be hired again while active or fallen. Filled test tubes use ordinary inventory item IDs (`sealed_<essence_id>`); this automatically shares storage, weight, sale and save validation. Sealing validates contact, profession, time, supply and safety before consuming anything. Opening consumes the filled tube with no empty refund.

## Determinism and saving

World generation uses its own seeded generator. Simulation RNG state is serialized as a string to preserve 64-bit precision. Vector2i/Rect2i values use explicit tagged encodings. Payload version3 (minute clock; version2 migration supported) is separate from envelope schema 1. Restore validates before assigning the candidate state. Six recognized companion-ID aliases migrate after raw validation; generated names replace fixed story identities. Unknown IDs remain errors. Cosmetic identity restoration cannot inject saved combat stats into templates. Saving flushes a temporary file, verifies it, preserves a healthy primary as backup, then atomically renames the temporary file. Loading falls back to the backup on integrity failure. Settings use a separate atomic JSON file.

## Extension boundaries

Add source evidence first. Implement actual qualitative mechanics and consequential tests, then enable content in ReferenceRuntime and expose its UI. Mark numerical estimates; a research entry is not an implemented mechanic. Extract new modules when concrete system growth justifies it. Current combat/AI/economy still share one practical simulation module; this is not a completed ECS or generic rules language.

The macOS build script snapshots source, imports/exports using the official universal runtime, embeds notices/source hashes, normalizes plist XML, signs and verifies locally, executes exported startup and publishes DMG/ZIP containers. Build/sign outside cloud-backed Documents to avoid metadata changing app signatures.

`advance_time` processes expiry, food, resting recovery and closing boundaries chronologically and stops at closure. The map viewer uses its own zoom/pan presentation state. Passive-only essence entries are omitted from techniques; each active entry carries its actual essence-slot index. Scent contacts are anonymous derived data and never modify fog knowledge. Suppression breaks centrally in positive-damage resolution, while the controlled release cut uses a fixed-damage pipeline to avoid lethal damage amplification.

`end_phase` centralizes Guard across presentation inputs; `end_round` remains the internal resolver. Combat AP is spent only during combat. Save validation checks the hero’s mode/health/dead-state relationship to avoid loading a zero-health active softlock. GameAudio explicitly kills crossfades, stops voices and clears stream references on exit.

## Data-driven Numbered Items and racial entry

`game/numbered_items.json` is the bundled content registry. `NumberedCatalog` loads it once, validates metadata/unique numbers/source URLs/operation parameters, and builds ordinary equipment definitions. `NumberedRules` resolves equipped IDs, duration formulas and fractional mitigation. Simulation’s `activate_numbered` iterates declarative effect sequences; `numbered_on_hit` resolves additional weapon components without recursive procs. Shared `numbered_state[id]` stores charge, fractional remainder and cooldown across party transfers/saves. Catalog JSON joins runtime source hashes and the exported build manifest.

Ring skill suppression uses `active_essences`; ownership/capacity remain unchanged. The destructive Skadia command validates every condition before removing worn items or assigning the contract. `ProfessionRules` owns stable aptitude/eligibility; simulation owns currency, calendar advancement, instruction, mana and irreversible profession restrictions. Trained generated recruits are retained rather than reset to their recruitment template. SaveValidation checks these records on both active and benched units.

Developer screenshot capture forces a frame after a process frame; an occluded macOS window cannot leave it waiting indefinitely for frame_post_draw.

## Shared stat data flow

Content rows use `{stat, op, value}`; adapters assign stable modifier IDs and provenance. Saved actor rows explicitly include `id` and `source`. Primary attributes resolve first, followed by derived secondary baselines and their modifiers. Formula: `(base + sum(add)) × (1 + sum(increase)) × product(multiply)`, then `at_least`, rounding and registry bounds. Numeric overflow fails the complete evaluation. Muscle Mass's sourced Strength conversion is applied in the adapter; most derived conversion coefficients remain estimates. `STAT_REFERENCE.md` is generated from the registry, not a separate handwritten ruleset.

`GameSimulation.stat_breakdown()` and `stat_value()` expose permanent plus optional combat/status values. Permanent resolutions are cached outside saved state using a fingerprint of all effective inputs, including edited content modifiers and weapon range. Restoration clears caches and recalculates without refilling resources. SaveValidation validates combined stats at the actual campaign level before committing state. Fractional natural recovery carries in a separately validated saved remainder. `preview_equipment()` resolves a copy without mutating the campaign or RNG.

Numeric stats do not replace stateful effects. Numbered Items use validated data-driven operation sequences; prevented-damage storage, selected essence seals, rituals, displacement and triggers still require shared resolvers. Research-only stat entries are not gameplay features and never populate the working STATS panel.

## Provisional stat consumers (0.8)

`StatPhysiology` owns numerical physical/resource adaptations and a separate morphology pass; `StatMentalRules` owns cognitive/morale conversions and incoming status duration; `StatCombatRules` owns critical/sensitivity/cutting/pain helpers; `StatAwareness` owns bounded evidence-only sound propagation. `StatIndices` reads all contribution weights from the registry and produces informational totals. Group-index modifiers propagate once into the Combat Index without buffing the inputs again. Aggregate contributions retain provenance.

`SpiritRules` owns the provisional Fairy first contract, independent Natural Energy, illumination and safe spirit rest. Simulation delegates commands, processes30-minute drain deadlines and includes nearby illumination in visibility. SaveValidation checks structural spirit data and composed capacity before restoration. Skill sealing never removes stat ownership. The first-contract method is a reconstruction, while additional-element Spirit Stone rules remain a future source-based extension.

Generic jump commands validate origin/landing/LOS/AP before spending anything and reuse ordinary reaction/hazard resolution. Optional mist is walkable terrain; real elapsed time depletes saved breath before poison damage. Food/SP/mana fractions are saved; bounded validation rejects malformed reserves before state assignment. All102 registered project stats have a consumer or summary calculation, with explicit provisional metadata; this is not the novel's exhaustive vocabulary.

## Additional affinities (0.9)

`SpiritStones` owns validated acquisition, guidance eligibility and per-shot payment. GameContent exposes the market supply; GameSimulation wraps the commands, adds the Wind modifier through `combat_modifiers(unit,items)` and pays once after a normal attack. Keeping Wind conditional in the combat layer avoids legacy field compensation cancelling its Accuracy. Equipment comparison resolves eligibility for the candidate weapon. Shared energy depletion/rest/recalculation clears both active spirit flags; SaveValidation validates Wind and composed Natural Energy before assignment. Current Wind-only scope is provisional; additional affinity data should extend this mechanism without duplicating inventory/RNG/payment rules.

## Homeland visits and ceremonies (0.10)

`HomelandCatalog` stores six source-aware entries and36 semantic points; `HomelandMap` owns distinct38×17 collision/path grids and original pixel drawing. It emits interaction/position/exit requests and never pays, grants stats or advances campaign time. `HomelandRules` validates living actors/site/action/race and returns a preview descriptor; only its perform route invokes campaign commands. Simulation wrappers enforce actual point adjacency, retain each land's legal walking position, and prevent dungeon entry until city return. Optional `state.homeland` stores location/actor/visits/discoveries/usage/positions; absent fields preserve existing schema3 saves. Validator checks dynamic collision and rejects NPC/exit placements.

`ComingOfAgeRules` handles the one-time pre-expedition starter-club exchange with requirements/carry preflight. `DragonBlessingRules` handles three stable saved blessing IDs and atomic payment, without resource refill. `StatSources` scales only essence flat modifiers for Earth and supplies Sea/Volcano canonical rows. `skill_power_multiplier` is consumed through resolved technique durations, snapshot trap/field strength, scent tracking and learned-spell damage. Optional bounded `status_duration` on trap/field records preserves cast strength; old records default2. `SaveValidation` rejects malformed/foreign/underlevel blessing records before assignment. No parallel modifier engine or separate campaign is created.


## Early and third floors (0.12)

`early_floor_content.gd` / `third_floor_content.gd` define sourced species, selected essence components and original sprite generation. `ReferenceRuntime` merges only enabled catalogs; stable appended area IDs6–9 preserve1–5. `early_monster_rules.gd` owns pure summoning/topple/territory helpers; `third_floor_combat.gd` owns narrow defensive/support adapters. Simulation owns payment, RNG, damage/procs and calls these helpers. Physical immunity sets damage0 without bypassing elemental on-hit processing. Absolute blunt avoidance occurs before RNG; fixed damage/spells/DOT are separate contexts.

`world.gd` generates lower floors and dispatches `third_floor_world.gd` for96×64 third-floor terrain. `floor_connections.gd` attaches actual destination/position records and supplies choices/arrival anchors. Shared paths onfloor3 are presented as region paths rather than inter-floor teleporters. Exact compressed graph/coordinates are estimates. `third_floor_rules.gd` handles field nullification, Eye deadlines, timed cabin protection and tide/camp rules. Simulation chronological time splits at its deadlines; UI never owns the authoritative clock. Refuge blocks combat/jump/forestloot and movement explicitly leaves it. Camp recovery scales to remaining refuge time.

SaveValidation accepts optional water/torch/serial/refuge/field/Eye/path metadata, validates destinations against the enabled registry and third-floor geometry against its generator. Missing legacy optional fields migrate safely. Temporary summons are pruned without reusing monotonic stable IDs or dropping ordinary kill records. Floor memory retains maps/knowledge/enemy state. No background network or novel-content service is required.

Windows export uses `scripts/build_windows.py`, the official validated PE template and preset1. Exports run from isolated snapshots; source files are not rewritten by export. EXE and PCK travel together. `scripts/verify_windows.py` checks exported hashes and runs actual compiled Windows gameplay under Wine (or Windows itself), separately from source checks.
