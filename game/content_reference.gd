class_name ReferenceContent
extends RefCounted
## Reference research catalog. Novel translation evidence is attached per verified claim.
## Many rows remain partial/secondary and all numeric resolver estimates stay separate.
## Zero numeric ability fields mean unverified, never a free source ability.

static func essences() -> Dictionary:
	return {
	  "canon_goblin": {
	    "name": "Goblin Essence",
	    "rank": 9,
	    "tier": 9,
	    "affinity": "",
	    "desc": "Melee weapons acquire a paralytic toxin. This is conditional on weapon use, not flat damage or generic lifesteal.",
	    "passive": "goblin_poison",
	    "passive_name": "Goblin Poison",
	    "value": 0,
	    "drawback": "",
	    "ability": {
	      "name": "Create Trap",
	      "effect": "create_trap",
	      "power": 0,
	      "cost": 0,
	      "cooldown": 0,
	      "range": 0,
	      "radius": 0,
	      "status": "",
	      "status_duration": 0,
	      "damage_type": "",
	      "description": "Places a trap; exact construction limits, duration, toxin severity, and costs remain unverified.",
	      "numeric_parameters_verified": false
	    },
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Essence",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9"
	    ],
	    "novel_chapters": [
	      19
	    ],
	    "source_stats": {
	      "patience": "low",
	      "smell": "low",
	      "poison_resistance": "low",
	      "dexterity": "low",
	      "sight": "low"
	    },
	    "verification_level": "secondary_summary_only",
	    "playable": false,
	    "requires_implementation": true,
	    "fidelity_note": "Original novel remains authoritative. The listed references summarize it; this entry has not been independently checked against the licensed chapter. Zero numerical fields mean unspecified, not a verified zero-cost ability. Enable only after the required resolver mechanics are implemented and tested.",
	    "required_effects": [
	      "weapon_conditioned_paralytic_poison",
	      "player_traps"
	    ],
	    "direct_novel_rule_verification": false
	  },
	  "canon_goblin_archer": {
	    "name": "Goblin Archer Essence",
	    "rank": 9,
	    "tier": 9,
	    "affinity": "",
	    "desc": "Bow hits add poison damage. The source does not support applying it to every attack or to melee weapons.",
	    "passive": "poison_arrow",
	    "passive_name": "Poison Arrow",
	    "value": 0,
	    "drawback": "",
	    "ability": {
	      "name": "Thief Step",
	      "effect": "stealth",
	      "power": 0,
	      "cost": 0,
	      "cooldown": 0,
	      "range": 0,
	      "radius": 0,
	      "status": "",
	      "status_duration": 0,
	      "damage_type": "",
	      "description": "Conceals the user; concealment works better while stationary or moving slowly.",
	      "numeric_parameters_verified": false,
	      "source_name_variants": [
	        "Sneak",
	        "Thief Step"
	      ]
	    },
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Jencia_Nephrin",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Erwen_Fornacci_di_Tersia",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Essence",
	      "https://martialrealm.com/novel/sgb/chapter-13-14-15/"
	    ],
	    "novel_chapters": [
	      13,
	      14
	    ],
	    "source_stats": {
	      "agility": 2,
	      "flexibility": 4,
	      "vision": 6,
	      "smell": 2,
	      "perception": 2,
	      "cognitive_interference": 6,
	      "accuracy": 8,
	      "poison_resistance": 4,
	      "obsession": 7
	    },
	    "verification_level": "primary_translation_passive_active_and_stats",
	    "playable": false,
	    "requires_implementation": true,
	    "fidelity_note": "Chapter14 directly lists the bow-conditioned poison passive, stealth active and source stat modifiers. This translation calls the active Sneak; other summaries use Thief Step. Grid timing, SP cost and poison severity remain estimates.",
	    "required_effects": [
	      "bow_conditioned_poison_damage",
	      "graded_stealth",
	      "movement_breaks_concealment"
	    ],
	    "direct_novel_rule_verification": true,
	    "primary_text_evidence": [
	      {
	        "url": "https://martialrealm.com/novel/sgb/chapter-13-14-15/",
	        "chapter": 14,
	        "claims": [
	          "Poison Arrow requires bow-type weapons.",
	          "Stealth is stronger when standing still or moving slowly.",
	          "The listed source stat modifiers are explicitly shown in the narrator game comparison."
	        ],
	        "access_method": "public_novel_translation_read",
	        "read_on": "2026-11-03"
	      }
	    ]
	  },
	  "canon_corpse_golem": {
	    "name": "Corpse Golem Essence",
	    "rank": 7,
	    "tier": 7,
	    "affinity": "",
	    "desc": "Blood becomes corrosive. Blood exposure can badly damage equipment, making this a build interaction and drawback rather than free thorns.",
	    "passive": "acid_fluid",
	    "passive_name": "Acid Fluid",
	    "value": 0,
	    "drawback": "",
	    "ability": {
	      "name": "Flesh Burst",
	      "effect": "flesh_burst",
	      "power": 0,
	      "cost": 0,
	      "cooldown": 0,
	      "range": 0,
	      "radius": 0,
	      "status": "",
	      "status_duration": 0,
	      "damage_type": "",
	      "description": "A body-part blast spends health. Exact blast damage, health expenditure, and recovery rules remain unverified.",
	      "numeric_parameters_verified": false
	    },
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_7",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bjorn_Yandel/Essences",
	      "https://hennoveltranslations.com/episodes/stgb-episode-221/"
	    ],
	    "novel_chapters": [
	      31
	    ],
	    "source_stats": {
	      "pain_resistance": 70,
	      "bone_strength": 55,
	      "poison_resistance": 12,
	      "strength": 15,
	      "perception": -5,
	      "appetite": 9,
	      "weight": 21
	    },
	    "verification_level": "mixed_primary_names_and_passive_active_split_secondary_costs_and_stats",
	    "playable": false,
	    "requires_implementation": true,
	    "fidelity_note": "Episode221 was read directly and confirms the passive/active distinction. The detailed HP cost, corrosion, exact stat modifiers and original chapter31 remain supported only by prior summaries; chapters21–44 were not accessible at this site. Numerical resolver parameters remain unspecified.",
	    "required_effects": [
	      "blood_exposure",
	      "acidic_blood_equipment_corrosion",
	      "health_cost_ability",
	      "body_part_explosion"
	    ],
	    "primary_text_evidence": [
	      {
	        "url": "https://hennoveltranslations.com/episodes/stgb-episode-221/",
	        "chapter": 221,
	        "claims": [
	          "Acidic Fluid is retained while active skills are suppressed.",
	          "Flesh Explosion is an active skill and is suppressed by Abyssal Fog."
	        ],
	        "access_method": "novel_translation_page_read",
	        "read_on": "2026-11-02"
	      }
	    ]
	  },
	  "canon_vampire_guardian": {
	    "name": "Vampire (Guardian) Essence",
	    "rank": 5,
	    "tier": 5,
	    "affinity": "",
	    "desc": "Survival is tied to the heart remaining intact. This is not verified as a simple on-hit lifesteal passive.",
	    "passive": "source_of_darkness",
	    "passive_name": "Source of Darkness",
	    "value": 0,
	    "drawback": "",
	    "ability": {
	      "name": "Eternal Life",
	      "effect": "missing_health_regeneration",
	      "power": 0,
	      "cost": 0,
	      "cooldown": 0,
	      "range": 0,
	      "radius": 0,
	      "status": "",
	      "status_duration": 0,
	      "damage_type": "",
	      "description": "A temporary regeneration effect becomes stronger as health falls.",
	      "numeric_parameters_verified": false
	    },
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bjorn_Yandel/Essences"
	    ],
	    "novel_chapters": [
	      44
	    ],
	    "source_stats": {
	      "natural_regeneration": 45,
	      "strength": 15,
	      "agility": 15,
	      "mana_resistance": 30,
	      "physical_resistance": 12,
	      "soul_power": 21,
	      "mana_sensitivity": 30,
	      "dark_resistance": 12,
	      "solar_resistance": -12
	    },
	    "verification_level": "secondary_summary_only",
	    "playable": false,
	    "requires_implementation": true,
	    "fidelity_note": "Vampire-specific skills and source_stats remain secondary-summary research; requested chapter44 was not accessible. Generic duplicate/absorption rules were independently checked in later novel text, but that does not verify this Vampire kit. Never replace this entry with unsupported generic lifesteal and label it faithful.",
	    "required_effects": [
	      "heart_dependent_survival",
	      "blood_stain_tracking",
	      "missing_health_regeneration",
	      "temporary_skill_theft"
	    ],
	    "guardian": true,
	    "abilities": [
	      {
	        "name": "Offering Imprint",
	        "effect": "blood_stain_boost",
	        "power": 0,
	        "cost": 0,
	        "cooldown": 0,
	        "range": 0,
	        "radius": 0,
	        "status": "",
	        "status_duration": 0,
	        "damage_type": "",
	        "description": "Physical capabilities rise temporarily with the count of creatures bearing the user blood.",
	        "numeric_parameters_verified": false
	      },
	      {
	        "name": "Eternal Life",
	        "effect": "missing_health_regeneration",
	        "power": 0,
	        "cost": 0,
	        "cooldown": 0,
	        "range": 0,
	        "radius": 0,
	        "status": "",
	        "status_duration": 0,
	        "damage_type": "",
	        "description": "Regeneration grows as the user health declines.",
	        "numeric_parameters_verified": false
	      },
	      {
	        "name": "Master of Blood",
	        "effect": "bloodsuck_copy_skill",
	        "power": 0,
	        "cost": 0,
	        "cooldown": 0,
	        "range": 0,
	        "radius": 0,
	        "status": "",
	        "status_duration": 0,
	        "damage_type": "",
	        "description": "Direct blood drinking can temporarily copy a target ability.",
	        "numeric_parameters_verified": false
	      }
	    ],
	    "direct_novel_rule_verification": false
	  },
	  "canon_orc_hero_tarugas": {
	    "name": "Orc Hero (Tarugas, Green) Essence",
	    "rank": 5,
	    "tier": 5,
	    "affinity": "",
	    "desc": "Resistance and recovery become stronger below half health and improve again below one fifth health.",
	    "passive": "path_of_heroes",
	    "passive_name": "Path of Heroes",
	    "value": 0,
	    "drawback": "",
	    "ability": {
	      "name": "Giantization",
	      "effect": "giantization",
	      "power": 0,
	      "cost": 0,
	      "cooldown": 0,
	      "range": 0,
	      "radius": 0,
	      "status": "",
	      "status_duration": 0,
	      "damage_type": "",
	      "description": "Growing changes physical capabilities and threat, influencing enemy attention. Exact scaling is not confirmed.",
	      "numeric_parameters_verified": false
	    },
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bjorn_Yandel/Essences",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_5",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth/Third_Floor",
	      "https://hennoveltranslations.com/episodes/stgb-episode-221/"
	    ],
	    "novel_chapters": [
	      68,
	      69
	    ],
	    "source_stats": {
	      "strength": 70,
	      "agility": 35,
	      "fighting_spirit": 40,
	      "physical_resistance": 20,
	      "bone_strength": 30
	    },
	    "verification_level": "mixed_primary_twenty_percent_threshold_secondary_other_details",
	    "playable": false,
	    "requires_implementation": true,
	    "fidelity_note": "Episode221 directly confirms the20% maximum threshold and active-skill suppression. The50% threshold, Tarugas color variant and precise source_stats still rely on summaries pending their original episodes. No physical-scaling coefficient has been independently verified.",
	    "required_effects": [
	      "health_threshold_resistance",
	      "health_threshold_resilience",
	      "size_scaling",
	      "threat_aggro"
	    ],
	    "essence_color": "green",
	    "verified_thresholds": [
	      0.5,
	      0.2
	    ],
	    "species_warning": "Ordinary Orc Warrior is not the verified source of Giantization. The green essence is associated with Tarugas, one Orc Hero variant.",
	    "primary_text_evidence": [
	      {
	        "url": "https://hennoveltranslations.com/episodes/stgb-episode-221/",
	        "chapter": 221,
	        "claims": [
	          "Below20% health, Hero's Path has its maximum resistance/endurance increase.",
	          "Giantization is an active skill suppressed by Abyssal Fog."
	        ],
	        "access_method": "novel_translation_page_read",
	        "read_on": "2026-11-02"
	      }
	    ]
	  },
	  "canon_stone_golem": {
	    "name": "Stone Golem Essence",
	    "rank": 8,
	    "tier": 8,
	    "affinity": "control",
	    "desc": "Suppression prevents movement and actions until damage breaks it. Only this verified active component is reconstructed.",
	    "passive": "",
	    "passive_name": "",
	    "value": 0,
	    "drawback": "",
	    "ability": {
	      "name": "Suppression",
	      "effect": "suppression",
	      "power": 0,
	      "cost": 0,
	      "cooldown": 0,
	      "range": 0,
	      "radius": 0,
	      "status": "suppressed",
	      "status_duration": 0,
	      "damage_type": "",
	      "description": "Prevents actions. Any positive damage immediately releases the affected target.",
	      "numeric_parameters_verified": false,
	      "breaks_on_damage": true,
	      "targeting": "hostile_area"
	    },
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_8",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth/Second_Floor",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Essence",
	      "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-25-26-27/"
	    ],
	    "novel_chapters": [
	      25
	    ],
	    "source_stats": {},
	    "verification_level": "primary_translation_human_essence_use_and_damage_break",
	    "playable": false,
	    "requires_implementation": true,
	    "fidelity_note": "Chapter25 depicts human essence users suppressing two explorers; even a minor wound releases each target. No golem passive or stat bonus is supplied. Tile dimensions, SP cost and turn timings are provisional.",
	    "required_effects": [
	      "suppressed_action_lock",
	      "suppression_breaks_on_any_positive_damage"
	    ],
	    "essence_transfer_verified": true,
	    "direct_novel_rule_verification": true,
	    "full_kit_verified": false,
	    "verified_components": [
	      "active_suppression",
	      "damage_break"
	    ],
	    "unverified_components": [
	      "passive_ability",
	      "stat_modifiers",
	      "range",
	      "radius",
	      "cost",
	      "cooldown",
	      "duration"
	    ],
	    "primary_text_evidence": [
	      {
	        "url": "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-25-26-27/",
	        "chapter": 25,
	        "claims": [
	          "A human essence user immobilizes two explorers with Stone Golem Suppression.",
	          "Positive damage releases an affected target."
	        ],
	        "access_method": "public_novel_translation_read",
	        "read_on": "2026-11-03"
	      }
	    ]
	  },
	  "canon_manticore": {
	    "name": "Manticore Essence",
	    "rank": 5,
	    "tier": 5,
	    "affinity": "",
	    "desc": "Consuming mana stones builds permanent statistics up to a total gain limit of 200.",
	    "passive": "inheritance",
	    "passive_name": "Inheritance / Heredity",
	    "value": 0,
	    "drawback": "",
	    "ability": {
	      "name": "Leap",
	      "effect": "leap_shockwave",
	      "power": 0,
	      "cost": 0,
	      "cooldown": 0,
	      "range": 0,
	      "radius": 0,
	      "status": "",
	      "status_duration": 0,
	      "damage_type": "",
	      "description": "Temporarily multiplies jumping power by ten for one leap, followed by a landing shockwave. At more than 500 kg, an added terrain effect is reported.",
	      "numeric_parameters_verified": false
	    },
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bjorn_Yandel/Essences",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_5"
	    ],
	    "novel_chapters": [
	      182,
	      183
	    ],
	    "source_stats": {
	      "discernment": 40,
	      "appetite": 30,
	      "jumping_power": 30
	    },
	    "verification_level": "secondary_summary_only",
	    "playable": false,
	    "requires_implementation": true,
	    "fidelity_note": "Original novel remains authoritative. The listed references summarize it; this entry has not been independently checked against the licensed chapter. Zero numerical fields mean unspecified, not a verified zero-cost ability. Enable only after the required resolver mechanics are implemented and tested.",
	    "required_effects": [
	      "mana_stone_stat_consumption",
	      "permanent_stat_cap",
	      "jump_arc",
	      "landing_shockwave",
	      "weight_conditioned_recoil",
	      "threat_aggro"
	    ],
	    "verified_stat_gain_cap": 200,
	    "verified_jump_multiplier": 10,
	    "verified_weight_threshold_kg": 500,
	    "excludes_monster_unique_ability": "The monster random-skill behavior is not supplied by its essence.",
	    "direct_novel_rule_verification": false
	  },
	  "canon_gnome": {
	    "name": "Gnome Essence",
	    "rank": 9,
	    "tier": 9,
	    "affinity": "",
	    "desc": "A stationary concealment field is documented. No passive or complete numerical essence modifiers were verified.",
	    "passive": "unknown",
	    "passive_name": "Unverified",
	    "value": 0,
	    "drawback": "",
	    "ability": {
	      "name": "Fairy Tale",
	      "effect": "stationary_concealment_field",
	      "power": 0,
	      "cost": 0,
	      "cooldown": 0,
	      "range": 0,
	      "radius": 0,
	      "status": "",
	      "status_duration": 0,
	      "damage_type": "",
	      "description": "Conceals nearby creatures while the caster remains on the ground and stationary. Source radius is three meters; its conversion to grid tiles remains estimated.",
	      "numeric_parameters_verified": false
	    },
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Essence",
	      "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-25-26-27/"
	    ],
	    "novel_chapters": [
	      25,
	      27
	    ],
	    "source_stats": {},
	    "verification_level": "primary_translation_transferred_stationary_area_concealment",
	    "playable": false,
	    "requires_implementation": true,
	    "fidelity_note": "Chapter25 directly depicts a human essence user concealing nearby creatures within three meters while stationary and grounded. The passive, stat modifiers, duration and grid conversion remain unverified.",
	    "required_effects": [
	      "stationary_area_concealment"
	    ],
	    "essence_transfer_verified": true,
	    "direct_novel_rule_verification": true,
	    "verified_radius_meters": 3,
	    "primary_text_evidence": [
	      {
	        "url": "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-25-26-27/",
	        "chapter": 25,
	        "claims": [
	          "A human uses Gnome essence for stationary, grounded area concealment within three meters."
	        ],
	        "access_method": "public_novel_translation_read",
	        "read_on": "2026-11-03"
	      }
	    ]
	  },
	  "canon_blade_wolf": {
	    "name": "Blade Wolf Essence",
	    "rank": 9,
	    "tier": 9,
	    "affinity": "scent",
	    "desc": "Track nearby scents independently of visual sight. This does not reveal unseen terrain or enable attacks through walls.",
	    "passive": "scent_tracking",
	    "passive_name": "Scent tracking",
	    "passive_name_is_descriptive": true,
	    "value": 0,
	    "drawback": "",
	    "ability": {
	      "name": "",
	      "effect": "",
	      "power": 0,
	      "cost": 0,
	      "cooldown": 0,
	      "range": 0,
	      "radius": 0,
	      "status": "",
	      "status_duration": 0,
	      "damage_type": "",
	      "description": "No active ability has been verified for this reconstruction.",
	      "numeric_parameters_verified": false
	    },
	    "reference_urls": [
	      "https://martialrealm.com/novel/sgb/chapter-13-14-15/",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Essence"
	    ],
	    "novel_chapters": [
	      10,
	      13
	    ],
	    "source_stats": {},
	    "verification_level": "primary_translation_scent_tracking_secondary_corroboration",
	    "playable": false,
	    "requires_implementation": true,
	    "direct_novel_rule_verification": true,
	    "full_kit_verified": false,
	    "essence_transfer_verified": true,
	    "required_effects": [
	      "scent_contacts_separate_from_visual_visibility"
	    ],
	    "verified_components": [
	      "scent_tracking"
	    ],
	    "unverified_components": [
	      "skill_name",
	      "active_ability",
	      "stat_modifiers",
	      "tracking_range",
	      "tracking_duration"
	    ],
	    "fidelity_note": "Chapter13 attributes scent tracking to Blade Wolf essence. The complete kit and whether the source classifies this effect as passive or active remain unverified; this reconstruction supplies only the documented tracking component. Grid range is provisional.",
	    "primary_text_evidence": [
	      {
	        "url": "https://martialrealm.com/novel/sgb/chapter-13-14-15/",
	        "chapter": 13,
	        "claims": [
	          "Narrator attributes a human pursuer tracking by smell to Blade Wolf essence."
	        ],
	        "access_method": "public_novel_translation_read",
	        "read_on": "2026-11-03"
	      }
	    ]
	  }
	}

static func monsters() -> Dictionary:
	return {
	  "canon_goblin": {
	    "name": "Goblin",
	    "role": "skirmisher",
	    "hp": 12,
	    "power": 4,
	    "armor": 0,
	    "evasion": 4,
	    "accuracy": 80,
	    "range": 1,
	    "move": 1,
	    "xp": 1,
	    "gold": 0,
	    "essence": "canon_goblin",
	    "affinity": "physical",
	    "status": "",
	    "desc": "Goblin uses poisoned melee weapons and traps.",
	    "telegraph": "",
	    "phase_power": 0,
	    "rank": 9,
	    "documented_locations": [
	      "Crystal Cave",
	      "Goblin Forest"
	    ],
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9",
	      "https://hennoveltranslations.com/episodes/stgb-episode-4/"
	    ],
	    "verification_level": "mixed_primary_species_behavior_xp_secondary_numeric_combat_parameters",
	    "experimental_numeric_fields": [
	      "hp",
	      "power",
	      "armor",
	      "evasion",
	      "accuracy",
	      "range",
	      "move"
	    ],
	    "fidelity_note": "Species, rank and listed locations come from summaries. HP, damage, defense, movement and turn-based timing are provisional implementation parameters, not verified original-novel formulas.",
	    "primary_text_evidence": [
	      {
	        "url": "https://hennoveltranslations.com/episodes/stgb-episode-4/",
	        "chapter": 4,
	        "claims": [
	          "First goblin kill grants1XP.",
	          "The corpse disappears and leaves a rank9 mana stone.",
	          "Goblins use traps and numbing poison and can wait out bleeding prey."
	        ],
	        "access_method": "novel_translation_page_read",
	        "read_on": "2026-11-02"
	      }
	    ]
	  },
	  "canon_ghoul": {
	    "name": "Ghoul",
	    "role": "ambusher",
	    "hp": 20,
	    "power": 6,
	    "armor": 0,
	    "evasion": 4,
	    "accuracy": 80,
	    "range": 1,
	    "move": 1,
	    "xp": 1,
	    "gold": 0,
	    "essence": "",
	    "affinity": "physical",
	    "status": "",
	    "desc": "A close-range creature stronger and faster than a goblin.",
	    "telegraph": "",
	    "phase_power": 0,
	    "rank": 9,
	    "documented_locations": [
	      "Crystal Cave",
	      "Land of the Dead",
	      "Bloody Citadel"
	    ],
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9"
	    ],
	    "verification_level": "secondary_summary_only",
	    "experimental_numeric_fields": [
	      "hp",
	      "power",
	      "armor",
	      "evasion",
	      "accuracy",
	      "range",
	      "move"
	    ],
	    "fidelity_note": "Species, rank and listed locations come from summaries. HP, damage, defense, movement and turn-based timing are provisional implementation parameters, not verified original-novel formulas.",
	    "essence_research_status": {
	      "kit_verified": false,
	      "reviewed_sources": [
	        "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9",
	        "https://martialrealm.com/novel/sgb/chapter-13-14-15/",
	        "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-25-26-27/"
	      ],
	      "note": "Reviewed descriptions establish the creature, not an essence passive or active. No transferable kit is invented."
	    }
	  },
	  "canon_gnome": {
	    "name": "Gnome",
	    "role": "controller",
	    "hp": 15,
	    "power": 4,
	    "armor": 0,
	    "evasion": 4,
	    "accuracy": 80,
	    "range": 1,
	    "move": 1,
	    "xp": 1,
	    "gold": 0,
	    "essence": "canon_gnome",
	    "affinity": "physical",
	    "status": "",
	    "desc": "A stationary concealment area is documented.",
	    "telegraph": "",
	    "phase_power": 0,
	    "rank": 9,
	    "documented_locations": [
	      "Crystal Cave",
	      "Black Rock Mountain"
	    ],
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9"
	    ],
	    "verification_level": "secondary_summary_only",
	    "experimental_numeric_fields": [
	      "hp",
	      "power",
	      "armor",
	      "evasion",
	      "accuracy",
	      "range",
	      "move"
	    ],
	    "fidelity_note": "Species, rank and listed locations come from summaries. HP, damage, defense, movement and turn-based timing are provisional implementation parameters, not verified original-novel formulas."
	  },
	  "canon_blade_wolf": {
	    "name": "Blade Wolf",
	    "role": "skirmisher",
	    "hp": 22,
	    "power": 7,
	    "armor": 0,
	    "evasion": 4,
	    "accuracy": 80,
	    "range": 1,
	    "move": 1,
	    "xp": 1,
	    "gold": 0,
	    "essence": "canon_blade_wolf",
	    "affinity": "physical",
	    "status": "",
	    "desc": "Species and locations verified; detailed attacks remain unverified.",
	    "telegraph": "",
	    "phase_power": 0,
	    "rank": 9,
	    "documented_locations": [
	      "Crystal Cave",
	      "Den of Beasts"
	    ],
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9",
	      "https://martialrealm.com/novel/sgb/chapter-13-14-15/"
	    ],
	    "verification_level": "secondary_summary_only",
	    "experimental_numeric_fields": [
	      "hp",
	      "power",
	      "armor",
	      "evasion",
	      "accuracy",
	      "range",
	      "move"
	    ],
	    "fidelity_note": "Species, rank and listed locations come from summaries. HP, damage, defense, movement and turn-based timing are provisional implementation parameters, not verified original-novel formulas.",
	    "scent_tracking_verified": true
	  },
	  "canon_goblin_archer": {
	    "name": "Goblin Archer",
	    "role": "ranged",
	    "hp": 14,
	    "power": 4,
	    "armor": 0,
	    "evasion": 4,
	    "accuracy": 80,
	    "range": 5,
	    "move": 1,
	    "xp": 1,
	    "gold": 0,
	    "essence": "canon_goblin_archer",
	    "affinity": "physical",
	    "status": "",
	    "desc": "Poisoned arrows and concealment are documented.",
	    "telegraph": "",
	    "phase_power": 0,
	    "rank": 9,
	    "documented_locations": [
	      "Goblin Forest"
	    ],
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9"
	    ],
	    "verification_level": "secondary_summary_only",
	    "experimental_numeric_fields": [
	      "hp",
	      "power",
	      "armor",
	      "evasion",
	      "accuracy",
	      "range",
	      "move"
	    ],
	    "fidelity_note": "Species, rank and listed locations come from summaries. HP, damage, defense, movement and turn-based timing are provisional implementation parameters, not verified original-novel formulas."
	  },
	  "canon_goblin_swordsman": {
	    "name": "Goblin Swordsman",
	    "role": "skirmisher",
	    "hp": 18,
	    "power": 6,
	    "armor": 1,
	    "evasion": 4,
	    "accuracy": 80,
	    "range": 1,
	    "move": 1,
	    "xp": 1,
	    "gold": 0,
	    "essence": "",
	    "affinity": "physical",
	    "status": "",
	    "desc": "A goblin variant carrying a longer curved blade.",
	    "telegraph": "",
	    "phase_power": 0,
	    "rank": 9,
	    "documented_locations": [
	      "Goblin Forest"
	    ],
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9"
	    ],
	    "verification_level": "secondary_summary_only",
	    "experimental_numeric_fields": [
	      "hp",
	      "power",
	      "armor",
	      "evasion",
	      "accuracy",
	      "range",
	      "move"
	    ],
	    "fidelity_note": "Species, rank and listed locations come from summaries. HP, damage, defense, movement and turn-based timing are provisional implementation parameters, not verified original-novel formulas.",
	    "essence_research_status": {
	      "kit_verified": false,
	      "reviewed_sources": [
	        "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9",
	        "https://martialrealm.com/novel/sgb/chapter-13-14-15/",
	        "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-25-26-27/"
	      ],
	      "note": "Reviewed descriptions establish the creature, not an essence passive or active. No transferable kit is invented."
	    }
	  },
	  "canon_skeleton": {
	    "name": "Skeleton",
	    "role": "tank",
	    "hp": 18,
	    "power": 5,
	    "armor": 2,
	    "evasion": 4,
	    "accuracy": 80,
	    "range": 1,
	    "move": 1,
	    "xp": 1,
	    "gold": 0,
	    "essence": "",
	    "affinity": "physical",
	    "status": "",
	    "desc": "Species and locations verified; detailed resistances remain unverified.",
	    "telegraph": "",
	    "phase_power": 0,
	    "rank": 9,
	    "documented_locations": [
	      "Land of the Dead",
	      "Bloody Citadel"
	    ],
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9"
	    ],
	    "verification_level": "secondary_summary_only",
	    "experimental_numeric_fields": [
	      "hp",
	      "power",
	      "armor",
	      "evasion",
	      "accuracy",
	      "range",
	      "move"
	    ],
	    "fidelity_note": "Species, rank and listed locations come from summaries. HP, damage, defense, movement and turn-based timing are provisional implementation parameters, not verified original-novel formulas.",
	    "essence_research_status": {
	      "kit_verified": false,
	      "reviewed_sources": [
	        "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9",
	        "https://martialrealm.com/novel/sgb/chapter-13-14-15/",
	        "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-25-26-27/"
	      ],
	      "note": "Reviewed descriptions establish the creature, not an essence passive or active. No transferable kit is invented."
	    }
	  },
	  "canon_slime": {
	    "name": "Slime",
	    "role": "tank",
	    "hp": 16,
	    "power": 3,
	    "armor": 1,
	    "evasion": 4,
	    "accuracy": 80,
	    "range": 1,
	    "move": 1,
	    "xp": 1,
	    "gold": 0,
	    "essence": "",
	    "affinity": "physical",
	    "status": "",
	    "desc": "A weak rift enemy, not a verified normal Crystal Cave spawn.",
	    "telegraph": "",
	    "phase_power": 0,
	    "rank": 9,
	    "documented_locations": [
	      "Green Iron Mine (rift)"
	    ],
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9"
	    ],
	    "verification_level": "secondary_summary_only",
	    "experimental_numeric_fields": [
	      "hp",
	      "power",
	      "armor",
	      "evasion",
	      "accuracy",
	      "range",
	      "move"
	    ],
	    "fidelity_note": "Species, rank and listed locations come from summaries. HP, damage, defense, movement and turn-based timing are provisional implementation parameters, not verified original-novel formulas."
	  },
	  "canon_stone_golem": {
	    "name": "Stone Golem",
	    "role": "controller",
	    "hp": 48,
	    "power": 9,
	    "armor": 6,
	    "evasion": 4,
	    "accuracy": 80,
	    "range": 1,
	    "move": 1,
	    "xp": 2,
	    "gold": 0,
	    "essence": "canon_stone_golem",
	    "affinity": "physical",
	    "status": "",
	    "desc": "A rank-eight construct whose Suppression prevents actions until the target is injured.",
	    "telegraph": "",
	    "phase_power": 0,
	    "rank": 8,
	    "documented_locations": [
	      "Black Rock Mountain"
	    ],
	    "reference_urls": [
	      "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-25-26-27/",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_8"
	    ],
	    "verification_level": "primary_translation_ability_transfer_and_location",
	    "experimental_numeric_fields": [
	      "hp",
	      "power",
	      "armor",
	      "evasion",
	      "accuracy",
	      "range",
	      "move"
	    ],
	    "fidelity_note": "Species, rank and listed locations come from summaries. HP, damage, defense, movement and turn-based timing are provisional implementation parameters, not verified original-novel formulas.",
	    "suppression": {
	      "range": 4,
	      "radius": 1,
	      "duration": 2,
	      "cooldown": 4,
	      "status": "suppressed",
	      "breaks_on_damage": true,
	      "experimental_numeric_fields": [
	        "range",
	        "radius",
	        "duration",
	        "cooldown"
	      ]
	    }
	  }
	}

static func regions() -> Dictionary:
	return {
	  "canon_crystal_cave": {
	    "name": "Crystal Cave",
	    "subtitle": "First Floor",
	    "floor": 1,
	    "level": 1,
	    "color": "6b8f9d",
	    "wall": "253d47",
	    "terrain": "cave",
	    "hazard_desc": "Crystal-lit tunnels, dark outskirts, and goblin traps. Layout scale and turn timing remain provisional.",
	    "enemy_ids": [
	      "canon_goblin",
	      "canon_ghoul",
	      "canon_gnome",
	      "canon_blade_wolf"
	    ],
	    "documented_monsters": [
	      "Goblin",
	      "Ghoul",
	      "Gnome",
	      "Blade Wolf"
	    ],
	    "resource": "",
	    "lore": "The central memorial and dark outskirts are documented landmarks. This generated map is not a reconstruction of exact novel geography.",
	    "exit_regions": [
	      "canon_goblin_forest",
	      "canon_land_of_dead",
	      "canon_black_rock_mountain"
	    ],
	    "unimplemented_exits": [
	      "Den of Beasts"
	    ],
	    "portal_closes_after_days": 7,
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth/First_Floor",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Bestiary/Rank_9",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth",
	      "https://hennoveltranslations.com/episodes/stgb-episode-4/",
	      "https://hennoveltranslations.com/episodes/stgb-episode-5/"
	    ],
	    "verified_novel_directly": false,
	    "primary_text_evidence": [
	      {
	        "url": "https://hennoveltranslations.com/episodes/stgb-episode-4/",
	        "chapter": 4,
	        "claims": [
	          "Ordinary first-floor routes are illuminated by crystals; dark zones are mainly on the outskirts toward second-floor portals.",
	          "Entry position is randomized; the narrator abnormal dark spawn differs from the game convenience."
	        ],
	        "access_method": "novel_translation_page_read",
	        "read_on": "2026-11-02"
	      },
	      {
	        "url": "https://hennoveltranslations.com/episodes/stgb-episode-5/",
	        "chapter": 5,
	        "claims": [
	          "A monument can open a second-floor portal."
	        ],
	        "access_method": "novel_translation_page_read",
	        "read_on": "2026-11-02"
	      }
	    ]
	  },
	  "canon_goblin_forest": {
	    "name": "Goblin Forest",
	    "subtitle": "Second Floor",
	    "floor": 2,
	    "level": 2,
	    "color": "416047",
	    "wall": "1e3226",
	    "terrain": "forest",
	    "hazard_desc": "A dim forest with frequent traps and goblin groups. Encounter group size and layout are provisional.",
	    "enemy_ids": [
	      "canon_goblin",
	      "canon_goblin_swordsman",
	      "canon_goblin_archer"
	    ],
	    "documented_monsters": [
	      "Goblin",
	      "Goblin Swordsman",
	      "Goblin Archer"
	    ],
	    "resource": "",
	    "lore": "A high cavern ceiling lights the forest. No new canonical boss or main quest is invented here.",
	    "portal_closes_after_days": 10,
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth/Second_Floor",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth"
	    ],
	    "verified_novel_directly": false
	  },
	  "canon_land_of_dead": {
	    "name": "Land of the Dead",
	    "subtitle": "Second Floor",
	    "floor": 2,
	    "level": 2,
	    "color": "6d6575",
	    "wall": "302a37",
	    "terrain": "graveyard",
	    "hazard_desc": "Ruined stone structures and undead enemies. Water-bearing corpse flowers are documented but not implemented.",
	    "enemy_ids": [
	      "canon_ghoul",
	      "canon_skeleton"
	    ],
	    "documented_monsters": [
	      "Ghoul",
	      "Elder Ghoul",
	      "Skeleton",
	      "Skeleton Warrior",
	      "Skeleton Archer",
	      "Banshee",
	      "Death Fiend",
	      "Dullahan"
	    ],
	    "unimplemented_monsters": [
	      "Elder Ghoul",
	      "Skeleton Warrior",
	      "Skeleton Archer",
	      "Banshee",
	      "Death Fiend",
	      "Dullahan"
	    ],
	    "resource": "",
	    "lore": "Only the researched undead subset is active. A mandatory seal boss is not a verified rule.",
	    "portal_closes_after_days": 10,
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth/Second_Floor",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth"
	    ],
	    "verified_novel_directly": false
	  },
	  "canon_green_iron_mine": {
	    "name": "Green Iron Mine",
	    "subtitle": "First Floor Rift — Not Implemented",
	    "floor": 1,
	    "level": 1,
	    "color": "5a7665",
	    "wall": "293a32",
	    "terrain": "mine",
	    "hazard_desc": "Rift access and its guardian are not implemented.",
	    "enemy_ids": [
	      "canon_slime"
	    ],
	    "documented_monsters": [
	      "Goblin Miner",
	      "Slime",
	      "King Slime"
	    ],
	    "unimplemented_monsters": [
	      "Goblin Miner",
	      "King Slime"
	    ],
	    "resource": "",
	    "lore": "This is a first-floor rift, not a normal cave biome.",
	    "playable": false,
	    "reference_urls": [
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth/First_Floor"
	    ],
	    "verified_novel_directly": false
	  },
	  "canon_black_rock_mountain": {
	    "name": "Black Rock Mountain",
	    "subtitle": "Second Floor · Southern Route",
	    "floor": 2,
	    "level": 2,
	    "color": "636a73",
	    "wall": "252a34",
	    "terrain": "rock",
	    "hazard_desc": "Stone Golem Suppression stops actions; positive damage releases an affected explorer. Exact geography is provisional.",
	    "enemy_ids": [
	      "canon_gnome",
	      "canon_stone_golem"
	    ],
	    "documented_monsters": [
	      "Gnome",
	      "Kobold Shield Soldier",
	      "Sandman",
	      "Stone Golem",
	      "Sandworm",
	      "Death Worm"
	    ],
	    "unimplemented_monsters": [
	      "Kobold Shield Soldier",
	      "Sandman",
	      "Sandworm",
	      "Death Worm"
	    ],
	    "resource": "",
	    "lore": "The southern second-floor route is recorded as a hunting ground for gnomes, kobolds and Stone Golems.",
	    "portal_closes_after_days": 10,
	    "entry_from": "canon_crystal_cave",
	    "entry_direction": "south",
	    "playable": false,
	    "reference_urls": [
	      "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-25-26-27/",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth/Second_Floor",
	      "https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth"
	    ],
	    "identity_verified_novel_directly": true,
	    "verified_novel_directly": false,
	    "experimental_numeric_fields": [
	      "layout",
	      "encounter_count",
	      "portal_position"
	    ],
	    "primary_text_evidence": [
	      {
	        "url": "https://koreanplayer.com/novel/surviving-the-game-as-a-barbarian-novel/chapter-25-26-27/",
	        "chapter": 27,
	        "claims": [
	          "The southern second-floor route is Black Rock Mountain and contains gnomes, kobolds and Stone Golems."
	        ],
	        "access_method": "public_novel_translation_read",
	        "read_on": "2026-11-03"
	      }
	    ]
	  }
	}

static func researched_rules() -> Dictionary:
	return {
	  "starting_level": {
	    "value": 1,
	    "status": "direct_observation_after_first_goblin",
	    "source_url": "https://hennoveltranslations.com/episodes/stgb-episode-5/",
	    "chapter": 5,
	    "note": "The first displayed panel is Level1 after only the first goblin kill in Episode4. This is not proof of the untouched new-character total before any kill. It contradicts assuming level0 without checking the missing early chapters."
	  },
	  "goblin_first_kill_xp": {
	    "value": 1,
	    "status": "direct_novel_translation",
	    "source_url": "https://hennoveltranslations.com/episodes/stgb-episode-4/",
	    "chapter": 4
	  },
	  "first_species_kill_xp_only": {
	    "value": true,
	    "status": "indexed_novel_excerpt",
	    "source_url": "https://hennoveltranslations.com/episodes/stgb-episode-456/",
	    "chapter": 456,
	    "note": "Novel farming explanation explicitly limits XP to the first hunt; Repeated ordinary hunts do not award species XP."
	  },
	  "essence_lifetime_seconds": {
	    "value": 1800,
	    "status": "indexed_novel_excerpt",
	    "source_urls": [
	      "https://hennoveltranslations.com/episodes/stgb-episode-374/",
	      "https://hennoveltranslations.com/archives/episodes/stgb-episode-518"
	    ],
	    "chapters": [
	      374,
	      518
	    ],
	    "precision": "approximately",
	    "note": "Texts describe about30minutes after drop. Test-tube preservation is a separate mechanic, not a normal inventory item."
	  },
	  "rank9_drop_rate_example": {
	    "value": 0.0001,
	    "status": "narrator_example_not_universal_table",
	    "source_url": "https://hennoveltranslations.com/archives/episodes/stgb-episode-457/",
	    "chapter": 457,
	    "note": "Narrator compares0.01% normal odds with5.01% after an approximately5percentage-point first-kill talisman. Do not promote this example into a verified rate for every species."
	  },
	  "guardian_drop_rate_example": {
	    "value": 0.333,
	    "status": "narrator_example_king_slime",
	    "source_url": "https://hennoveltranslations.com/archives/episodes/stgb-episode-375",
	    "chapter": 375,
	    "note": "A KingSlime kill leaves no essence, numbered item, or riftstone; narration cites33.3% individual odds. Guardian essence is not guaranteed."
	  },
	  "essence_removal_price_quote": {
	    "value": 100000,
	    "currency": "stones",
	    "status": "direct_contextual_novel_quote_paraphrase",
	    "source_url": "https://hennoveltranslations.com/episodes/stgb-episode-221/",
	    "chapter": 221,
	    "note": "A temple removal is priced at100000stones in this context. A universal rank-independent tariff or additional restrictions are not established by this passage."
	  },
	  "field_absorption_by_contact": {
	    "value": true,
	    "status": "direct_attempt_and_context",
	    "source_urls": [
	      "https://hennoveltranslations.com/archives/episodes/stgb-episode-622/",
	      "https://hennoveltranslations.com/archives/episodes/stgb-episode-620"
	    ],
	    "chapters": [
	      622,
	      620
	    ],
	    "note": "The novel shows approaching and touching an essence in the dungeon and consuming test essences there. The Episode622 attempt fails because it is a duplicate; city-only absorption is not a source rule."
	  },
	  "duplicate_essence_consumption": {
	    "value": false,
	    "status": "direct_novel_translation",
	    "source_url": "https://hennoveltranslations.com/archives/episodes/stgb-episode-622/",
	    "chapter": 622,
	    "note": "An available slot does not permit the duplicate. A normal essence can upgrade into its Guardian counterpart; it does not occupy a second duplicate slot. Exact same-skill/different-source edge cases still require careful chapter context."
	  },
	  "normal_to_guardian_upgrade": {
	    "value": true,
	    "status": "direct_novel_translation",
	    "source_url": "https://hennoveltranslations.com/archives/episodes/stgb-episode-622/",
	    "chapter": 622
	  },
	  "essence_capacity_gain_per_level": {
	    "value": 1,
	    "status": "indexed_novel_level6_observation",
	    "source_url": "https://hennoveltranslations.com/archives/episodes/stgb-episode-264",
	    "chapter": 264,
	    "note": "The narrator has five full slots before reaching level6; level-up gives one additional slot and30SoulPower. A complete level/XP table is not established by this paragraph."
	  },
	  "level2_xp_threshold": {
	    "status": "unverified_requested_early_chapters_unavailable",
	    "note": "Do not infer cumulative or per-level thresholds from a secondary paraphrase. Parent research may supply Episode50; exact wording must be reconciled with Episode5 Level1 observation."
	  },
	  "same_affinity_tier_incompatibility": {
	    "status": "not_verified",
	    "note": "No same-affinity or same-tier incompatibility rule is established by the source passages inspected."
	  },
	  "corrupted_essence_removal_exception": {
	    "status": "indexed_novel_exception",
	    "source_url": "https://hennoveltranslations.com/archives/episodes/surviving-the-game-as-a-barbarian-episode-804/",
	    "chapter": 804,
	    "note": "Omen of Corruption can make an essence permanently unremovable even at a temple. This exception is not yet implemented."
	  }
	}
