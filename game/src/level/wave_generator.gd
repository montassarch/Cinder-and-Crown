class_name WaveGenerator
extends RefCounted
## Picks the enemies for one room's wave. Deterministic for a given rng. Each enemy
## costs its `threat` out of the wave's budget, which grows with depth; heavier enemies
## unlock later and have a per-wave limit.

const BASE_BUDGET: int = 4
const BUDGET_PER_DEPTH: int = 2
## However big the budget, a wave stays readable.
const MAX_WAVE_SIZE: int = 6


static func budget_for(depth: int) -> int:
	return BASE_BUDGET + BUDGET_PER_DEPTH * maxi(depth, 0)


static func roll(pool: Array[EnemyData], depth: int, rng: RandomNumberGenerator) -> Array[EnemyData]:
	var wave: Array[EnemyData] = []
	var unlocked: Array[EnemyData] = pool.filter(func(e: EnemyData) -> bool: return e.unlock_depth <= depth and e.threat > 0)
	if unlocked.is_empty():
		return wave
	var remaining := budget_for(depth)
	while wave.size() < MAX_WAVE_SIZE:
		var options: Array[EnemyData] = unlocked.filter(func(e: EnemyData) -> bool:
			return e.threat <= remaining and wave.count(e) < e.max_per_wave)
		if options.is_empty():
			break
		var pick := options[rng.randi_range(0, options.size() - 1)]
		wave.append(pick)
		remaining -= pick.threat
	if wave.is_empty():
		# Nothing fits the budget: a room is never left empty, so send the cheapest.
		var cheapest := unlocked[0]
		for enemy in unlocked:
			if enemy.threat < cheapest.threat:
				cheapest = enemy
		wave.append(cheapest)
	return wave
