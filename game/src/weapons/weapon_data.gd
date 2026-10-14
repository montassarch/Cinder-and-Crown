class_name WeaponData
extends Resource
## One file per weapon. Distances in tiles, times in seconds.

@export var display_name: String = ""
@export var damage: int = 1
@export var attack_duration: float = 0.3
## Start/end seconds within the attack during which the hitbox is live.
@export var hit_window: Vector2 = Vector2(0.1, 0.2)
@export var knockback_tiles: float = 1.0
@export var hitbox_size_tiles: Vector2 = Vector2(1.5, 1.0)
@export var hitbox_offset_tiles: Vector2 = Vector2(1.0, 0.0)
@export var hit_stop_seconds: float = 0.05


func is_hit_window_valid() -> bool:
	return hit_window.x >= 0.0 and hit_window.x < hit_window.y and hit_window.y <= attack_duration
