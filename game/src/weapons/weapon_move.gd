class_name WeaponMove
extends Resource
## One strike of a weapon: how long it lasts, where it hits, how it moves the hero and how it looks.
## Distances in tiles, times in seconds. A weapon is a set of these (see WeaponData).

enum Kind { MELEE, PROJECTILE }

@export var display_name: String = ""
@export var kind: Kind = Kind.MELEE
## Scales the weapon's base damage.
@export var damage_multiplier: float = 1.0
@export var duration: float = 0.3
## Start/end seconds within the move during which the hitbox is live (or, for a projectile move, the
## moment it is fired: the start).
@export var hit_window: Vector2 = Vector2(0.1, 0.2)
@export var hitbox_size_tiles: Vector2 = Vector2(1.5, 1.0)
@export var hitbox_offset_tiles: Vector2 = Vector2(1.0, 0.0)
@export var knockback_tiles: float = 1.0
@export var hit_stop_seconds: float = 0.05
## Forward speed while the move plays (negative hops backwards), in tiles per second.
@export var lunge_tiles_per_second: float = 0.0
## Downward speed set when an air move starts, in tiles per second (0 keeps normal falling).
@export var dive_speed_tiles: float = 0.0
## The hero animation to play (see PlayerVisual.ANIMS); empty plays the combo animation.
@export var anim: StringName = &""
## The glowing arc shown on the swing (see FxArt); empty shows none.
@export var fx: StringName = &"slash_a"
@export var fx_scale: float = 1.0
@export var fx_forward_tiles: float = 0.0
## Projectile moves only.
@export var projectile_count: int = 1
## 0 flies level; positive angles fly downward (so an air shot can aim at the ground).
@export var projectile_angle_degrees: float = 0.0
@export var projectile_spread_degrees: float = 0.0
@export var projectile_speed_tiles: float = 18.0
@export var projectile_range_tiles: float = 12.0
## How many enemies one shot passes through (0 stops at the first).
@export var projectile_pierce: int = 0
@export var projectile_tint: Color = Color(1.0, 0.9, 0.6)
@export var projectile_radius: float = 2.5


func is_valid() -> bool:
	return hit_window.x >= 0.0 and hit_window.x < hit_window.y and hit_window.y <= duration
