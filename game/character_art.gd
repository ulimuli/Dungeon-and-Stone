class_name CharacterArt
extends RefCounted
## Native-pixel modular portraits and directional paper dolls. Cosmetics use their
## own RNG and never read or advance the simulation random stream. Save only the
## normalized appearance dictionary. All artwork is original procedural artwork.

const VERSION: int = 1
const CHOICES: Dictionary = {
	"skin": ["pale", "fair", "bronze", "umber", "ebony", "ash", "olive", "copper"],
	"hair_style": ["crop", "swept", "braid", "long", "shaved", "mohawk", "knots"],
	"hair_color": ["black", "chestnut", "auburn", "gold", "silver", "white", "blueblack", "copper"],
	"eyes": ["brown", "hazel", "green", "blue", "gray", "amber"],
	"outfit": ["slate", "garnet", "moss", "navy", "ochre", "ivory", "plum", "teal"],
	"accent": ["slate", "garnet", "moss", "navy", "ochre", "ivory", "plum", "teal"],
	"face_detail": ["plain", "freckles", "scar", "paint", "beard", "moustache"],
	"body": ["balanced", "broad", "slender"],
	"presentation": ["masculine", "feminine", "androgynous"],
	"accessory": ["none", "earring", "hood", "headband", "circlet", "goggles", "apron", "scarf", "pauldron"]
}
const SKINS: Dictionary = {
	"human": ["edcbb1", "dab18e", "bd906e", "946a51", "62463a", "c0b4ab", "a5a17d", "c9906c"],
	"fairy": ["f2dec5", "e0c6a4", "c4aa87", "a48b6e", "77664e", "c7cdc6", "b0bb96", "d3a58a"],
	"dwarf": ["e8c4a2", "d9ac85", "b98b61", "96704e", "604535", "c1aca0", "aaa17b", "c68b61"],
	"beastfolk": ["dfd8c8", "c1b49e", "a68c71", "8a705d", "51463f", "a3acb5", "8d947b", "b98d6a"],
	"barbarian": ["e8c4a7", "d2a57e", "b9855e", "8c6048", "5d4236", "b9aaa0", "a29a76", "c58a64"],
	"draconian": ["bed2d3", "91bab6", "749b99", "547d81", "35565f", "9aa6b2", "8b9c77", "b18a69"]
}
const HAIRS: Dictionary = {"black":"292631", "chestnut":"654b3c", "auburn":"8c4c39", "gold":"c5a46d", "silver":"9ba7b0", "white":"d4d6c8", "blueblack":"303f58", "copper":"b77449"}
const CLOTHES: Dictionary = {"slate":"58667a", "garnet":"8e4549", "moss":"68794f", "navy":"354f75", "ochre":"aa864b", "ivory":"c2b8a0", "plum":"775878", "teal":"487d7c"}
const EYES: Dictionary = {"brown":"694831", "hazel":"8c8554", "green":"73996c", "blue":"79a5b9", "gray":"a1acb3", "amber":"d5b55f"}
static var _cache: Dictionary = {}

static func options() -> Dictionary:
	return CHOICES.duplicate(true)

static func _race(ancestry: String) -> String:
	var value: String = ancestry.to_lower()
	var aliases: Dictionary = {"beastman":"beastfolk", "beastmen":"beastfolk", "elf":"fairy", "dragonkin":"draconian", "dragonian":"draconian"}
	value = str(aliases.get(value, value))
	return value if SKINS.has(value) else "human"

static func _stable_hash(value: String) -> int:
	var result: int = 2166136261
	for byte: int in value.to_utf8_buffer():
		result = ((result ^ byte) * 16777619) & 0x7fffffff
	return result

static func seeded(ancestry: String, seed: int) -> Dictionary:
	var race: String = _race(ancestry)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (seed & 0x7fffffff) ^ _stable_hash(race)
	var result: Dictionary = {"version": VERSION}
	for field: String in CHOICES:
		var choices: Array = CHOICES[field]
		result[field] = str(choices[rng.randi_range(0, choices.size() - 1)])
	if race == "dwarf" and result.presentation != "feminine" and rng.randf() < 0.65:
		result.face_detail = "beard"
	return result

static func normalize(appearance: Dictionary, ancestry: String, seed: int = 0) -> Dictionary:
	var result: Dictionary = seeded(ancestry, seed)
	var aliases: Dictionary = {"hair":"hair_color", "feature":"accessory", "face":"face_detail", "gender":"presentation"}
	for raw_field: Variant in appearance:
		var field: String = str(aliases.get(str(raw_field), str(raw_field)))
		if not CHOICES.has(field): continue
		var value: Variant = appearance[raw_field]
		var choices: Array = CHOICES[field]
		if value is int or value is float:
			result[field] = str(choices[clampi(int(value), 0, choices.size() - 1)])
		elif value is String:
			var choice: String = str(value).to_lower()
			if field == "hair_style": choice = {"short":"crop", "bald":"shaved"}.get(choice, choice)
			if field == "presentation": choice = {"male":"masculine", "female":"feminine", "neutral":"androgynous"}.get(choice, choice)
			if choices.has(choice): result[field] = choice
			elif choice.begins_with("#") and Color.html_is_valid(choice): result[field] = _nearest_color(choice, field, _race(ancestry), result[field])
	result.version = VERSION
	return result

static func _nearest_color(value: String, field: String, race: String, fallback: String) -> String:
	if field not in ["skin", "hair_color", "eyes", "outfit", "accent"]: return fallback
	var wanted: Color = Color(value)
	var best: float = INF
	var result: String = fallback
	for choice: String in CHOICES[field]:
		var candidate: Color = _color(field, choice, race)
		var distance: float = Vector3(wanted.r - candidate.r, wanted.g - candidate.g, wanted.b - candidate.b).length_squared()
		if distance < best:
			best = distance
			result = choice
	return result

static func _color(field: String, choice: String, race: String) -> Color:
	if field == "skin": return Color(str(SKINS[race][maxi(0, CHOICES.skin.find(choice))]))
	if field == "hair_color": return Color(str(HAIRS.get(choice, "654b3c")))
	if field == "eyes": return Color(str(EYES.get(choice, "694831")))
	return Color(str(CLOTHES.get(choice, "58667a")))

static func _appearance(unit: Dictionary) -> Dictionary:
	var identity: String = str(unit.get("id", "")) + ":" + str(unit.get("name", ""))
	var raw: Variant = unit.get("appearance", {})
	return normalize(raw if raw is Dictionary else {}, str(unit.get("ancestry", "human")), _stable_hash(identity))

static func portrait(unit: Dictionary) -> Texture2D:
	var race: String = _race(str(unit.get("ancestry", "human")))
	var look: Dictionary = _appearance(unit)
	var key: String = "portrait:" + race + ":" + JSON.stringify(look)
	if not _cache.has(key):
		_remember(key, ImageTexture.create_from_image(_portrait_image(race, look)))
	return _cache[key] as Texture2D

static func sprite(unit: Dictionary, direction: int = 0, frame: int = 0) -> Texture2D:
	var race: String = _race(str(unit.get("ancestry", "human")))
	var look: Dictionary = _appearance(unit)
	var facing: int = posmod(direction, 4)
	var pose: int = posmod(frame, 4)
	var role: String = str(unit.get("role", "civilian"))
	var key: String = "sprite:" + race + ":" + JSON.stringify(look) + ":" + role + ":%d:%d" % [facing, pose]
	if not _cache.has(key):
		_remember(key, ImageTexture.create_from_image(_sprite_image(race, look, role, facing, pose)))
	return _cache[key] as Texture2D

static func _remember(key: String, texture: Texture2D) -> void:
	# Bounded cosmetic cache. A discarded ImageTexture is rebuilt deterministically.
	if _cache.size() >= 512: _cache.erase(_cache.keys()[0])
	_cache[key] = texture

static func _pixel(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height(): image.set_pixel(x, y, color)

static func _rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	for yy: int in range(maxi(0, y), mini(image.get_height(), y + height)):
		for xx: int in range(maxi(0, x), mini(image.get_width(), x + width)):
			image.set_pixel(xx, yy, color)

static func _line(image: Image, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	var dx: int = absi(x1 - x0)
	var dy: int = -absi(y1 - y0)
	var sx: int = 1 if x0 < x1 else -1
	var sy: int = 1 if y0 < y1 else -1
	var error: int = dx + dy
	while true:
		_pixel(image, x0, y0, color)
		if x0 == x1 and y0 == y1: break
		var twice: int = error * 2
		if twice >= dy:
			error += dy
			x0 += sx
		if twice <= dx:
			error += dx
			y0 += sy

static func _ellipse(image: Image, cx: int, cy: int, rx: int, ry: int, color: Color) -> void:
	for y: int in range(cy - ry, cy + ry + 1):
		for x: int in range(cx - rx, cx + rx + 1):
			if pow(float(x - cx) / maxf(0.5, float(rx)), 2) + pow(float(y - cy) / maxf(0.5, float(ry)), 2) <= 1.0:
				_pixel(image, x, y, color)

static func _poly(image: Image, vertices: Array, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2i in vertices: points.append(Vector2(point))
	var min_y: int = image.get_height()
	var max_y: int = -1
	var min_x: int = image.get_width()
	var max_x: int = -1
	for point: Vector2 in points:
		min_y = mini(min_y, int(point.y)); max_y = maxi(max_y, int(point.y))
		min_x = mini(min_x, int(point.x)); max_x = maxi(max_x, int(point.x))
	for y: int in range(maxi(0, min_y), mini(image.get_height(), max_y + 1)):
		for x: int in range(maxi(0, min_x), mini(image.get_width(), max_x + 1)):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points): image.set_pixel(x, y, color)

static func _polygon(image: Image, coords: Array, color: Color) -> void:
	var vertices: Array = []
	for n: int in range(0, coords.size(), 2): vertices.append(Vector2i(int(coords[n]), int(coords[n + 1])))
	_poly(image, vertices, color)

static func _portrait_image(race: String, look: Dictionary) -> Image:
	var image: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color("080e19"))
	# Controlled two-tone dither, quieter than the character.
	for y: int in range(2, 63):
		for x: int in range(2, 63):
			if pow(float(x - 31) / 28.0, 2) + pow(float(y - 31) / 37.0, 2) < 1:
				_pixel(image, x, y, Color("111e2c") if (x * 7 + y * 11) % 17 > 1 else Color("172637"))
	var outline: Color = Color("080a10")
	var skin: Color = _color("skin", look.skin, race)
	var shadow: Color = skin.darkened(0.29)
	var deep: Color = skin.darkened(0.48)
	var light: Color = skin.lightened(0.18)
	var hair: Color = _color("hair_color", look.hair_color, race)
	var hair_dark: Color = hair.darkened(0.35)
	var cloth: Color = _color("outfit", look.outfit, race)
	var accent: Color = _color("accent", look.accent, race)
	var iris: Color = _color("eyes", look.eyes, race)
	var broad: int = (3 if look.body == "broad" else (-2 if look.body == "slender" else 0)) + (3 if race == "barbarian" else (2 if race == "dwarf" else 0))
	var face_width: int = (11 if race in ["dwarf", "barbarian"] else 9) + (1 if look.presentation == "masculine" else 0)
	var fy: int = 2 if race == "dwarf" else 0
	# Draped shoulders, neck, collar, fasteners: fabric is built at native resolution.
	_polygon(image, [4-broad,63, 7-broad,54, 17,47, 25,44, 40,44, 49,48, 57+broad,55, 61+broad,63], outline)
	_polygon(image, [6-broad,63, 9-broad,55, 21,48, 43,48, 55+broad,55, 59+broad,63], cloth.darkened(0.25))
	_polygon(image, [9-broad,55, 20,49, 26,49, 22,57, 22,64, 6-broad,64], cloth)
	_polygon(image, [42,49, 51,54, 56+broad,62, 39,64, 39,55], cloth.darkened(0.07))
	_line(image, 10-broad,55, 20,51, cloth.lightened(0.26))
	_line(image, 11-broad,59, 20,54, cloth.lightened(0.12))
	_line(image, 46,54, 51+broad,59, cloth.darkened(0.40))
	_rect(image,25,39+fy,15,13,deep)
	_polygon(image,[26,39+fy, 39,39+fy, 38,48, 33,53, 26,48],shadow)
	_polygon(image,[26,40+fy, 32,44+fy, 32,49, 27,47],skin)
	_polygon(image,[22,47, 27,48, 33,54, 29,58, 20,51],accent)
	_polygon(image,[40,46, 45,49, 37,58, 33,54],accent.darkened(0.24))
	_line(image,22,48,29,55,accent.lightened(0.25))
	_line(image,33,55,33,63,Color("9e947a"))
	_rect(image,30,57,6,4,Color("3b3f48"));_rect(image,31,57,4,2,Color("b6b5a5"))
	# Long hair back layer shapes, preserved beneath the face.
	if look.hair_style in ["long", "braid", "knots"]:
		_polygon(image,[18,19+fy, 44,19+fy, 46,49, 41,54, 36,42, 23,42, 18,52, 15,48],hair_dark)
		_line(image,18,27,17,44,hair);_line(image,43,27,44,45,hair.lightened(0.10))
	if look.accessory == "hood":
		_polygon(image,[13,45, 14,20, 21,8, 32,4, 43,9, 50,25, 50,48, 43,52, 41,18, 22,17, 22,49],cloth.darkened(0.20))
		_line(image,15,22,21,11,cloth.lightened(0.30));_line(image,44,13,48,26,cloth)
	# Ears have independent silhouettes, drawn before their face overlays.
	if race == "fairy":
		_polygon(image,[22,24+fy, 7,15+fy, 13,30+fy, 23,34+fy],outline)
		_polygon(image,[21,25+fy, 9,18+fy, 15,29+fy, 23,32+fy],skin)
		_line(image,11,21+fy,19,28+fy,shadow)
		_polygon(image,[42,24+fy, 57,15+fy, 51,30+fy, 41,34+fy],outline)
		_polygon(image,[43,25+fy, 55,18+fy, 49,29+fy, 41,32+fy],shadow)
		_line(image,48,25+fy,53,20+fy,light)
	elif race != "beastfolk":
		_ellipse(image,21-face_width+9,29+fy,3,5,shadow)
		_ellipse(image,42+face_width-9,29+fy,3,5,deep)
		_line(image,20,27+fy,21,31+fy,light)
	# Sculpted six-plane face, narrow highlights rather than a rectangular mask.
	_polygon(image,[31-face_width,17+fy, 24,11+fy, 39,11+fy, 32+face_width,18+fy, 33+face_width,33+fy, 40,43+fy, 33,47+fy, 24,43+fy, 30-face_width,34+fy],outline)
	_polygon(image,[32-face_width,18+fy, 24,13+fy, 39,13+fy, 31+face_width,19+fy, 32+face_width,32+fy, 39,41+fy, 33,45+fy, 25,41+fy, 31-face_width,33+fy],skin)
	_polygon(image,[25,16+fy, 30,14+fy, 29,27+fy, 25,33+fy, 22,29+fy, 22,20+fy],light)
	_polygon(image,[38,16+fy, 31+face_width,21+fy, 32+face_width,33+fy, 38,41+fy, 34,43+fy, 36,33+fy],shadow)
	_polygon(image,[24,34+fy, 30,37+fy, 29,41+fy, 25,39+fy],shadow)
	_line(image,25,39+fy,30,42+fy,skin.lightened(0.08))
	# Brow, sockets, visible iris and highlight, with different jaw presentations.
	var brow_y: int = 25+fy if look.presentation == "feminine" else 24+fy
	_line(image,23,brow_y,28,brow_y-1,hair_dark);_line(image,35,brow_y-1,41,brow_y,hair_dark)
	_rect(image,23,27+fy,7,3,deep);_rect(image,35,27+fy,7,3,deep)
	_line(image,24,28+fy,29,28+fy,Color("e1ddc7"));_line(image,35,28+fy,40,28+fy,Color("d1d3c1"))
	_rect(image,27,27+fy,2,3,iris);_rect(image,36,27+fy,2,3,iris)
	_pixel(image,28,28+fy,outline);_pixel(image,36,28+fy,outline)
	_pixel(image,27,27+fy,Color("f1ead1"));_pixel(image,36,27+fy,Color("f1ead1"))
	if look.presentation == "feminine":
		_line(image,22,27+fy,24,26+fy,hair_dark);_line(image,40,26+fy,42,27+fy,hair_dark)
		_line(image,26,40+fy,31,43+fy,shadow)
	_line(image,32,28+fy,30,34+fy,shadow)
	_rect(image,31,33+fy,3,2,light);_pixel(image,34,34+fy,deep)
	_line(image,29,38+fy,36,38+fy,deep);_line(image,30,39+fy,35,39+fy,skin.darkened(0.12))
	_line(image,31,41+fy,35,41+fy,light)
	if race == "barbarian":
		_rect(image,22,24,8,2,shadow);_rect(image,35,24,8,2,deep)
		_line(image,24,33,27,34,deep);_line(image,38,33,41,31,deep)
	if race == "beastfolk": _beast_face(image,skin,shadow,light,hair)
	if race == "draconian": _dragon_face(image,skin,shadow,light,accent)
	_portrait_hair(image,look,hair,hair_dark,fy)
	if race == "beastfolk":
		_polygon(image,[19,23, 12,5, 24,13, 27,19],outline);_polygon(image,[20,20, 15,8, 23,15],skin)
		_polygon(image,[38,18, 50,5, 47,25, 42,24],outline);_polygon(image,[42,20, 48,9, 46,22],shadow)
		_line(image,17,11,20,17,light);_line(image,47,11,45,18,skin)
	if race == "draconian":
		_polygon(image,[21,20, 13,4, 18,7, 27,17],deep);_polygon(image,[39,17, 48,4, 47,13, 43,23],deep)
		_line(image,15,6,22,17,Color("d4cbb1"));_line(image,47,6,42,17,Color("a9aa9d"))
	_portrait_detail(image,look,race,fy,skin,shadow,hair,accent)
	_portrait_accessory(image,look,fy,cloth,accent)
	# Small controlled rim around garment preserves a crisp silhouette in black UI.
	_line(image,7-broad,61,9-broad,56,Color("7c8790"))
	return image

static func _beast_face(image: Image, skin: Color, shadow: Color, light: Color, hair: Color) -> void:
	_polygon(image,[22,31, 28,32, 32,35, 36,32, 43,31, 41,40, 34,45, 28,43, 22,38],skin)
	_polygon(image,[25,34, 31,35, 34,35, 39,34, 39,40, 33,43, 26,40],light)
	_polygon(image,[29,34, 36,34, 34,37, 31,37],hair.darkened(0.4))
	_line(image,33,37,33,40,shadow);_line(image,28,40,37,40,shadow)
	_line(image,21,34,17,32,shadow);_line(image,22,37,17,37,shadow)
	_line(image,42,34,46,32,shadow);_line(image,41,37,46,37,shadow)
	for point: Vector2i in [Vector2i(25,36),Vector2i(27,37),Vector2i(38,36),Vector2i(39,38)]: _pixel(image,point.x,point.y,shadow)

static func _dragon_face(image: Image, skin: Color, shadow: Color, light: Color, accent: Color) -> void:
	_polygon(image,[22,32, 28,34, 33,34, 40,31, 44,35, 39,43, 33,47, 25,42],shadow)
	_polygon(image,[26,34, 33,35, 39,33, 39,39, 33,42, 27,39],skin)
	_rect(image,29,36,2,1,shadow.darkened(0.5));_rect(image,36,35,2,1,shadow.darkened(0.5))
	_line(image,28,40,37,40,shadow.darkened(0.4));_pixel(image,30,40,light);_pixel(image,36,40,light)
	for point: Vector2i in [Vector2i(22,31),Vector2i(24,34),Vector2i(23,37),Vector2i(39,22),Vector2i(41,25),Vector2i(40,29),Vector2i(26,18)]:
		_line(image,point.x,point.y,point.x+2,point.y+1,light)
	_line(image,32,17,31,21,accent.lightened(0.25))

static func _portrait_hair(image: Image, look: Dictionary, hair: Color, dark: Color, fy: int) -> void:
	var style: String = look.hair_style
	if style == "shaved":
		_line(image,23,17+fy,28,14+fy,hair.darkened(0.15));_line(image,28,14+fy,37,14+fy,hair.darkened(0.15))
		for x: int in range(24,41,3): _pixel(image,x,16+fy,hair)
		return
	_polygon(image,[20,26+fy, 18,18+fy, 22,10+fy, 28,8+fy, 38,9+fy, 44,15+fy, 44,25+fy, 40,23+fy, 39,18+fy, 25,18+fy, 23,26+fy],dark)
	_polygon(image,[21,19+fy, 23,12+fy, 30,10+fy, 39,12+fy, 41,16+fy, 35,18+fy, 26,17+fy],hair)
	_line(image,25,13+fy,30,11+fy,hair.lightened(0.26));_line(image,31,12+fy,37,13+fy,hair.lightened(0.14))
	_line(image,22,21+fy,22,25+fy,hair);_line(image,42,19+fy,42,25+fy,hair)
	if style == "swept":
		_polygon(image,[22,18+fy, 26,10+fy, 41,12+fy, 40,17+fy, 32,18+fy, 27,23+fy, 26,17+fy],hair)
		_line(image,27,14+fy,36,12+fy,hair.lightened(0.23));_line(image,28,17+fy,37,14+fy,hair.lightened(0.11))
	elif style == "long":
		_polygon(image,[19,21, 23,24, 23,43, 20,51, 17,49, 18,34],hair)
		_polygon(image,[41,22, 44,21, 46,45, 42,52, 39,47, 41,35],dark)
		_line(image,20,27,19,45,hair.lightened(0.18));_line(image,43,28,44,44,hair)
	elif style == "braid":
		for y: int in range(24,54,4):
			_rect(image,18+int(y/4)%2,y,5,4,dark)
			_line(image,19,y,22,y+2,hair);_pixel(image,20,y,hair.lightened(0.2))
		_rect(image,18,50,5,2,Color("b59a63"))
	elif style == "mohawk":
		_rect(image,20,17+fy,5,7,Color("665a50"));_rect(image,40,18+fy,3,6,Color("665a50"))
		_polygon(image,[28,17+fy, 27,8+fy, 29,6+fy, 31,3+fy, 34,7+fy, 36,5+fy, 38,12+fy, 36,18+fy],hair)
		_line(image,30,9+fy,31,5+fy,hair.lightened(0.3))
	elif style == "knots":
		_ellipse(image,21,12+fy,5,5,dark);_ellipse(image,43,12+fy,5,5,dark)
		_ellipse(image,21,11+fy,3,3,hair);_ellipse(image,43,11+fy,3,3,hair)
		_pixel(image,20,9+fy,hair.lightened(0.25));_pixel(image,42,9+fy,hair.lightened(0.25))

static func _portrait_detail(image: Image, look: Dictionary, race: String, fy: int, skin: Color, shadow: Color, hair: Color, accent: Color) -> void:
	match str(look.face_detail):
		"freckles":
			for point: Vector2i in [Vector2i(24,32),Vector2i(27,33),Vector2i(25,35),Vector2i(37,32),Vector2i(40,33),Vector2i(39,35)]: _pixel(image,point.x,point.y+fy,shadow)
		"scar":
			_line(image,38,24+fy,35,36+fy,skin.lightened(0.35));_line(image,39,24+fy,36,36+fy,shadow)
			_line(image,36,29+fy,39,30+fy,shadow);_line(image,35,33+fy,38,34+fy,shadow)
		"paint":
			_polygon(image,[22,30+fy, 28,31+fy, 26,37+fy, 23,35+fy],accent)
			_polygon(image,[37,31+fy, 42,30+fy, 40,37+fy, 37,35+fy],accent.darkened(0.20))
		"beard":
			_polygon(image,[21,34+fy, 25,37+fy, 29,36+fy, 33,38+fy, 37,36+fy, 42,33+fy, 41,44+fy, 34,53+fy, 29,51+fy, 23,44+fy],hair.darkened(0.30))
			_line(image,25,40+fy,28,47+fy,hair.lightened(0.12));_line(image,32,41+fy,33,50+fy,hair)
			_line(image,38,39+fy,35,48+fy,hair.lightened(0.17));_line(image,29,39+fy,35,39+fy,shadow.darkened(0.3))
			if race == "dwarf":
				_rect(image,29,47+fy,8,3,Color("938b75"));_line(image,30,47+fy,35,47+fy,Color("c9c3ac"))
		"moustache":
			_polygon(image,[31,36+fy, 34,36+fy, 40,40+fy, 35,41+fy, 32,39+fy, 28,41+fy, 24,40+fy],hair.darkened(0.12))

static func _portrait_accessory(image: Image, look: Dictionary, fy: int, cloth: Color, accent: Color) -> void:
	var metal: Color = Color("b8b4a3")
	match str(look.accessory):
		"earring":
			_ellipse(image,20,33+fy,2,3,Color("d5b977"));_rect(image,20,32+fy,1,2,Color("303544"))
		"headband":
			_rect(image,21,19+fy,22,3,accent);_line(image,22,19+fy,42,19+fy,accent.lightened(0.35))
			_polygon(image,[41,21+fy, 46,23+fy, 48,34+fy, 44,31+fy],accent.darkened(0.25))
		"circlet":
			_line(image,21,20+fy,29,21+fy,metal);_line(image,35,21+fy,43,20+fy,metal)
			_polygon(image,[32,18+fy, 35,21+fy, 32,25+fy, 29,21+fy],accent.lightened(0.3));_pixel(image,32,20+fy,Color("f3ead0"))
		"goggles":
			_rect(image,20,20+fy,24,3,Color("665847"));_ellipse(image,27,21+fy,5,4,Color("a99d84"));_ellipse(image,38,21+fy,5,4,Color("a99d84"))
			_ellipse(image,27,21+fy,3,2,Color("2d4a5b"));_ellipse(image,38,21+fy,3,2,Color("2d4a5b"));_pixel(image,26,20+fy,Color("a7ced0"));_pixel(image,37,20+fy,Color("a7ced0"))
		"apron":
			_line(image,22,49,26,58,Color("a6a08a"));_line(image,43,49,40,58,Color("a6a08a"))
			_polygon(image,[25,54, 41,54, 43,64, 23,64],Color("75624b"));_line(image,26,55,39,55,Color("b09a77"));_rect(image,28,59,10,4,Color("594c3f"))
		"scarf":
			_polygon(image,[23,44+fy, 29,48+fy, 39,45+fy, 43,48, 39,53, 29,54, 22,49],accent)
			_polygon(image,[37,51, 42,51, 44,64, 37,62],accent.darkened(0.20));_line(image,25,47,30,50,accent.lightened(0.25))
		"pauldron":
			_polygon(image,[6,56, 12,49, 21,49, 25,53, 23,60, 12,62],Color("454e5d"));_line(image,11,52,20,51,metal)
			_line(image,8,55,22,55,Color("8e969a"));_pixel(image,11,58,metal);_pixel(image,20,58,metal)
	if look.accessory == "hood":
		_line(image,19,20,18,36,cloth.lightened(0.25));_line(image,45,24,46,38,cloth.darkened(0.3))

static func _sprite_image(race: String, look: Dictionary, role: String, direction: int, frame: int) -> Image:
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var skin: Color = _color("skin", look.skin, race)
	var shadow: Color = skin.darkened(0.34)
	var hair: Color = _color("hair_color", look.hair_color, race)
	var cloth: Color = _color("outfit", look.outfit, race)
	var accent: Color = _color("accent", look.accent, race)
	var ink: Color = Color("0b1019")
	var metal: Color = Color("b7c4cb")
	var broad: int = (1 if look.body == "broad" else (-1 if look.body == "slender" else 0)) + (1 if race in ["dwarf", "barbarian"] else 0)
	var bob: int = -1 if frame in [1, 3] else 0
	var leg: int = 1 if frame == 1 else (-1 if frame == 3 else 0)
	var head_y: int = 7 if race == "dwarf" else (4 if race == "barbarian" else 5)
	head_y += bob
	var back: bool = direction == 3
	var profile: bool = direction in [1, 2]
	var face_x: int = -1 if profile else 0
	# Ground contact, separated boots and alternating stride.
	_ellipse(image,16,30,9,1,Color(0,0,0,0.22))
	_rect(image,10,24+bob,5,5+leg,ink);_rect(image,18,24+bob,5,5-leg,ink)
	_rect(image,10,25,4,3+leg,cloth.darkened(0.35));_rect(image,19,25,3,3-leg,cloth.darkened(0.48))
	_rect(image,9,28+leg,6,2,Color("51483e"));_rect(image,18,28-leg,6,2,Color("443e3a"))
	_line(image,10,28+leg,13,28+leg,Color("8f8470"));_line(image,19,28-leg,22,28-leg,Color("736d62"))
	# Tail is behind the body and never obscures class/equipment hands.
	if race == "beastfolk":
		_line(image,22,24+bob,28,22+bob,ink);_line(image,28,22+bob,29,18+bob,ink)
		_line(image,22,23+bob,27,22+bob,shadow);_line(image,27,22+bob,28,19+bob,skin)
	if race == "draconian":
		_polygon(image,[21,22+bob, 29,25+bob, 28,19+bob, 31,25+bob, 27,28+bob, 21,26+bob],shadow)
		_line(image,24,24+bob,28,26+bob,skin)
	_polygon(image,[7-broad,18+bob, 10,15+bob, 21,15+bob, 25+broad,18+bob, 24+broad,25+bob, 8-broad,25+bob],ink)
	_rect(image,10,16+bob,13,9,cloth.darkened(0.28))
	_polygon(image,[10,17+bob, 15,16+bob, 15,24+bob, 9,24+bob],cloth)
	_line(image,11,18+bob,11,22+bob,cloth.lightened(0.30))
	_rect(image,9,24+bob,15,2,Color("66563f"));_rect(image,15,24+bob,3,2,metal.darkened(0.25))
	_rect(image,7-broad,18+bob,4,6,cloth);_rect(image,22,18+bob,4+broad,6,cloth.darkened(0.28))
	_rect(image,7-broad,23+bob,4,3,skin);_rect(image,23+broad,23+bob,3,3,shadow)
	if race == "barbarian":
		_rect(image,7-broad,17+bob,4,7,skin);_rect(image,23,17+bob,4+broad,7,shadow)
		_rect(image,11,17+bob,10,6,skin);_line(image,16,18+bob,16,22+bob,shadow)
		_line(image,11,20+bob,14,20+bob,shadow);_line(image,18,20+bob,21,20+bob,shadow)
	if look.accessory == "apron":
		_polygon(image,[12,18+bob, 21,18+bob, 23,27+bob, 11,27+bob],Color("8c7456"));_rect(image,14,22+bob,6,3,Color("5d4d3e"))
		_line(image,12,17+bob,14,20+bob,Color("c0ac86"))
	if look.accessory == "pauldron":
		_rect(image,6-broad,16+bob,7,5,Color("4c596a"));_line(image,7-broad,16+bob,11,16+bob,metal)
	# Neck and independently detailed head, not a reduced portrait.
	_rect(image,13,13+bob,7,5,shadow)
	_rect(image,10+face_x,head_y+1,13,12,ink)
	_polygon(image,[11+face_x,head_y+2, 20+face_x,head_y+1, 22+face_x,head_y+5, 21+face_x,head_y+11, 16+face_x,head_y+13, 11+face_x,head_y+10],skin)
	_rect(image,20+face_x,head_y+5,2,5,shadow);_rect(image,11+face_x,head_y+4,2,5,skin.lightened(0.17))
	if race == "fairy":
		_polygon(image,[11,head_y+5, 5,head_y+2, 8,head_y+8, 11,head_y+9],skin)
		_polygon(image,[22,head_y+5, 28,head_y+2, 25,head_y+8, 22,head_y+9],shadow)
		_pixel(image,6,head_y+3,skin.lightened(0.3));_pixel(image,26,head_y+4,skin)
	if not back:
		if not profile:
			_rect(image,12,head_y+6,4,2,shadow.darkened(0.3));_rect(image,18,head_y+6,4,2,shadow.darkened(0.3))
			_pixel(image,14,head_y+6,_color("eyes",look.eyes,race).lightened(0.2));_pixel(image,19,head_y+6,_color("eyes",look.eyes,race).lightened(0.2))
			_line(image,16,head_y+7,15,head_y+9,shadow);_pixel(image,16,head_y+9,skin.lightened(0.25))
		else:
			_rect(image,11,head_y+6,4,2,shadow.darkened(0.5));_pixel(image,12,head_y+6,_color("eyes",look.eyes,race).lightened(0.3))
			_rect(image,9,head_y+8,3,2,skin);_pixel(image,9,head_y+9,shadow)
		_line(image,14,head_y+11,18,head_y+11,shadow)
	if not back and look.presentation == "feminine":
		_pixel(image,11,head_y+6,hair.darkened(0.35));_pixel(image,22,head_y+6,hair.darkened(0.35))
	elif not back and look.presentation == "masculine":
		_line(image,12,head_y+5,15,head_y+5,shadow);_line(image,19,head_y+5,22,head_y+5,shadow)
	if race == "beastfolk" and not back:
		_rect(image,13,head_y+9,8,3,skin.lightened(0.25));_rect(image,16,head_y+8,3,2,hair.darkened(0.5))
	if race == "draconian" and not back:
		_rect(image,14,head_y+9,8,3,shadow);_line(image,14,head_y+11,20,head_y+11,skin.lightened(0.15))
		_pixel(image,21,head_y+8,skin.lightened(0.4));_pixel(image,11,head_y+9,skin.lightened(0.3))
	if back:
		var nape: Color = skin.darkened(0.08) if look.hair_style == "shaved" else hair.darkened(0.2)
		_rect(image,11,head_y+2,11,10,nape);_line(image,12,head_y+4,12,head_y+9,nape.lightened(0.18))
		_polygon(image,[11,16+bob, 22,16+bob, 23,25+bob, 9,25+bob],cloth.darkened(0.05))
		_line(image,12,18+bob,11,23+bob,cloth.lightened(0.17))
	var hair_style: String = look.hair_style
	if hair_style != "shaved":
		_polygon(image,[10,head_y+6, 9,head_y+2, 12,head_y-1, 19,head_y-1, 23,head_y+3, 23,head_y+6, 19,head_y+3, 13,head_y+3, 12,head_y+7],hair.darkened(0.30))
		_rect(image,12,head_y,8,3,hair);_line(image,13,head_y,18,head_y,hair.lightened(0.25))
		if hair_style == "swept": _polygon(image,[11,head_y+3, 16,head_y, 21,head_y+2, 14,head_y+5],hair)
		if hair_style == "long":
			_rect(image,10,head_y+5,3,11,hair);_rect(image,21,head_y+5,3,11,hair.darkened(0.22))
			_line(image,11,head_y+8,11,head_y+14,hair.lightened(0.20))
		if hair_style == "braid":
			for y: int in range(head_y+5,head_y+17,3):
				_rect(image,10,y,3,3,hair.darkened(0.25));_line(image,10,y,12,y+2,hair.lightened(0.2))
		if hair_style == "mohawk":
			_polygon(image,[14,head_y+3, 14,head_y-2, 16,head_y-4, 18,head_y-1, 19,head_y+3],hair)
			_line(image,15,head_y,16,head_y-3,hair.lightened(0.25))
		if hair_style == "knots":
			_ellipse(image,10,head_y+1,3,3,hair);_ellipse(image,23,head_y+1,3,3,hair.darkened(0.25))
	else:
		_line(image,12,head_y+1,20,head_y+1,hair.darkened(0.1));_pixel(image,22,head_y+4,hair)
	if race == "beastfolk":
		_polygon(image,[10,head_y+4, 7,head_y-3, 14,head_y+1],hair.darkened(0.3));_line(image,9,head_y,11,head_y+3,skin)
		_polygon(image,[20,head_y+1, 26,head_y-3, 24,head_y+6],hair.darkened(0.3));_line(image,24,head_y,22,head_y+3,shadow)
	if race == "draconian":
		_polygon(image,[11,head_y+3, 7,head_y-3, 10,head_y-2, 15,head_y+2],shadow);_line(image,8,head_y-2,12,head_y+2,Color("c8c7b1"))
		_polygon(image,[20,head_y+2, 25,head_y-3, 24,head_y+2, 22,head_y+5],shadow);_pixel(image,24,head_y-2,Color("adaf9f"))
	if not back:
		match str(look.face_detail):
			"scar": _line(image,20,head_y+5,18,head_y+10,skin.lightened(0.4))
			"paint": _rect(image,12,head_y+9,2,2,accent);_rect(image,20,head_y+9,2,2,accent)
			"freckles": _pixel(image,13,head_y+9,shadow);_pixel(image,20,head_y+9,shadow)
			"beard":
				_polygon(image,[11,head_y+10, 16,head_y+12, 22,head_y+10, 21,head_y+15, 16,head_y+18, 12,head_y+15],hair.darkened(0.2))
				_line(image,14,head_y+14,15,head_y+16,hair.lightened(0.15));_line(image,19,head_y+13,18,head_y+16,hair)
			"moustache": _rect(image,14,head_y+10,7,2,hair.darkened(0.2))
	match str(look.accessory):
		"earring": _pixel(image,10,head_y+10,Color("e0c381"));_pixel(image,10,head_y+11,Color("a18c63"))
		"headband": _rect(image,11,head_y+4,12,2,accent);_line(image,12,head_y+4,21,head_y+4,accent.lightened(0.25))
		"circlet": _line(image,11,head_y+4,22,head_y+4,metal);_rect(image,16,head_y+4,2,2,accent.lightened(0.4))
		"goggles":
			_rect(image,10,head_y+3,14,3,Color("796d58"));_rect(image,12,head_y+3,4,2,Color("64939e"));_rect(image,18,head_y+3,4,2,Color("64939e"));_pixel(image,12,head_y+3,metal)
		"scarf": _rect(image,12,head_y+13,11,3,accent);_rect(image,21,head_y+15,3,6,accent.darkened(0.18))
		"hood":
			_line(image,9,head_y+3,9,head_y+12,cloth);_line(image,24,head_y+3,24,head_y+13,cloth.darkened(0.25))
			_line(image,10,head_y+1,13,head_y-2,cloth.lightened(0.25));_line(image,13,head_y-2,20,head_y-2,cloth)
	# Profession/class props differ in outline, independent of clothing colors.
	if role in ["ranged", "archer", "scout"]:
		_line(image,27,16+bob,30,20+bob,Color("a38963"));_line(image,30,20+bob,29,25+bob,Color("a38963"));_line(image,29,25+bob,26,27+bob,Color("a38963"));_line(image,27,16+bob,26,27+bob,metal.darkened(0.3))
	elif role in ["support", "controller", "summoner", "scholar", "priest"]:
		_line(image,27,12+bob,26,29,Color("76634c"));_ellipse(image,27,12+bob,2,2,accent.lightened(0.3));_pixel(image,27,11+bob,metal)
	elif role in ["tank", "skirmisher", "melee", "fighter"]:
		_line(image,27,13+bob,27,24,metal);_line(image,28,14+bob,28,22,Color("6b8293"));_line(image,25,24,29,24,Color("a89a77"))
	if direction == 2: image.flip_x()
	return image
