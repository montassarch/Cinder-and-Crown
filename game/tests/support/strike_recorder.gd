extends Node2D
## Stand-in for the player: records strikes (parryable) and plain hits (dodge-only), and can
## answer a strike by parrying it.

var strikes: Array = []
var hits: Array = []
var parry_it: bool = false

func take_strike(damage: int, source_x: float, attacker: Node) -> void:
	strikes.append([damage, source_x, attacker])
	if parry_it:
		attacker.on_parried(false, global_position.x)

func take_hit(damage: int, source_x: float, _knockback_tiles: float = 0.0) -> void:
	hits.append([damage, source_x])
