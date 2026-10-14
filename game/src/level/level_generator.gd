class_name LevelGenerator
extends RefCounted
## Deterministic: the same pool, count and seed always give the same layout.
## Returns [] when the pool cannot make a valid level, never a partial one.


static func generate(pool: Array[RoomData], room_count: int, rng_seed: int) -> Array[RoomData]:
	var layout: Array[RoomData] = []
	if room_count < 2:
		return layout

	var spawns := _of_kind(pool, RoomData.Kind.SPAWN)
	var normals := _of_kind(pool, RoomData.Kind.NORMAL)
	var exits := _of_kind(pool, RoomData.Kind.EXIT)
	var middle := room_count - 2
	if spawns.is_empty() or exits.is_empty() or (middle > 0 and normals.is_empty()):
		return layout

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	layout.append(spawns[rng.randi_range(0, spawns.size() - 1)])
	for i in middle:
		layout.append(_pick_avoiding(normals, layout[layout.size() - 1], rng))
	layout.append(exits[rng.randi_range(0, exits.size() - 1)])
	return layout


static func _of_kind(pool: Array[RoomData], kind: RoomData.Kind) -> Array[RoomData]:
	var matches: Array[RoomData] = []
	for room in pool:
		if room.kind == kind:
			matches.append(room)
	return matches


## "No repeat" is a preference: drop the previous room from the options when there
## is any other choice, otherwise accept the repeat. Nothing loops.
static func _pick_avoiding(candidates: Array[RoomData], previous: RoomData, rng: RandomNumberGenerator) -> RoomData:
	var options: Array[RoomData] = []
	for room in candidates:
		if room != previous:
			options.append(room)
	if options.is_empty():
		options = candidates
	return options[rng.randi_range(0, options.size() - 1)]
