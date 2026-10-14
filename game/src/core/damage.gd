class_name Damage
extends RefCounted

static func compute(base: int, multiplier: float, defense: int) -> int:
	return maxi(0, floori(base * multiplier) - defense)
