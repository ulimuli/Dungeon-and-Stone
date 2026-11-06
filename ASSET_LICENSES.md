# Asset provenance and licenses

Dungeon & Stone uses original project artwork, interface rendering and synthesized audio. The novel and the supplied public wiki inform researched names and mechanics; the supplied manhwa page informs the general interface direction. No novel passages, comic panels, downloaded character illustrations, commercial sprite packs or streamed recordings are bundled as game assets. Generated adventurer appearances, map geometry and city architecture are provisional visual interpretations rather than exact reproductions of reference-media art.

## Original project artwork and audio

The original generated pixel artwork and synthesized audio assets are dedicated under CC0 1.0. This includes the pixel artwork produced at runtime by CharacterArt, the city artwork drawn by CityMap, and the native24px empty/filled test-tube symbols and native32px Stone Golem sprite drawn by the interface. Checkpoint0.6 also draws original native24px Frost Spirit Ring and Guardian’s Braces icons at runtime. The dedication applies to original project assets, not the separately licensed fonts, engine or referenced fiction.

The current local asset inventory is **55 PNG files and 11 PCM WAV files**, excluding import metadata and the two font files. `assets/manifest.json` records actual filenames, dimensions, sound durations and provenance; `assets/classic_manifest.json` lists the classic presentation textures. These are file counts, not claims about unique gameplay content.

- Raster artwork includes dark stone terrain, silver inventory/UI symbols, seven original creature silhouettes, ordinary exploration icons, a title background and an application icon. Skeleton and Goblin Swordsman are native 32×32 pixels; the other five creature sprites are 24×24. Terrain and classic interface symbols are generally 16×16. Render with nearest filtering and integer scaling.
- `game/character_art.gd` generates original native 64×64 portraits and32×32 transparent world sprites. Saved appearance data selects race silhouettes, skin tones, hair, eyes, clothing, face details, body presentation and accessories. Textures are generated locally and cached; no external image service or downloaded face is required.
- `game/city_map.gd` draws original city buildings, streets, landmarks and service markers directly. NPC and player figures use CharacterArt. This authored city map is an implementation interpretation of Rafdonia.
- Nine local synthesized sound effects cover move, step, hit, death, loot, UI, cast, blocked and heal. Two local looping ambience tracks cover city and dungeon. All are 22,050Hz stereo 16-bit PCM WAV, without external samples. `game/audio.gd` manages playback and separate volume controls.

Generated character art is crisp modular pixel artwork; it remains provisional production art, with restrained walk frames and generic profession props. Artwork does not claim that every equipped item or every novel character ability has a dedicated illustration.

## VT323

`assets/vt323.ttf` is unmodified VT323, Copyright 2011 The VT323 Project Authors (peter.hull@oikoi.com), licensed under the **SIL Open Font License 1.1**. The complete notice and license are bundled in `assets/VT323-OFL.txt`.

Official source: https://github.com/google/fonts/tree/main/ofl/vt323

Binary: https://raw.githubusercontent.com/google/fonts/main/ofl/vt323/VT323-Regular.ttf

License source: https://raw.githubusercontent.com/google/fonts/main/ofl/vt323/OFL.txt

Font import settings disable antialiasing and subpixel positioning for crisp terminal glyphs; the font binary is unchanged. Preserve the full license and copyright notice when redistributing the font. The font may not be sold by itself.

## Pixelify Sans

`assets/pixelify_sans.ttf` is unmodified Pixelify Sans, Copyright 2021 The Pixelify Sans Project Authors (https://github.com/eifetx/Pixelify-Sans), licensed under the **SIL Open Font License 1.1**. The complete notice and license are bundled in `assets/PixelifySans-OFL.txt`.

Official source: https://github.com/google/fonts/tree/main/ofl/pixelifysans

Binary: https://raw.githubusercontent.com/google/fonts/main/ofl/pixelifysans/PixelifySans%5Bwght%5D.ttf

License source: https://raw.githubusercontent.com/google/fonts/main/ofl/pixelifysans/OFL.txt

Preserve the complete license and copyright notice when redistributing the font. The font may not be sold by itself. Engine-provided fallback fonts retain their engine-distribution notices.

## Godot Engine

Godot 4.5.1 is distributed under the **MIT license** with additional notices for its bundled dependencies. Exact official 4.5.1-stable notices are included as `GODOT_LICENSE.txt` and `GODOT_COPYRIGHT.txt`. Preserve both with an exported runtime. These texts are the authoritative notices for the bundled engine and its third-party components.

The macOS packager embeds those engine notices, this provenance document and both font licenses in `Dungeon & Stone.app/Contents/Resources/Legal/`.

Any additional externally sourced asset must have its source, author, exact license, local path and redistribution obligations recorded here before distribution. Free access alone does not establish reuse permission.

The0.10 homeland maps, terrain textures, buildings, props, paths and effects are original procedural pixel drawing in `game/homeland_map.gd`, using the existing modular character art. No novel/manhwa illustrations or wiki images were downloaded or bundled. Descriptive research URLs in `research/homelands.md` support setting details; the sources are not redistributed as art or chapter text. These provisional code-drawn environments can be replaced without changing map collision or point IDs.

## Early/third-floor provisional visuals (0.12)

EarlyFloorContent and ThirdFloorContent generate original32px monster silhouettes/two poses; main.gd draws original terrain, memorial, flower, pit, purple-tree and mound pixels. These are provisional visual interpretations, not extracted novel/manhwa artwork. No novel text/manhwa panels are bundled. Windows runtime uses the same official Godot4.5.1 MIT/dependency notices and fonts as macOS; preserve Legal/ when redistributing.
