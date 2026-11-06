# Third-floor content evidence

This records the implemented **subset** in `game/third_floor_content.gd`. The third floor has more than these four habitats. Generated geography, ordinary HP/damage/armor/accuracy/evasion, grid ranges and cooldowns are estimates, not recovered novel rules. No complete replication is claimed. Display names follow established wiki names, with translation variants retained as aliases rather than duplicate species.

## Sources and supported claims

- [Novel chapters49–51](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-49-50-51/): Den of Beasts leads to Ironrock Hill. Iron Tusk is rank7, a large steel-tusked boar; a dwarf uses its absorbed essence's Counterweight to resist knockback. Wormstone, Iron Falcon and the hill guardian award2 first-speciesXP each. The group later meets Orc Warriors, an Archer and a Sorcerer. Frenzy multiplies physical resistance by3 for10seconds. Some machine translations call Iron Tusk an ant; no separate ant species is added.
- [Novel chapters52–54](https://slashrealm.com/novel/stabmtl/chapter-52-53-54/): Orc Colony precedes the central Witch's Forest, which surrounds the fourth-floor portal. The forest includes incorporeal enemies. The third floor closes on day15. These facts do not establish a one-to-one mapping from every second-floor region to the four habitats modeled here.
- [Novel chapter60](https://wuxiaworld.site/novel/surviving-the-game-as-a-barbarian/chapter-60/): Woodman and Wraith each award1XP; Owl Bear awards2XP. Cold attacks and a holy-water-coated weapon are used against ghosts. Only these researched species are added from this chapter; other named species await their own functional investigation.
- [Novel chapter61](https://bape-clothing.com/book/surviving-the-game-as-a-barbarian-2/chapter-61): Carnivaro, also translated Cannibalo, is a rank7 intelligent humanoid undead. It pursues chosen prey, uses a crossbow with unusually accurate Tracking Arrow, and places invisible Mana Mines. It is connected to lingering under Witch's Eye. Its complete combat kit is **not** implemented by this data module.
- [Novel chapters115–117](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-115-116-117/): Land of the Dead leads to Pitch-black Estuary, also called Dark River Estuary. Rank8 Frogmen carry harpoons. Slimy Mucus evades blunt weapons while mobile; cold enables a mace strike. Blades receive lesser evasion. Channels are shallow before the midnight flood, which lasts until06:00; red mounds serve as camps. Frogman Shaman eyes are a collection target; a specific combat spell is not described.
- [Wiki rank8 bestiary](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_8): secondary confirmation for Frogman Shaman rank and hill/orc species classification. [Wiki rank7 bestiary](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_7): secondary classification for Mighty Orc Warrior and Carnivaro, and Carnivaro's Hound skill. Wiki descriptions are used as leads/secondary evidence, not proof of unspecified formulas.

## Implemented definitions and limits

| Habitat | Species IDs (all prefixed `canon_`) | Rank / first-speciesXP |
|---|---|---|
| Ironrock Hill | `iron_tusk` |7 /3|
| Ironrock Hill | `wormstone`, `iron_falcon`, `ironrock_hill_guardian_soldier` |8 /2 each|
| Orc Colony | `orc_warrior`, `orc_archer`, `orc_sorcerer` |8 /2 each|
| Orc Colony | `mighty_orc_warrior` |7 /3|
| Witch's Forest | `woodman`, `wraith` |9 /1 each|
| Witch's Forest | `owl_bear` |8 /2|
| Witch's Eye encounter | `carnivaro` |7 /3|
| Dark River Estuary | `frogman`, `frogman_shaman` |8 /2 each|

Fourteen species provide29 first-speciesXP. Carnivaro is excluded from the ordinary forest pool; field rules own its encounter. Stable IDs are independent of translation aliases. The hill guardian is an ordinary species, not a substitute for the floor boss. No invented fourth-floor campaign, named boss or automatic source entry mapping is contained in this module.

The only new essence is **Iron Tusk**, and only its verified transferable Counterweight active is modeled. Unknown attribute modifiers remain empty.3SP,4tactical rounds and6-round cooldown are estimates. The active uses central `anchored` status; it must prevent displacement without inventing resistance bonuses. No Frogman essence is awarded: player transfer of its mucus passive has not been established by reviewed text.

Frenzy metadata targets shared raw `physical_resistance`×3, with estimated25 base resistance for orcs,2-round duration,3-tile radius and4-round cooldown. This preserves the documented stat affected rather than substituting attack damage or armor. Frogman metadata limits guaranteed blunt evasion to mobile targets; chilled/stunned/paralyzed/suppressed/toppled disable it. The2-round cold-stiffening conversion is estimated. Wraith physical immunity requires actual elemental/holy counterplay in the central resolver. Carnivaro's accurate ranged profile and pursuit are partial; Mana Mine and Hound remain explicitly incomplete. No unverified shaman spell, falcon flight immunity, tree roots or arbitrary animal skills are inferred from species names.

## Art and verification

Fourteen original code-drawn32px sprites each have two cached poses, hard alpha edges and a shared restrained palette. They are provisional visual interpretations, not copied novel/manhwa assets. No outside asset license is required. A rendered contact sheet was inspected at `work/third-floor-art.png`; characters have distinct silhouettes/weapons and transparent backgrounds, with no missing frames. Portraits, directional animations and final art remain unfinished.

Run:

```sh
/path/to/Godot --headless --path /path/to/dungeon-and-stone --script res://tests/third_floor_content_test.gd
```

Result: **199 checks,0failures** under Godot4.5.1. Checks cover provenance/estimate metadata, rank/XP, habitat ownership, incomplete-kit flags, selected effect descriptors, nonduplicated readable sprites, pose/cache identity and fresh nested definitions. This is pure data/asset verification; it is not evidence that all AI behaviors, field events, essence transfer interactions or a complete campaign were playtested. Runtime integration belongs to the corresponding integration suites.
