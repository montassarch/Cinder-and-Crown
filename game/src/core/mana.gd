class_name Mana
extends Node
## Spendable resource for abilities. Refills slowly on its own; the owner can add more
## (the hero gains some for every sword hit that lands).

signal mana_changed(current: float, max_mana: float)

@export var max_mana: float = 100.0
@export var regen_per_second: float = 2.0

var current: float = 0.0


func refill() -> void:
	_set_current(max_mana)


func can_afford(cost: float) -> bool:
	return current + 0.0001 >= cost


## Takes the cost if there is enough; otherwise changes nothing and returns false.
func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	_set_current(current - cost)
	return true


func gain(amount: float) -> void:
	_set_current(minf(max_mana, current + maxf(amount, 0.0)))


func advance(delta: float) -> void:
	if current < max_mana and regen_per_second > 0.0:
		gain(regen_per_second * delta)


func _set_current(value: float) -> void:
	value = clampf(value, 0.0, max_mana)
	if is_equal_approx(value, current):
		current = value
		return
	current = value
	mana_changed.emit(current, max_mana)
