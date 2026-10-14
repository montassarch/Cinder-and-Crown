class_name Health
extends Node

signal health_changed(current: int, max_health: int)
signal died

@export var max_health: int = 100

var current: int = 0


func _ready() -> void:
	current = max_health


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
