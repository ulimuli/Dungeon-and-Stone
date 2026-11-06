class_name AdventurerNames
extends RefCounted
## Original generated personal names. This vocabulary asserts no canonical
## racial language, family history, faction affiliation or novel identity.
const GIVEN: Array[String] = ["Tarin","Nessa","Corin","Vela","Dena","Kelan","Suri","Tovan","Neri","Rovan","Eska","Tessa","Ilan","Kora","Fen","Darin","Lena","Varen","Kiri","Torin","Risa","Soren","Yara","Elen","Kaven","Nola","Renn","Miren","Cera","Joren","Vessa","Doren"]
const FAMILY: Array[String] = ["Ashford","Rook","Vale","Hale","Briar","Keel","Pike","Wren","Fallow","Dale","Moss","Alder","Reeve","Holt","Voss","Fenn","Gale","Brook","Heath","Flint","March","Reed","Rowan","Lark","Harrow","Wells","Lowe","Mere","Gray","Kestrel","Ward","Tern"]

static func stable_seed(text: String) -> int:
	var result: int = 2166136261
	for byte: int in text.to_utf8_buffer(): result = ((result ^ byte) * 16777619) & 0x7fffffff
	return result

static func generate(campaign_seed: int, identity_key: String, used: Dictionary = {}) -> String:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = stable_seed("adventurer-name-v1|%d|%s" % [campaign_seed,identity_key])
	var offset: int = random.randi_range(0,GIVEN.size()*FAMILY.size()-1)
	# A complete deterministic permutation guarantees a distinct available name.
	for step: int in range(GIVEN.size()*FAMILY.size()):
		var index: int = (offset + step * 37) % (GIVEN.size()*FAMILY.size())
		var candidate: String = GIVEN[index % GIVEN.size()] + " " + FAMILY[index / GIVEN.size()]
		if not used.has(candidate): return candidate
	return "Unnamed Adventurer"
