class_name EnemyData
extends Resource
## One file per enemy type. Distances in tiles, times in seconds.

enum Behaviour { CHASER, FLYER, CHARGER }

@export var display_name: String = ""
@export var max_health: int = 20
@export var move_speed_tiles: float = 2.0
@export var attack_damage: int = 5
## CHASER/FLYER: reach of the strike. CHARGER: how close the target must be to start winding up.
@export var attack_range_tiles: float = 1.5
@export var telegraph_seconds: float = 0.5
@export var recovery_seconds: float = 0.8
@export var behaviour: Behaviour = Behaviour.CHASER
## Sword hits it shrugs off before its guard breaks. 0: every hit that lands while it is not
## yet committed to a strike makes it flinch.
@export var poise: int = 0
@export var body_size_tiles: Vector2 = Vector2(1.0, 1.8)
@export var tint: Color = Color(0.6, 0.6, 0.6)
