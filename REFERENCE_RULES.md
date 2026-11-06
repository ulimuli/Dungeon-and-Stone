# Dungeon & Stone — source evidence

The original novel is authoritative. The supplied [Hennovel index](https://hennoveltranslations.com/novels/sgb/) currently jumps from Episode 5 to 52; missing chapters were not read there. Some evidence is indexed text or another translated-novel page. The full novel has not been read. The fan wiki is secondary. Exact fidelity is not established by familiar names.

## Implemented evidence

| Rule | Evidence and qualification |
| --- | --- |
| Starting level one; first Goblin gives1XP and a rank-nine mana stone | [Episode 4](https://hennoveltranslations.com/episodes/stgb-episode-4/), [Episode 5](https://hennoveltranslations.com/episodes/stgb-episode-5/); early panel observations. |
| Ordinary species XP only on first hunt | [Episode 456](https://hennoveltranslations.com/episodes/stgb-episode-456/), indexed passage. |
| Essence capacity rises with level | [Episode 264](https://hennoveltranslations.com/archives/episodes/stgb-episode-264): sixth level adds a slot; this does not provide a whole XP table. |
| Early cumulative XP thresholds | [Chapters 49–51](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-49-50-51/) count44XP and explicitly place the narrator at level 3 while listing6/30/150 with ambiguous level labels. Combined with level 1→2 in [Chapter 22](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-22-23-24/), implementation interprets6→2,30→3,150→4. This is a contextual interpretation, not an unambiguous table quote. Later thresholds stay unspecified. |
| First level increase adds 10 Soul Power | Chapter 22 at the linked translated-novel page. Physical growth is not inferred from this increase. |
| Ordinary rank-nine essence baseline0.01% | [Episode 457](https://hennoveltranslations.com/archives/episodes/stgb-episode-457), indexed passage. Used for currently supported ordinary rank-nine species; not a universal table for higher ranks or variants. The chapter's first-hunt talisman adds percentage points, but that item is not implemented. |
| Loose essence lasts about 30minutes | [Episode 374](https://hennoveltranslations.com/episodes/stgb-episode-374/), [Episode 518](https://hennoveltranslations.com/archives/episodes/stgb-episode-518), indexed passages. Current 15-minute beats are provisional and coarse. |
| Contact absorption and duplicate rejection | [Episode 622](https://hennoveltranslations.com/archives/episodes/stgb-episode-622/). Guardian upgrade exceptions remain unfinished; preservation is implemented separately below. |
| Floor deadlines, monthly opening and area populations | [Labyrinth](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth), [FirstFloor](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth/First_Floor), [SecondFloor](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth/Second_Floor). Secondary evidence: first 7 days, second 10 days. Geometry is provisional. |
| Goblin/GoblinArcher/Gnome qualitative essence effects | Source URLs/chapter leads stored per entry in `content_reference.gd`; secondary summaries unless marked otherwise. Numerical severity/cost/cooldown/range are not verified. |
| Ice Spear, a documented rank-eight single-target attack | Linked Chapters 49–51. The current damage coefficient, mana recovery, range, cost and cooldown are provisional; freezing is not inferred from its name. |

## Research boundaries

Portal-opening achievements reward the first opener and can repeat across expeditions; ordinary crossings do not earn XP. Chapter 22 and [Chapters 130–132](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-130-131-132/) support this distinction. Competitive first-opening/reset grouping is not implemented, so portal travel does not grant invented XP.

A removal price of 100,000 stones occurs in [Episode 221](https://hennoveltranslations.com/episodes/stgb-episode-221/); a universal rank-independent fee is not established. Removal/replacement remain unavailable.

## Essence preservation

- A mage seals a physical essence into a test tube; it can be carried home, transferred and sold: [Episode 159](https://hennoveltranslations.com/episodes/stgb-episode-159/), [Episode 457](https://hennoveltranslations.com/archives/episodes/stgb-episode-457), [Episode 621](https://hennoveltranslations.com/episodes/stgb-episode-621/), [Episode 315](https://hennoveltranslations.com/archives/episodes/stgb-episode-315).
- Sealing takes substantial uninterrupted work; the implementation blocks it during combat: [Episode 537](https://hennoveltranslations.com/archives/episodes/stgb-episode-537/). That episode also explicitly says wizards cannot absorb essences, while a necromancer can; therefore the restriction checks the mage profession, not every character with a spell. No unsupported mana cost is added to sealing.
- Tubes are not reusable; opening/breaking releases essence for inhalation: [Episode 243](https://hennoveltranslations.com/archives/episodes/stgb-episode-243). The game consumes the filled tube with no empty refund.
- Tubes are scarce/costly enough that preserving low-rank essences for resale can be uneconomical: [Episode 380](https://hennoveltranslations.com/archives/episodes/stgb-episode-380). No exact tube retail price, weight or sealing duration has been verified.

Temporary playable estimates: empty tube base price 1,000 on the existing compressed economy, 0.3 carry weight, one 15-minute beat to seal, filled rank-nine tube base value 300 / normal sale 100. These deliberately preserve the costly/non-reusable tradeoff. They are **not novel currency quotes**. The user authorizes sensible contextual estimates; future source-scale economy work must rebalance prices and obtainable income together. Treat a possible million-stone tube valuation as an estimate, never a recovered price. Exact coarse-clock timing remains unfinished.

## Economic anchors for the next pass

[Chapters 22–24](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-22-23-24/) directly quote about 20 stones for an ordinary rank-nine mana stone and 100 for a rank-eight Death Fiend stone; stone bread is 20, magic torch about 10,000, duo rank-nine bonding 15,000 for 24 hours. These anchors do not yet match the temporary game economy. [Chapters 16–18](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-16-17-18/) put ordinary first-expedition returns around 24–41 thousand and Bjorn/Erwen pure hunting below 100 thousand over seven days. Current finite spawn counts cannot support those price levels. Do not simply raise every price and make the opening unwinnable; add source-supported income and time systems in the same change. Higher later-context estimates do not replace the explicit early rank-nine quote without resolving the discrepancy.

Six races remain equally in scope. [Episode 52](https://hennoveltranslations.com/episodes/stgb-episode-52/) describes Human talent/professional paths, Fairy spirits, Dwarf numbered-item blessings, Beastman spirit-beast contracts and Barbarian Soul Engraving. [Episode 159](https://hennoveltranslations.com/episodes/stgb-episode-159/) supports Draconian Dragon Fear/language systems. These are not automatically unlocked starter powers. Their full progression is unfinished.

Playable companions are now generated adventurers with original personal names, per the user’s explicit request. Twelve templates cover two recruits per race without assigning the novel’s character identities, biographies or personal questlines. Their spell/weapon mechanics still require source evidence; generated appearance/name data makes no canonical racial-language claim. The city drawing is a navigable illustration, not a surveyed map of Rafdonia. [Episode 622](https://hennoveltranslations.com/archives/episodes/stgb-episode-622/) identifies District 7 Dimensional Square.

User-approved temporary numbers remain marked unverified: initial supplies/attributes, prices/living costs, recruitment fees, damage and accuracy formulas, status timings, spell/essence costs and grid scale. Keep these separate from sourced qualitative facts.

## Racial progression research boundaries

| Race | Supported next mechanics and constraints |
| --- | --- |
| Human | Talent/profession paths include aura, magic, priesthood and spirits ([Episode52](https://hennoveltranslations.com/episodes/stgb-episode-52/)). Do not give every human every profession or infer that only humans can be mages. Current generated mage is one conservative template. |
| Fairy | Spirit handling uses Natural Energy, distinct from SP and mana ([Episode463](https://hennoveltranslations.com/archives/episodes/stgb-463)). Pureblood inheritance is exceptional, not a universal starter perk ([Episode442](https://hennoveltranslations.com/archives/episodes/stgb-episode-442/)). |
| Dwarf | Numbered-item blessing has a documented1.5× effect on Guardian’s Braces duration ([Episode58](https://hennoveltranslations.com/archives/episodes/stgb-episode-58)). Do not multiply ordinary weapon damage or every item statistic. Obtainable numbered items are a prerequisite to integrating this mechanic. |
| Beastman | Soul-beast aptitude/selection is not universal. Contract manifestations and growth are supported; Beast Blood accelerates growth ([Episode150](https://hennoveltranslations.com/episodes/stgb-episode-150/)). Exact starter contracts, doses and fees still need evidence. |
| Barbarian | Soul Engraving involves a shaman/sanctuary and irreversible choices. The early first Undying quote is800,000 before a personal200,000 discount ([Chapters19–21](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-19-20-21/)); that discount is not universal. Aggregate physical enhancement must not be mislabeled as +20 Strength or health. |
| Draconian | Dragon Fear/Language are supported ([Episode159](https://hennoveltranslations.com/episodes/stgb-episode-159/)). Chieftain/shaman blessing arrangements require approval and specific circumstances ([Episode202](https://hennoveltranslations.com/episodes/stgb-episode-202/)); they are not free universal creation powers. Beginner potency/unlocks are unresolved. |

These are research boundaries, not implemented racial trees or six completed feature entries.

## Checkpoint0.5 additions

- Blade Wolf scent tracking is documented in [Chapters13–15](https://martialrealm.com/novel/sgb/chapter-13-14-15/) and the rank-nine wiki. Current implementation produces anonymous nearby scent contacts; exact tile localization and six-tile range are a game approximation. No active ability or full essence stat package has been invented.
- [Chapters25–27](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-25-26-27/) explicitly identify Stone Golem essence Suppression in a human user, immobilization of two victims and release after even a tiny injury. The same source places Gnomes/Stone Golems along Black Rock Mountain’s second-floor southern route. Generated geometry,48HP combat coefficients, area radius/cost/rounds and rank-eight drop probability remain estimates. Rank-nine0.01% evidence is not presented as a recovered rank-eight probability.
- Purchased Undying I acquisition and irreversible path are supported by the cited Chapters19–21. Current800 price is an estimate for the compressed game economy, not the800,000 source quote. +1 extra HP per90-minute fed noncombat interval is an explicit HP-clock approximation; +20 aggregate physical is not applied as Strength or max health.
- One-/two-minute grid actions and baseline fed recovery are estimates. The sourced30-minute loose essence lifetime,8-hour rest and7-/10-day deadlines retain their real durations. Old quarter-hour saves migrate their absolute clocks by15 exactly once.
- The user explicitly requested larger dungeons and at least2–3 characters abreast. New96×64 layouts and3-/5-wide connections satisfy that game geometry requirement; they do not claim a source-exact cartographic survey.

## Checkpoint0.6 source mapping

- No.9425’s essence-skill sealing is corroborated by the [Numbered Items wiki](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Numbered_Items). [Novel60](https://noveldex.io/series/novel/surviving-the-game-as-a-barbarian/chapter/60) establishes the worn-ring destruction ritual, all-equipped-gear loss, Skadia Strengthening, initial unarmed-only cold and1.5million market quote. The15million demand in dialogue is repayment, not its ordinary market price.
- [Novel48](https://noveldex.io/series/novel/surviving-the-game-as-a-barbarian/chapter/48) places No.3112’s acquisition in the variant Bloody Citadel and cites an old≈50million exchange price. [Novel58](https://hennoveltranslations.com/archives/episodes/stgb-episode-58) establishes5% mitigation, damage-related active efficacy, displacement, status cleansing/immunity and Dwarf1.5× efficiency. Charge conversion/reset, numerical duration/cooldown and the fractional-HP representation are implementation estimates.
- [Novel587](https://hennoveltranslations.com/archives/episodes/stgb-episode-587) identifies No.9712 Club of the Snowfield and its additional frost damage. Added damage amount/ordinary item statistics/price are estimates.
- [Novel159](https://hennoveltranslations.com/episodes/stgb-episode-159/) identifies innate Draconian Fear; [Novel160](https://hennoveltranslations.com/episodes/stgb-episode-160/) shows voluntary suppression, reactivation and intensity. The current accuracy/range conversion is estimated; it grants no boss-grade death/stun effect.
- Human aptitude and paid instruction are supported by [Novel52](https://hennoveltranslations.com/episodes/stgb-episode-52/), multi-day assessment by [Novel292](https://hennoveltranslations.org/episodes/stgb-episode-292/), and later-life taught magic by [Novel663](https://hennoveltranslations.org/episodes/stgb-episode-663/). These support the implemented basic route; specific fee/time/frequency are estimates. They do not prove guaranteed Tower admission or every Human’s access to all professions.
- Fairy additional attributes via Spirit Stones and Natural Energy are documented above. [Novel121](https://hennoveltranslations.org/episodes/stgb-episode-121/) supports training-driven spirit awakening but does not establish the first-contract process. That prerequisite remains unresolved; no free initial spirit is invented.

## Shared stat reconstruction

Chapter18 ([early chapter mirror](https://martialrealm.com/novel/sgb/chapter-16-17-18/)) describes Physical/Mind/Special Ability and many substats, including Strength/carry, Flexibility/evasion and Vision/Smell. This is evidence for names/relationships, not exact conversion formulas. Chapter337 ([translation](https://hennoveltranslations.org/episodes/stgb-episode-337/)) supplies1% total Strength per Muscle Mass point. Chapter463 ([translation](https://hennoveltranslations.com/archives/episodes/stgb-463)) supplies aggregate weights including Dexterity0.5 and Magic Resistance3; these do not imply0.5% or3% mitigation. Goblin Archer's exact nine bonuses are imported from the existing verified source package. Unknown packages are not filled with invented attribute lists.

`game/stat_catalog.gd` and generated `STAT_REFERENCE.md` record102 registered project IDs, all with consumers or informational summaries. This is a selected project catalog, not an exhaustive list of novel substats. The generic modifier stacking order, raw resistance curve, caps and most derived coefficients are reconstruction decisions explicitly marked as estimates, not claims of a complete novel ruleset.

## November5 authorization and remaining catalog consumers

The user explicitly authorized logical provisional qualitative mechanics when no novel explanation is available. `StatMentalRules.provisional_notes()`, `StatPhysiology.support_metadata()` and registry `known_effect`/`provisional_effect` retain that distinction. Earlier research-only findings remain in `research/stat-*-research.md` as evidence of what was and was not found, not as current implementation status. All102 project rows now have consumers or informational summaries; the source describes thousands of substats, so this count is not exhaustive.

Perception/Cognition and Bone Strength/Bone Density remain independently defined provisional domains because translated names overlap. No verified essence package receives duplicated aliases. Mana Sensitivity spell amplification, Absorption healing uptake, generic jump, mist/breath exposure, Pain disruption, attachment distress and most aggregate weights are explicit reconstructions. Early documented stat names do not prove these invented conversions.

The first Fire Spirit acquisition lesson is also provisional, permitted to provide a working Natural Energy consumer. [Chapters10–12](https://martialrealm.com/novel/sgb/chapter-10-11-12/) establish an existing Fire Spirit's illumination and rest. [Chapter19](https://martialrealm.com/novel/sgb/chapter-19-20-21/) describes an additional-element Spirit Stone at≈150000 stones and10% success, not a sourced first-contract lesson. These are kept separate.

## Additional affinity contract (0.9)

[Chapter19](https://martialrealm.com/novel/sgb/chapter-19-20-21/) states that Spirit Stones attempt spirits of another attribute, cost≈150000 in the game and succeed10% of the time. It also describes Wind-assisted arrow trajectory and speed. The implementation preserves the10% outcome and consumption risk. Base price150 is compressed, secondary availability currently restricted to Wind, Accuracy+10 and energy cost1 per attempted shot are explicit estimates/scope limits. Neither the chapter nor this implementation establishes that Wind is the only possible additional affinity. First Fire acquisition remains the separately labelled provisional lesson.

## Homeland source boundaries (0.10)

See `research/homelands.md` for each location and ceremony citation. Barharium is a sourced Fairy place name; Humans use Rafdonia. The Dwarf Forge Quarter is explicitly provisional, since workshop activity near Gnome Tree does not establish a named exclusive sanctuary. Layouts, unnamed operators and open visitor access are authored.

[Chapter202](https://hennoveltranslations.com/archives/episodes/stgb-episode-202) specifies Earth additional essence attributes+20%, Volcano skill performance about+30%, and Sea Soul Power+100. Native level2/500-stone access and one permanent slot are provisional; this does not reproduce the exceptional foreigner quest. Signed flat essence scaling, minimum1/round-up durations, tracking radius and spell damage are the currently supported conversions, not an assertion that every future skill/racial/artifact effect is implemented. [Chapter454](https://hennoveltranslations.org/episodes/stgb-episode-454/) supports the Barbarian coming-of-age weapon choice; exchanging the current starter club before the first expedition is an explicit opening implementation.


## Floors1–3 expansion (0.12)

See research/early-floor-audit.md, research/early-floor-monsters.md, research/third-floor-audit.md and research/third-floor-monsters.md for chapter/claim evidence. Thirdfloor is Pilgrim'sPath and contains more than ten fields; the four enabled third-floor habitats are a subset. Exact portal placement, compressed inter-biome paths, generated layouts, sprite silhouettes, spawn quantities, monsterHP/damage/armor, supplies, prices and skill AP/SP/range/cooldown conversions are reconstruction estimates.

Verified qualitative rules implemented:7/10/15day closure; Den→Ironrock and Dead→Estuary; Orc coordinated species/Frenzy triple resistance; IronTusk Counterweight; physical-resistant ghosts and elemental counters; Frogman mucus versus blunt/cold; Witch field status nullification/three debuffs; worsening stationary Eye pursuit endpoints; max5cabin occupancy and8h appearance lifetime; estuary midnight–06water/redmound camps. The fixed cabin relocation cadence, stat penalty magnitudes and discrete84h step are explicit approximations. No claim of full Eye scaling formula, complete cabin ritual/Riakis, allbiome geography, full essence packages or deeper-floor completion is made.
