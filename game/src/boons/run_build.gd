class_name RunBuild
extends RefCounted
## The boons taken so far this run and the stats they add up to. Pure state: the
## player reads the multipliers, the level rolls the offers. Cleared when a run ends.

const RARITY_WEIGHTS := {
	BoonData.Rarity.COMMON: 60.0,
	BoonData.Rarity.RARE: 30.0,
	BoonData.Rarity.EPIC: 10.0,
}
## Each earlier showing of a boon cuts its weight to 1 / (1 + this * showings).
const REPEAT_PENALTY: float = 1.5

var _taken: Dictionary = {}
var _offered: Dictionary = {}
var _damage: float = 0.0
var _speed: float = 0.0
var _mana_gain: float = 0.0
var _lifesteal: float = 0.0
var _max_health: float = 0.0


func apply(boon: BoonData) -> void:
	_taken[boon.id] = times_taken(boon.id) + 1
	match boon.effect:
		BoonData.Effect.DAMAGE:
			_damage += boon.amount
		BoonData.Effect.SPEED:
			_speed += boon.amount
		BoonData.Effect.MANA_GAIN:
			_mana_gain += boon.amount
		BoonData.Effect.LIFESTEAL:
			_lifesteal += boon.amount
		BoonData.Effect.MAX_HEALTH:
			_max_health += boon.amount
		BoonData.Effect.HEAL:
			pass  # an instant effect, applied by whoever owns the health


func clear() -> void:
	_taken.clear()
	_offered.clear()
	_damage = 0.0
	_speed = 0.0
	_mana_gain = 0.0
	_lifesteal = 0.0
	_max_health = 0.0


func times_taken(id: String) -> int:
	return _taken.get(id, 0)


func damage_multiplier() -> float:
	return 1.0 + _damage


func speed_multiplier() -> float:
	return 1.0 + _speed


func mana_gain_multiplier() -> float:
	return 1.0 + _mana_gain


## Hit points restored per sword hit that lands.
func lifesteal() -> int:
	return roundi(_lifesteal)


func bonus_max_health() -> int:
	return roundi(_max_health)


## Up to `count` distinct boons from `pool`. Rarer boons come up less often, a boon
## shown earlier in the run comes up less often, and a unique boon already taken
## is left out. The caller's rng makes a seed replay the same offers.
func roll_offers(pool: Array[BoonData], count: int, rng: RandomNumberGenerator) -> Array[BoonData]:
	var available: Array[BoonData] = pool.filter(func(b: BoonData) -> bool: return not (b.unique and times_taken(b.id) > 0))
	var offers: Array[BoonData] = []
	while offers.size() < count and not available.is_empty():
		var weights: Array[float] = []
		var total := 0.0
		for boon in available:
			var weight: float = RARITY_WEIGHTS[boon.rarity] / (1.0 + REPEAT_PENALTY * _offered.get(boon.id, 0))
			weights.append(weight)
			total += weight
		var roll := rng.randf() * total
		var pick := available.size() - 1
		for i in available.size():
			roll -= weights[i]
			if roll <= 0.0:
				pick = i
				break
		var chosen := available[pick]
		offers.append(chosen)
		_offered[chosen.id] = _offered.get(chosen.id, 0) + 1
		available.remove_at(pick)
	return offers
