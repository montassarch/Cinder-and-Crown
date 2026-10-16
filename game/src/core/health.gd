class_name Health
extends Node

signal health_changed(current: int, max_health: int)
signal died

@export var max_health: int = 100

var current: int = 0


func _ready() -> void:
	current = max_health


## Re-seat max and current at runtime (data-driven owners configure after _ready).
func setup(new_max: int) -> void:
	max_health = new_max
	current = new_max
	health_changed.emit(current, max_health)


## Raise the cap and give the same amount of health (a max-health upgrade).
func raise_max(amount: int) -> void:
	if amount <= 0:
		return
	max_health += amount
	current += amount
	health_changed.emit(current, max_health)


func take_damage(amount: int) -> int:
	var absorbed := clampi(amount, 0, current)
	if absorbed == 0:
		return 0
	current -= absorbed
	health_changed.emit(current, max_health)
	if current == 0:
		died.emit()
	return absorbed


func heal(amount: int) -> void:
	if amount <= 0 or not is_alive():
		return
	current = mini(current + amount, max_health)
	health_changed.emit(current, max_health)


func is_alive() -> bool:
	return current > 0
