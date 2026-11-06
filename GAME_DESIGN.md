# Dungeon & Stone — current rules

The original novel is the authority; the fan wiki supports research. Implemented rules and unresolved details are distinguished in `REFERENCE_RULES.md`. All six races receive equal development priority. The objective is a complete campaign, but the current playable scope is nine supported areas across floors1–3.

## Expedition loop

Create a character, prepare in Rafdonia, assemble up to five members including the player, enter Crystal Cave, explore/fight, collect mana stones and rare physical essence drops, travel through discovered portals, and survive until the floor closes. Return banks recovered items and charges current living costs; prepare for the next monthly opening. First-floor closure is seven days; supported second-floor areas close after ten. Return routes to a closed floor are blocked.

The city map opens Inn, Market, Recruitment, Blacksmith, Apothecary, Guild records, Storage and Dimensional Square. Operators route actual transactions. Companion figures are omitted from the city illustration; recruitment uses its menu. Twelve generated adventurers offer two options per race; their personal names and appearances are campaign-seeded and saved. Joining fees cover provisional expedition supplies. Prices, recruitment timing and the city drawing are provisional; service representatives are unnamed, with cosmetic visual identities.

## Character and combat

Barbarian, Beastman, Draconian, Dwarf, Fairy and Human have distinct provisional attribute profiles and modular appearance. Strength affects attack and carry capacity; Agility affects accuracy, evasion and action points; Wit affects sight and resources; Vigor affects health/rest. Equipment changes power, range, armor, evasion, accuracy and weight. Requirements and carry limits are enforced. Shield currently occupies the primary weapon slot; dual wielding is unfinished.

Party phases allow movement for 1 AP, one normal attack for 1 AP and techniques for 2 AP plus their resource. Agile units may receive 3 AP. Walls block sight/projectiles; leaving adjacent melee threat can provoke one reaction per foe per round. Enemies act on observed targets and last sightings. Companion behavior is manual, aggressive or guard. Round resolution is guarded against re-entry.

Physical damage subtracts armor, then applies resistance. Other damage applies resistance directly. Damage has a minimum of one; resistance is clamped from −50% to 80%. Accuracy minus evasion is clamped from 20% to 98%. These arithmetic coefficients are unverified. Logs explain actual damage, armor, resistance and hit chance.

Statuses refresh to the greater duration, never add stacks. Processing order is explicit in simulation code. Poison, bleeding and burning tick damage; paralysis/stun prevent actions; weakened/frightened/marked/chilled have defined combat effects. Only source-supported effects are naturally applied by current content. Trigger depth is capped at four.

The recruitable human mage’s rank-eight Ice Spear targets one visible enemy with clear line of effect. It uses a separate mana pool. Exact spell potency/range/cost/cooldown and recovery use provisional implementation values. Aggressive AI casts when possible, moves into casting range and guards while waiting; it does not pretend to cast an unavailable spell.

## Knowledge and essence progression

Ordinary species grant XP only on first defeat. XP is cumulative. The early table is interpreted as 6 total XP for level 2, 30 for level 3 and 150 for level 4; this interpretation is documented and qualified. No later threshold is invented. Level increases essence capacity; the supported first increase adds ten Soul Power. It does not arbitrarily increase physical attributes.

Goblin essence adds melee-weapon paralysis and Create Trap. Goblin Archer adds bow-conditioned poison and Thief Step. Gnome adds stationary concealment covering nearby allies; moving the source cancels the field. Costs, cooldowns, range and durations are unverified. Ordinary rank-nine drops use the novel's 0.01% baseline example; special variants require separate rules. Absorption requires a free slot, actual contact range, a living recipient and explicit confirmation. Duplicates are rejected without consuming the drop.

Loose drops carry area, position and absolute expiry. Their approximate thirty-minute lifetime persists across saves and travel. Expedition time is measured in minutes. Movement/normal attacks cost one estimated minute and techniques/round resolution two; these grid conversions are not recovered novel formulas. A nearby living mage can seal a loose drop outside combat using a purchased single-use test tube. Sealing takes fifteen estimated minutes and must finish by essence expiry and before portal closure. Filled tubes survive extraction and can be stored or sold; opening requires explicit absorption confirmation, a free slot and no duplicate, and destroys the tube. Wizards cannot absorb essences. Source-correct removal/replacement remains unfinished.

## Consequences and limits

Hero death ends the run; companion death is permanent. Leaving a living companion in the city preserves equipment, essences, health, injuries and resources for later rejoining; it does not provide healing or essence removal. Food is consumed at every crossed day boundary; shortages damage the party and increase fatigue. Rest is blocked during combat. Healing potions are blocked during combat without consuming them. Inventory, storage and currency transactions validate before mutation. Relief work is a provisional recovery service, not a sourced quest.

Full racial trees, faithful monthly taxes, rifts, deeper floors, deeper party progression and relationships, authored source quests and endings remain unimplemented. Do not count research rows as playable content.

The economy still uses a compressed temporary scale. Test tubes currently cost 1,000 base stones and filled low-rank tubes sell for 100, making preservation a build investment. These are balancing estimates, not recovered novel prices; a coordinated source-scale income/price update is outstanding.

## Expanded exploration and partial racial progression

New expeditions use96×64 seeded maps with variable packed chambers and looped connections. Corridors are at least3tiles wide, forest paths5. Safe portal spaces support party arrivals; a3×3 footprint is checked across generated routes. The map supports integer zoom, fit and dragging. Legacy active expeditions retain their original geography until the next entry.

Black Rock Mountain is a supported south-route second-floor area, with Gnomes and rank-eight Stone Golems. Stone Golem Suppression telegraphs an area, immobilizes opposing units and breaks individually on any positive damage. Moving out of the prior telegraph is counterplay; a free adjacent ally can spend its attack and1AP to make an exactly1HP release cut. Lethal cuts are refused. Tile range, radius, duration and costs remain estimates.

Blade Wolf essence currently implements the documented scent-tracking component only. Anonymous traces can appear beyond visual sight but reveal no creature identity, health or unexplored terrain, and do not authorize attacks through walls. Its unknown full kit is not filled with invented abilities.

Fed living characters gain baseline natural recovery outside combat; coefficients are provisional. A Barbarian can purchase Undying I through the sanctuary screen in Character Status. The path choice is permanent, improves that recovery and changes no Strength/health/resource maximum. The source quote is800,000; the current compressed economy uses an estimated800. Other stages and the other racial trees remain unfinished.

End-phase Guard is shared by keyboard, mouse and controller. It spends the selected acting character’s remaining AP; incapacity prevents guarding. Noncombat techniques use time/resources without subtracting combat AP. Mage-only unused SP/level readouts and nonfunctional loyalty readouts are omitted. Enemy Gnome concealment cancels when it moves, matching the stationary requirement.

## Racial entry mechanics in0.6

Skadia’s initial Strengthening contract requires a Beastman wearing No.9425. Confirming the ritual destroys all worn equipment; items manually removed to the pack survive. The contract is permanent. Unarmed strikes have cold attribute; weapon attacks do not gain cold at this stage. Strengthening coefficients and tactical conversion are estimated.

No.3112 prevents5% of post-defense damage with fractional carry. Its active expends accumulated prevented damage for an estimated protection duration, cleanses harmful statuses, grants temporary status immunity and repels enemies. Dwarf duration is1.5×. The effect does not negate damage. No.9712 adds cold damage to a landed ordinary attack. Source identities/effects are verified; unspecified coefficients remain marked estimates.

Draconian intimidation can be suppressed/released and applies an estimated nearby accuracy penalty, without automatic turn loss. Human aptitude is fixed by stable campaign identity; assessment cannot be paid repeatedly to reroll. Suitable essence-free Humans can pay for private Ice Spear lessons, becoming mages with mana and essence restrictions. Fees, aptitude frequency and study durations are estimates. These are bounded completed entry mechanics, not complete racial trees, universal talent, or Magic Tower membership.

## Shared numeric rules

Equipment, essence attributes, racial bonuses and statuses contribute to the same stat calculation. Flat bonuses apply first, then summed percentage increases, then independent multipliers; minimum bounds, rounding and caps follow. Primary attributes feed derived baselines before secondary modifiers. The STATS panel explains actual sources and equipment tooltips preview changes. Combining transformed flat attack with weakened now uses this stated flat-then-multiply order.

Muscle Mass raises total Strength1% per point, as described in chapter337. Goblin Archer's nine documented bonuses are used. Most baseline/derived coefficients, tactical ranges and the raw-resistance conversion remain estimates. Raw resistance points are not direct percentages. The master list distinguishes functional stats from researched names without implemented mechanics. Special abilities still have explicit stateful rules rather than being represented as inert numeric bonuses.

## Provisional completion of the current catalog

All102 current project entries have simulation consumers or informational summaries. This is a selected catalog and includes reconstruction attributes/output stats; it is not all of the novel's thousands of substats. On the user's instruction, unexplained qualitative behavior uses explicit logical provisional rules. The generated master reference names each conversion and its limits.

Endurance/bones/body size affect health, armor, Weight and reach; mental substats shape precision, timing, recklessness, fixation, composure and recovery. Generic jumping, breath-holding in optional mist, fractional Appetite food demand and a separate spirit resource make their supporting stats usable. Pain changes disruption, never the HP loss itself. Attachment briefly affects recovery after gear changes. Informational indices help inspect a build without granting a second combat bonus.

The Fairy's first Fire Spirit lesson is provisional acquisition,120stones/3days; capacity20, +3 nearby visibility,1energy per30minutes and a safe2-hour rest are numerical conversions. First-contract canon remains unresolved. Additional-element Spirit Stones and higher spirit training are the next source-based extensions.

## Homeland visits

Each new character begins in a compact home map. LANDS and the Rafdonia gate allow visiting the six implemented areas; unrestricted visitor access/travel time are provisional abstractions. Select a living party member for a racial rite. Approach an NPC/landmark with WASD/arrows/D-pad or click-to-walk; E/Space/A interacts. Paid and permanent changes need confirmation. Observation reveals journal lore once and yields no XP/gold. The six city maps do not replace dungeon progression.

Young Barbarian heroes may exchange their starter club for one of six existing weapons once before entering the dungeon. Dragon Shamans offer three permanent build choices using chapter202 effects, with provisional level2/500-stone native access and one slot. Earth scales essence attribute packages; Sea adds100 Soul Power; Volcano scales supported skill durations/tracking/spell damage by1.3. Whole-tile/round rounding and affected performance dimensions are explicit estimates. Foreign-rite quests, full racial trees and exact sanctuary entry restrictions remain unfinished.


## Early floors1–3 (0.12)

Crystal four compass steles connect to their own second-floor habitats. The center memorial remains separate. Den→Ironrock and Dead→Estuary are sourced third-floor arrivals; compact Hill→Orc→Witch and Estuary→Witch paths represent longer documented journeys. Geometry, travel compression and tactical values are estimates. Forest→Greentail and Rock→Twilight are documented but not playable destinations yet. Third floor closes day15, without resetting time or reopening lower floors.

Water joins food as a shared supply: daily demand uses living nonsummons, shortages wound/fatigue, recovery requires both. Day2 corpse flowers replenish once; torches change actual dark-zone sight until their absolute expiry. Pit exposure/disarming is persistent. DeathFiend summoning has atomic ten-cell preflight, owner cap, no rewards/shared-resource credit and absolute/round lifetime.

Witch field removes all non-field statuses from both sides and applies shared estimated perception/cognition/pain penalties. Stationary exposure attracts Carnivaro; documented endpoints are1hour initially/10minutes at84hours. A purple tree grants separate cabin safety until appearance expiry, max5occupants; leaving removes protection, camp duration/recovery caps to time remaining. Fixed8hour relocation is a reconstruction, not a verified respawn law. No corpse offering/Riakis implementation. At estuary highwater, all living explorers must gather on dry red mounds to camp; water remains shallow/wadeable.

Wraith ignores physical strikes but elemental secondary effects still resolve. Mobile Frogman evades ordinary blunt strikes without consuming hit RNG; cold or restraint disables that defense. OrcFrenzy triples raw resistance; IronTusk anchors temporarily. Full species kits and essence attribute packages remain incomplete. The35species give55first-speciesXP; farming repeats yields noXP.
