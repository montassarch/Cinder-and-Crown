class_name EnemyMove
extends Resource
## One attack, one file. An enemy is a list of these (see EnemyData.moves). Distances in
## tiles, times in seconds. Only MELEE and PROJECTILE moves can be parried: the rest are
## dodged (roll through, jump over).

enum Kind { MELEE, PROJECTILE, SLAM, DASH, DIVE, EXPLODE, HAZARD, SUMMON }

@export var id: String = ""
@export var kind: Kind = Kind.MELEE
## The wind-up: the closing ring plays over this time.
@export var telegraph_seconds: float = 0.5
## MELEE: how long the strike is live. DASH and DIVE: how long the rush lasts.
@export var active_seconds: float = 0.15
@export var recovery_seconds: float = 0.6
@export var damage: int = 5
## MELEE: reach. EXPLODE: blast radius.
@export var reach_tiles: float = 1.5
## PROJECTILE, SLAM wave, DASH and DIVE speed.
@export var speed_tiles: float = 0.0
## PROJECTILE flight distance, SLAM wave travel distance.
@export var range_tiles: float = 0.0
@export var parryable: bool = true
## Afterwards the enemy is exposed for this long: it takes extra damage (a dive's landing).
@export var exposed_seconds: float = 0.0
## PROJECTILE: the shot's colour (fully transparent keeps the default ember orange).
@export var tint: Color = Color(0, 0, 0, 0)
## HAZARD: spots marked on the floor round the hero as the wind-up starts (`count` of them, `spacing_tiles` apart,
## each `reach_tiles` either side and `hazard_height_tiles` tall); the painted effect `hazard_art` erupts there as
## the wind-up ends and hurts for `active_seconds`. SUMMON: `count` of `summon` appear beside the caster.
@export var count: int = 1
@export var spacing_tiles: float = 0.0
@export var hazard_art: StringName = &""
@export var hazard_height_tiles: float = 4.0
@export var summon: EnemyData


## False when a number this kind of move depends on is missing.
func is_valid() -> bool:
	if telegraph_seconds <= 0.0:
		return false
	# Only a melee swing or a thrown shot can be deflected; the rest are plain hits.
	if parryable and kind != Kind.MELEE and kind != Kind.PROJECTILE:
		return false
	match kind:
		Kind.MELEE:
			return reach_tiles > 0.0 and active_seconds > 0.0
		Kind.PROJECTILE, Kind.SLAM:
			return speed_tiles > 0.0 and range_tiles > 0.0
		Kind.DASH, Kind.DIVE:
			return speed_tiles > 0.0 and active_seconds > 0.0
		Kind.EXPLODE:
			return reach_tiles > 0.0
		Kind.HAZARD:
			return reach_tiles > 0.0 and active_seconds > 0.0 and count > 0 and hazard_art != &""
		Kind.SUMMON:
			return summon != null and count > 0
	return false
