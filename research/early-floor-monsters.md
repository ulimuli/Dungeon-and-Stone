# Early-floor monster implementation audit

Read2026-11-05. The original novel takes priority; public translations vary in spelling. This batch adds13 source-backed identities and13 original32px code-drawn sprites. Ordinary AI uses existing melee, ranged, ambusher, skirmisher and guarding roles with explicitly provisional coefficients. These baseline profiles do **not** establish recovered complete skill kits. Unknown essence packages remain absent.

## Primary evidence

- [Novel23–24](https://martialrealm.com/novel/sgb/chapter-22-23-24/): Elder Ghoul, Skeleton Warrior and Skeleton Archer each award1XP; the elder is larger, archers use bows, and skeletons have an exposed rib core relevant to blades. Death Fiends are heavily defended, regenerate rapidly, summon ten Ghouls, move slowly and stop pursuit outside their territory. A fallen fiend cannot rise unaided. The text explicitly discusses both transferable essence skills, with weaker regeneration than the monster and synergy with Undying.
- [Novel50](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-49-50-51/): the canyon has cave-dwelling beasts and hidden pits. Its ordinary species include Giant Blade Wolf, Wall Mole, Half-Moon Rock Bear, Wall Mole Queen and Bloodstained Blade Wolf (1XP each); Saber Tiger and Werewolf award2XP. Black-cliff depths contain rank-eight creatures rather than rank-nine ones. Species-specific Werewolf regeneration or tiger techniques are not established here.
- [Novel27](https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-25-26-27/): southern Black Rock Mountain is a hunting route for gnomes, kobolds and Stone Golems. The detailed Shield Soldier identity/rank uses the secondary compilation below rather than claiming chapter27 specifies its full kit.

## Secondary corroboration and gaps

The [rank-nine](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9), [rank-eight](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_8) and [second-floor](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth/Second_Floor) compilations identify Kobold Shield Soldier(rank9,1XP), Sandman(rank8,2XP), and the relevant habitats. Their detailed combat kits are not specified. Wiki pages can reject direct access; indexed article contents were reviewed. This evidence is weaker than a directly read novel account and is marked accordingly.

Vulkars/Bulkar is named in the Den account but its exact rank, XP and mechanics remain unresolved; it is **not** fabricated as a completed entry. Name aliases map to single stable species IDs, never duplicate XP entries. Further source-backed enemies, Banshee curse/immunity behavior, Dullahan, other biome variants and rifts remain separate work.

## Runtime contract

`EarlyFloorContent.monsters()` provides13 compatible rows; `region_pools()` includes established existing IDs; `den_bands()` separates ordinary/deep candidates. `sprite(id,frame)->Texture2D` supplies cached32px transparent pixel art and `sprite_image` supports inspection. Art depicts readable provisional silhouettes rather than traced novel/manhwa illustrations. It uses no external assets.

`essences()` supplies one **partial** Death Fiend kit: unknown raw attributes remain `source_stats:{}` and `modifiers:[]`. Physical Preservation has a separate `passive_modifiers` entry for shared `natural_recovery ×2` (estimated). That skill modifier must be excluded while sealed; it is not an attribute retained by the Frost Ring or amplified by Earth's attribute bonus. Runtime combat regeneration must also respect sealing, death, summoning rules and the central healing calculation.

Call of the Dead's ten-Ghoul monster count is sourced. The player descriptor currently also calls10, for12SP, a6-round cooldown,12-round lifetime, range/radius4. Those player limits and grid conversions are estimates. Spawn preflight must prevent partial payment, excessive ownership, blocked-placement loss, recursive summons, free XP/materials and indefinite companions. Monster regeneration8/round, cooldown6, radius3 and territorial radius10 are explicitly estimated. The owning simulation must implement and test these hooks before advertising the complete behavior.

## Verification boundary

`early_floor_content_test.gd` verifies313 definition/art assertions: provenance, real pools/bands, no speculative essence assignment, shared passive modifier validity, stable aliases, unshared mutable results and distinct original sprites. This is **not** evidence of actual AI, drop, absorption, summon, save or GUI integration; those must be exercised by the root integration tests.
