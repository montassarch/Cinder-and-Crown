class_name WeaponData
extends Resource

## One weapon, as data. Adding a weapon to the game means adding a .tres
## file under data/weapons/ -- never editing code, never touching a match
## statement. The sandbox menu scans that folder at runtime, so a dropped-in
## file appears without a rebuild.
##
## Every spatial field is in TILES, per the project's resolution rule.

@export var display_name: String = "Unnamed Weapon"

## Base damage before multipliers and defense. See Damage.compute.
@export var damage: int = 10

## Total length of one swing, in seconds. The player is committed for this
## long, so it is the main cost of attacking.
@export var attack_duration: float = 0.3

## When the hitbox is live within the swing: x = open, y = close, both in
## seconds from the swing's start. The gap before x is the wind-up the
## player must commit to; the gap after y is the recovery they can be
## punished in.
@export var hit_window: Vector2 = Vector2(0.08, 0.18)

## Hitbox dimensions and its offset from the player, in tiles. Offset x is
## forward; it gets mirrored by facing direction.
@export var hitbox_size_tiles: Vector2 = Vector2(1.5, 1.0)
@export var hitbox_offset_tiles: Vector2 = Vector2(1.0, 0.0)

## Impulse applied to whatever this hits, in tiles/second.
@export var knockback_tiles: float = 2.0

## How long the game freezes on a landed hit. This is most of what makes a
## hit feel heavy rather than numeric -- a heavy weapon wants more.
@export var hit_stop_seconds: float = 0.06


## True when the hit window can actually be sampled during the swing.
##
## Guards four ways an authored file can be unusable: a window that starts
## after it ends, one that outlives the swing (leaving the hitbox live past
## the animation), a negative start, and a zero-length window that can
## never be sampled at all.
func is_hit_window_valid() -> bool:
	if hit_window.x < 0.0:
		return false
	if hit_window.x >= hit_window.y:
		return false
	return hit_window.y <= attack_duration
