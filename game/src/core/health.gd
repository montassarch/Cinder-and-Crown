class_name Health
extends Node

## Hit points for anything that can die — the player and every enemy.
##
## Configured by an explicit configure() call rather than _ready(), for two
## reasons: enemies get their max health from an EnemyData resource at spawn
## time, and tests can exercise this without a scene tree.

## Emitted whenever current changes, including on configure().
signal health_changed(current: int, max_health: int)

## Emitted once, on the transition into zero. Never again.
signal died

@export var max_health: int = 100

var current: int = 0


## Sets the maximum and refills to full. Also the only way to revive
## something that has died — a stray heal must not do it.
func configure(new_max_health: int) -> void:
	max_health = maxi(new_max_health, 1)
	current = max_health
	health_changed.emit(current, max_health)


func _ready() -> void:
	if current == 0:
		configure(max_health)


## Applies damage and returns the amount actually absorbed, which is never
## more than the target had left. A dead target absorbs nothing.
func take_damage(amount: int) -> int:
	if not is_alive():
		return 0
	var absorbed := mini(maxi(amount, 0), current)
	if absorbed == 0:
		return 0
	current -= absorbed
	health_changed.emit(current, max_health)
	if current == 0:
		died.emit()
	return absorbed


## Restores health up to max_health. Does nothing to a dead target.
func heal(amount: int) -> void:
	if not is_alive():
		return
	var restored := mini(maxi(amount, 0), max_health - current)
	if restored == 0:
		return
	current += restored
	health_changed.emit(current, max_health)


func is_alive() -> bool:
	return current > 0
