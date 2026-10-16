extends Node2D
## Stand-in attacker: records how it was parried.

var parried: Array = []

func on_parried(perfect: bool, from_x: float) -> void:
	parried.append([perfect, from_x])
