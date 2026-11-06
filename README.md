# Dungeon & Stone

An unfinished offline desktop reconstruction of the game described in *Surviving the Game as a Barbarian*. Godot 4.5.1, typed GDScript, 640×360 with integer scaling.

## Play

Download the development packages from [GitHub Releases](https://github.com/ulimuli/Dungeon-and-Stone/releases/tag/v0.12.0).

Windows: extract the entire `Dungeon-and-Stone-Windows.zip`, then run **Dungeon & Stone.exe** beside its PCK. The64-bit Windows build is unsigned.

macOS: open the supplied `Dungeon-and-Stone-macOS.dmg`, then open **Dungeon & Stone.app**. The universal macOS runtime supports Apple Silicon and Intel; no editor, account or network is needed. The ZIP is an alternative. This local build is ad-hoc signed, not notarized.

New Game → choose one of six races → customize → explore your home → return to Rafdonia to prepare → enter through Dimensional Square. Click buildings or service operators for services. Companions are listed in Recruitment and are not drawn on the city map. Tooltips contain details; the journal records discoveries.

WASD/arrows move; click an enemy to attack; E interacts; Space ends the party phase; Tab selects an ally; 1–3 select techniques, then click a target. I inventory, P status, J journal, C eight-hour rest, Escape menu. Keyboard bindings and audio/text/motion settings are configurable.

Crystal Cave closes at 168 expedition hours; second-floor areas close at240; the third floor at360. Survivors return automatically. An arrival portal is not an immediate exit. Loose essences expire after about thirty minutes; confirm absorption while adjacent, or have a nearby mage seal one using a test tube before it expires. Death is permanent.

## Scope

Nine areas across floors1–3,35 species,7 partially reconstructed essence components,29 obtainable item definitions and twelve generated recruitable adventurers are integrated. A human mage can cast Ice Spear and seal dropped essences into single-use test tubes. Filled tubes survive extraction, storage and saves. Generated recruits keep their names and customized appearances; they do not use the novel’s companion identities. The six race profiles are selectable and visually distinct; their full racial progression is unfinished. There is no complete campaign, final boss or ending yet. Prices, starting stats, damage coefficients, tactical timing and recruitment placement remain explicitly unverified. See `PROGRESS.md` and `REFERENCE_RULES.md`.

New expeditions use96×64 maps with3-wide minimum corridors (forest5), variable chambers and alternate routes. Start a new expedition to get the expanded layout; an existing active save retains its old map. The map screen supports+/− zoom, Fit and drag-panning. Clock schema3 uses minutes and safely upgrades prior quarter-hour saves. Black Rock Mountain, scent tracking, breakable Suppression and purchased Undying I are integrated; full racial trees and the complete campaign remain unfinished.

The build includes three Numbered Items through a shared local JSON catalog: the Ring of the Frost Spirit, Guardian’s Braces and Club of the Snowfield. Character Status exposes Skadia’s destructive ritual, Draconian Fear controls and Human magic assessment/lessons. Use Remove on equipment before the Skadia ritual to preserve it. Artifact prices, tactical coefficients and professional fees/times are estimates; the full racial trees remain unfinished.

Shared stats: see [STAT_REFERENCE.md](STAT_REFERENCE.md) for the generated master list. Equipment, essences, racial bonuses and statuses share one modifier calculator. The registry contains102 registered IDs with consumers or informational summary calculations; it is not the novel's complete stat vocabulary.

Checkpoint0.9 completes consumers for this project catalog, including provisional interpretations of unspecified effects. Jump with V or JUMP, then click a legal landing; Escape cancels. Fairies can confirm provisional Fire Spirit instruction in Character Status, then manage illumination and its separate Natural Energy. Optional mist pockets use breath and poison exposure. All qualitative/numeric estimates are documented;102 is not an exhaustive count of novel stats.

Spirit Stones can be purchased at the market and used from a contracted Fairy’s Character Status. Attempts consume one stone with10% success. The implemented secondary affinity is Wind; equip a bow, activate Wind Guidance, and each attempted shot gains10 Accuracy and spends1 shared Natural Energy. Wind-only scope and bonus/cost are estimates; odds and the additional-contract mechanic are sourced.

## Source launch

Use Godot4.5.1. Import `project.godot` in the editor once, or run `Godot --headless --path . --editor --import --quit`, then `Godot --path .`. The packaged app includes its engine and needs none of these source tools. See TESTING.md for checks and export commands.

Checkpoint0.10 adds six walkable racial locations with36 interaction points. New characters start in their home; use RAFDONIA to reach city services, then LANDS or the city gate to revisit. Click a person/landmark to approach and speak, or walk beside it and press E/Space. The actor selector chooses a living party member for rites. Young Barbarians can choose their first weapon once; level2 Draconians can review the three Dragon blessings. The forge district, visitor rights, travel abstraction and ritual access prices are provisional. Sources and remaining limits are in `research/homelands.md`.

Third-floor entry: eastern Den route leads to Ironrock Hill; western Dead route leads to Dark River Estuary. Paths lead toward Orc Colony/Witch’s Forest. Purple trees offer expiring cabin refuge; red estuary mounds permit high-tide camps. The central fourth-floor tower remains unavailable. Exact travel scale and geography are provisional.

Windows builds: `python3 scripts/build_windows.py --godot /path/to/godot --template /path/to/windows_release_x86_64.exe --output builds`. Fetch the official template with `python3 scripts/fetch_windows_template.py --output /path/to/windows_release_x86_64.exe`. Wine verification is optional and separate from building.
