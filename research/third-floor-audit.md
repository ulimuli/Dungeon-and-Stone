# Third-floor source audit

Research date: 2026-11-05. The novel takes priority; accessible translation mirrors are used where Hen fails. Translation aliases are recorded rather than treated as different places. This is an evidence inventory, not a claim that every entry is implemented.

## Floor graph: verified corrections

| Second-floor route | Third-floor entry area | Evidence |
| --- | --- | --- |
| Den of Beasts | Ironrock Hill / Steelrock Hill | Novel 50–51 explicitly describes the arrival. [Translation](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-49-50-51/) |
| Land of the Dead | Pitch-black Estuary / Dark River Estuary | Novel 115 explicitly identifies the starting point, reached through the northernmost second-floor portal. [Translation](https://freewebnovel.com/novel/surviving-the-game-as-a-barbarian/chapter-115) |
| Goblin Forest | Greentail Marsh / Greentail Wetlands | Novel 505 takes the Goblin Forest route through this lizardman habitat; exact immediate arrival geography is not stated. [Translation](https://freewebnovel.com/novel/surviving-the-game-as-a-barbarian/chapter-505) |
| Rock Desert / Black Rock Mountain | Twilight Slope | Novel 313 explicitly names this route, then continues toward Thornreed Field. [Translation](https://slashrealm.com/novel/stabmtl/chapter-313-314-315/) |

The Forest→Greentail pairing is a strongly supported route sequence, not an explicit claim that no intermediate field exists. Den and Dead are explicitly called starting points.

Novel 51 describes a connected third floor with different starting points and a central fourth-floor portal, typically three to four days of movement away. Area boundaries are relatively quiet because monster territories overlap. Do not implement second-floor portals as arbitrary selectors for all third-floor destinations.

The Witch’s Forest surrounds the central fourth-floor portal (novel 53). It is not the Land of the Dead’s entry area. Orc Colony is an interior hunting region reached after Ironrock Hill. Exact adjacency among every entry area remains unspecified in the sources read here; any compressed connector graph must be marked an implementation estimate.

## Scale and clock

Novel 53 explicitly gives closure at the end of days 7, 10 and 15 for floors one, two and three. Novel 115 independently confirms day-15 closure, and shows reaching the central tower shortly before that deadline. Third-floor travel must not reset the expedition clock.

Novel 505 says Pilgrim’s Path has over ten fields. The wiki lists only four headings and is not a complete floor inventory. Six named playable areas still do not constitute a complete third floor. Do not claim a complete map merely because all four second-floor routes are wired.

## Environment and mechanics with direct evidence

- **Ironrock Hill:** highland/cliff terrain; rank-seven Iron Tusk/Iron Ant translation alias is a boar-shaped charging monster with steel tusks and Counterweight knockback immunity. Novel 50–51 also names Wormstone, Iron Falcon and Steel Hill Guardian. Exact grid dimensions, populations and full essence packages are absent.
- **Orc Colony:** novel 51 describes forest habitat and coordinated groups; novel 52 distinguishes outer hunting grounds from the Great Warrior habitat. Clan interference in that specific expedition is a story circumstance, not proof that every month must contain the same blockade. Do not invent a palisaded settlement from the word colony.
- **Witch’s Forest:** novel 56–57 describes damp, cold thorn bushes, coiling vines and moving trees. Its field applies disorientation, auditory/visual hallucinations and pain amplification while nullifying non-field status effects. Sensory distortion has actual navigation consequences. [Novel 55–57](https://slashrealm.com/novel/stabmtl/chapter-55-56-57/)
- **Witch’s Eye:** after 84 hours, the field reaches level five; standing still attracts rank-seven Cannibalo. The stationary interval shrinks from about an hour initially to about ten minutes then. A rope prevents companions becoming separated. Do not treat these examples as a fully specified continuous scaling formula. [Novel 61](https://freewebnovel.com/novel/surviving-the-game-as-a-barbarian/chapter-61)
- **Pitch-black Estuary:** shallow dirty channels cross damp ground; river crossing makes noise. Water rises toward midnight, stays high 00:00–06:00, and recedes at six. Reddish dry mounds are camp refuges. Novel 115 gives Frogmen and a Frogman Shaman collection request; full shaman spells are not specified there.
- **Greentail Marsh:** lizardman habitat is explicit in novel 505. Exact water hazards, all species/ranks and the connection immediately after the entry portal need further primary research.
- **Twilight Slope:** route identity is explicit in novel 313. Detailed terrain, lighting and its ordinary species pool remain unverified. Its name alone does not establish lava, permanent dusk, fire damage or a movement penalty.
- **Thornreed Field:** west of the central Witch’s Forest in novel 313. Later novel 458 describes shoulder-high thorn reeds, broadly flat/open ground and reeds deliberately burned before a raid. Do not apply that burned state to every expedition. [Novel 458](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-458/)

## Landmarks and special content: implementation boundaries

**Witch’s Cabin:** novel 63 confirms entering through a glowing tree by hand contact; the separate refuge contains grass, flowers and a cabin, with five occupants maximum and entrance closure at capacity. [Novel 63](https://freewebnovel.com/novel/surviving-the-game-as-a-barbarian/chapter-63)

Novel 64–65 directly confirms each corpse burned extends the cabin by eight hours, and seven cumulative offerings across explorers summon Riakis. Ordinary monsters disappear, chaos creatures replace them, the Witch’s field deactivates, and inter-floor portals close. The same passage places Orc Colony east of the forest, across an open plain. [Novel 64–66](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-64-65-66/)

Novel 62 directly confirms random refuge appearances lasting eight hours, with field effects disabled and no monster spawns. Exact respawn intervals and whether there is only one concurrent refuge are unspecified; the wiki’s immediate eight-hour relocation interpretation should not silently become a canonical fixed schedule. A static hut granting arbitrary buffs would not reproduce the known rules. [Novel 62](https://noveltune.net/book/surviving-the-game-as-a-barbarian-2/62.html)

**Central tower:** novel 115 shows a giant tower with a multicolored portal at its doorway. Entry synchronization matters for parties. Providing a landmark without fourth-floor simulation must remain explicitly incomplete, with no fake win or invented guardian gate.

**Sculpture Temple:** novel 505 describes headless-statue ruins, an unpopular side route containing rank-seven Nameless Statues. Unanswered Prayer can temporarily gain a random essence below rank five; Distortion permits material gathering. This location is outside the initial four-heading wiki list and cannot be counted unless integrated.

**Orc altar / Hundred Colors rift / Riakis:** wiki references 39, 298 and 458–464 respectively. These are separate special-content projects. Ordinary travel to floor three is not gated by defeating Riakis or sacrificing corpses. Do not advertise a complete floor lord, rift or transferable essence based only on its name and a simplified attack.

## Remaining research and next implementation checks

1. Preserve the verified four entry routes and central Witch’s Forest structure; validate return anchors, lower-floor closure and a single absolute clock.
2. Integrate source-backed ordinary monster roles and actual transferred abilities with shared stats. Keep unspecified damage, costs, distances and encounter rates labelled estimates.
3. Add timed estuary refuges and an actual cabin refuge lifecycle before expanding cosmetic interactions. Verify starvation/fatigue and camp safety cannot softlock an expedition.
4. Research Twilight Slope and Greentail ordinary pools, remaining fields, exact cabin respawn cadence, Orc altar and rift before calling floors 1–3 a faithful complete replica.

Current early-floor checkpoint before this expansion: 21 species yield 26 first-species XP, below level-three threshold 30. Repeated kills do not solve that ceiling. First portal-opener +2 XP exists in the novel, but competition, repeat eligibility and monthly cadence are unresolved. Do not silently lower the level threshold to conceal missing content.
