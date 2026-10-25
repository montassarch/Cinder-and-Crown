class_name WeaponData
extends Resource
## One file per weapon. Distances in tiles, times in seconds.
## A weapon is a set of WeaponMoves: a tap chain (tap again in time for the next one), an air move (attack while
## airborne) and a roll move (attack right after a roll). The plain swing fields below are used only by a weapon
## that defines no chain.

@export var display_name: String = ""
@export var damage: int = 1
@export var attack_duration: float = 0.3
## Start/end seconds within the attack during which the hitbox is live.
@export var hit_window: Vector2 = Vector2(0.1, 0.2)
@export var knockback_tiles: float = 1.0
@export var hitbox_size_tiles: Vector2 = Vector2(1.5, 1.0)
@export var hitbox_offset_tiles: Vector2 = Vector2(1.0, 0.0)
@export var hit_stop_seconds: float = 0.05
@export var chain: Array[WeaponMove] = []
@export var air_move: WeaponMove
@export var roll_move: WeaponMove

var _plain_swing: WeaponMove


func is_hit_window_valid() -> bool:
	for move in all_moves():
		if not move.is_valid():
			return false
	return hit_window.x >= 0.0 and hit_window.x < hit_window.y and hit_window.y <= attack_duration


func chain_length() -> int:
	return maxi(chain.size(), 1)


func chain_move(step: int) -> WeaponMove:
	if chain.is_empty():
		return _plain()
	return chain[clampi(step, 0, chain.size() - 1)]


## Where a tap lands in the chain: on after the previous strike if it came quickly, else the start.
func next_chain_step(previous: int, chained: bool) -> int:
	return (previous + 1) % chain_length() if chained else 0


func all_moves() -> Array[WeaponMove]:
	var moves: Array[WeaponMove] = []
	moves.append_array(chain)
	for extra in [air_move, roll_move]:
		if extra != null:
			moves.append(extra)
	return moves


func move_count() -> int:
	return all_moves().size()


func _plain() -> WeaponMove:
	if _plain_swing == null:
		_plain_swing = WeaponMove.new()
		_plain_swing.display_name = display_name
	_plain_swing.duration = attack_duration
	_plain_swing.hit_window = hit_window
	_plain_swing.hitbox_size_tiles = hitbox_size_tiles
	_plain_swing.hitbox_offset_tiles = hitbox_offset_tiles
	_plain_swing.knockback_tiles = knockback_tiles
	_plain_swing.hit_stop_seconds = hit_stop_seconds
	return _plain_swing
