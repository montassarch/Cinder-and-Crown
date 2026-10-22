class_name EnemyData
extends Resource
## One file per enemy type. Distances in tiles, times in seconds.

enum Behaviour { CHASER, FLYER, CHARGER, KEEP_DISTANCE }
## How an enemy with several moves plays them: in order as one string, or one picked each time.
enum Pattern { SEQUENCE, RANDOM }

@export var display_name: String = ""
## Folder of this enemy's sprites under art/enemies/ ("" draws a plain coloured box).
@export var art: String = ""
@export var max_health: int = 20
@export var move_speed_tiles: float = 2.0
@export var attack_damage: int = 5
## CHASER/FLYER: reach of the strike. CHARGER: how close the target must be to start winding up.
@export var attack_range_tiles: float = 1.5
@export var telegraph_seconds: float = 0.5
@export var recovery_seconds: float = 0.8
@export var behaviour: Behaviour = Behaviour.CHASER
## The attacks this enemy performs. Empty: it gets one implicit move built from the older
## attack_* fields above (a melee swing, or a dash for a CHARGER).
@export var moves: Array[EnemyMove] = []
@export var pattern: Pattern = Pattern.SEQUENCE
## Pause between the moves of a string, and the rest after the whole string.
@export var chain_gap_seconds: float = 0.1
@export var cooldown_seconds: float = 0.0
## KEEP_DISTANCE: how far from the hero it likes to stand.
@export var preferred_range_tiles: float = 0.0
## Hits from the side it faces are absorbed (they still wear its poise down).
@export var shielded: bool = false
## Sword hits it shrugs off before its guard breaks. 0: every hit that lands while it is not
## yet committed to a strike makes it flinch.
@export var poise: int = 0
## How much of a wave's budget this enemy costs.
@export var threat: int = 2
## The first level (0 = the first of a run) this enemy can turn up in.
@export var unlock_depth: int = 0
## No wave holds more than this many of this enemy.
@export var max_per_wave: int = 3
## Cells dropped when it dies (banked for the between-runs shop).
@export var cell_reward: int = 1
@export var body_size_tiles: Vector2 = Vector2(1.0, 1.8)
@export var tint: Color = Color(0.6, 0.6, 0.6)


## The moves to play: the listed ones, or one built from the older attack fields.
func effective_moves() -> Array[EnemyMove]:
	if not moves.is_empty():
		return moves
	var implicit := EnemyMove.new()
	implicit.id = "implicit"
	implicit.damage = attack_damage
	implicit.telegraph_seconds = telegraph_seconds
	implicit.recovery_seconds = recovery_seconds
	if behaviour == Behaviour.CHARGER:
		implicit.kind = EnemyMove.Kind.DASH
		implicit.parryable = false
		implicit.speed_tiles = move_speed_tiles * Enemy.CHARGE_SPEED_MULTIPLIER
		implicit.active_seconds = Enemy.CHARGE_DURATION
		implicit.reach_tiles = Enemy.CHARGE_CONTACT_TILES
	else:
		implicit.kind = EnemyMove.Kind.MELEE
		implicit.reach_tiles = attack_range_tiles
	return [implicit]
