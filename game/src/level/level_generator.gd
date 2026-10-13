class_name LevelGenerator
extends RefCounted

## Builds a room order from a pool and a seed.
##
## Pure and static: same pool, same count, same seed gives the same level
## every time. That reproducibility is the point -- a bug found in a run is
## worthless if the run cannot be rebuilt.

## How many times to retry a pick that would repeat the previous room.
##
## The no-repeat rule is a bounded PREFERENCE, not a loop condition. With a
## pool of one NORMAL room the rule is unsatisfiable, and a while-loop
## waiting for a different pick would hang the game instead of building a
## level. After this many tries it accepts the repeat and moves on.
const REPEAT_RETRIES: int = 8

## The smallest real level: somewhere to start, somewhere to leave.
const MIN_ROOMS: int = 2


## Returns the ordered rooms of one level, or an empty array if the pool
## cannot make a valid one.
##
## Guarantees when it returns non-empty: first room is SPAWN, last is EXIT,
## everything between is NORMAL, and no two adjacent rooms are the same
## resource unless the pool makes that impossible.
static func generate(
	pool: Array[RoomData], room_count: int, rng_seed: int
) -> Array[RoomData]:
	var result: Array[RoomData] = []

	var spawns := _of_kind(pool, RoomData.Kind.SPAWN)
	var exits := _of_kind(pool, RoomData.Kind.EXIT)
	var normals := _of_kind(pool, RoomData.Kind.NORMAL)

	# No start or no way out is not a level. Better an empty result the
	# caller can report than a room the player cannot leave.
	if spawns.is_empty() or exits.is_empty():
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	var total := maxi(room_count, MIN_ROOMS)
	# Without NORMAL rooms the level is just its two ends.
	if normals.is_empty():
		total = MIN_ROOMS

	result.append(spawns[rng.randi_range(0, spawns.size() - 1)])

	for _i: int in range(total - MIN_ROOMS):
		result.append(_pick_non_repeating(normals, result[result.size() - 1], rng))

	result.append(exits[rng.randi_range(0, exits.size() - 1)])
	return result


## Picks from candidates, preferring not to match `previous`, giving up
## after REPEAT_RETRIES so an impossible preference cannot hang.
static func _pick_non_repeating(
	candidates: Array[RoomData], previous: RoomData, rng: RandomNumberGenerator
) -> RoomData:
	var chosen := candidates[rng.randi_range(0, candidates.size() - 1)]
	var tries := 0
	while chosen == previous and tries < REPEAT_RETRIES:
		chosen = candidates[rng.randi_range(0, candidates.size() - 1)]
		tries += 1
	return chosen


static func _of_kind(pool: Array[RoomData], kind: RoomData.Kind) -> Array[RoomData]:
	var found: Array[RoomData] = []
	for room: RoomData in pool:
		if room != null and room.kind == kind:
			found.append(room)
	return found
