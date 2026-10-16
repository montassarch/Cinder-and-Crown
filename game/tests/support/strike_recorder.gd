extends Node2D
## Stand-in for the player: records strikes and can answer by parrying them.

var strikes: Array = []
var parry_it: bool = false

func take_strike(damage: int, source_x: float, attacker: Node) -> void:
	strikes.append([damage, source_x, attacker])
	if parry_it:
		attacker.on_parried(false, global_position.x)
