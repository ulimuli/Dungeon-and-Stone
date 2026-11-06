class_name StatAwareness
extends RefCounted
## Auditory contacts are evidence of a recent sound, never sight or identification.
## Ch244/625 establish hearing; ch413 establishes Sixth Sense danger intuition.
## Tile conversions and the three-minute sound lifetime are estimates.
const HEARING_SOURCES: Array[String] = ["https://hennoveltranslations.org/episodes/stgb-episode-244/","https://hennoveltranslations.org/episodes/stgb-episode-625/"]
const SIXTH_SOURCE: String = "https://hennoveltranslations.com/archives/episodes/stgb-episode-413"
const SOUND_LIFETIME: int = 3

static func radius(points: float) -> int:
	return StatPhysiology.hearing_radius(points)

static func connected_within(map: Dictionary, origin: Vector2i, target: Vector2i, maximum: int) -> bool:
	if maximum<=0 or absi(origin.x-target.x)+absi(origin.y-target.y)>maximum: return false
	var frontier: Array[Vector2i] = [origin]
	var depth: Dictionary = {origin:0}
	var cursor: int = 0
	while cursor<frontier.size():
		var current: Vector2i = frontier[cursor]; cursor+=1
		if current==target: return true
		if int(depth[current])>=maximum: continue
		for direction: Vector2i in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next: Vector2i = current+direction
			if depth.has(next) or not DungeonWorld.walkable(map,next): continue
			depth[next] = int(depth[current])+1
			frontier.append(next)
	return false

static func audible(map: Dictionary, observer: Vector2i, noise: Dictionary, hearing: float, now: int) -> bool:
	if not noise.get("pos") is Vector2i or not (noise.get("time") is int or noise.get("time") is float): return false
	var age: int = now-int(noise.time)
	return age>=0 and age<=SOUND_LIFETIME and connected_within(map,observer,noise.pos,radius(hearing))

static func danger_near(map: Dictionary, observer: Vector2i, targets: Array, points: float) -> bool:
	var maximum: int = clampi(ceili(maxf(0,points)/20.0),0,6)
	if maximum<=0: return false
	for target: Variant in targets:
		if target is Vector2i and connected_within(map,observer,target,maximum): return true
	return false
