class_name CombatFx
extends Node
## The combat effects: a slash arc on every swing, a spark and a damage number where a hit lands, a burst when an
## enemy dies, a ring when the hero parries, screen shake for all of it. Everything is added over the scene.
## The pixel effects from the free packs (LibraryFx) add impacts per weapon, dust, explosions, shockwaves and casts.

const SLASH_TINT := Color(0.86, 0.94, 1.0)
const SLASH_STORM_TINT := Color(0.45, 0.72, 1.0)
const SLASH_FORWARD_PIXELS: float = 9.0
const SLASH_CHEST_PIXELS: float = -6.0
const SPARK_TINT := Color(1.0, 0.92, 0.7)
const BURST_TINT := Color(1.0, 0.6, 0.35)
const PARRY_TINT := Color(0.8, 0.9, 1.0)
const PERFECT_PARRY_TINT := Color(1.0, 0.85, 0.4)
const NUMBER_RISE_PIXELS: float = 20.0
const HURT_SHAKE: float = 0.35

# effect cues from the free packs (CodeManu: CC-BY 4.0; MatheusGG28: free, credit optional)
const CUE_PUNCH := "matheusgg28_pixel_fx/impact_punch"
const CUE_ARROW_HIT := "matheusgg28_pixel_fx/impact_projectile"
const CUE_MAGIC_HIT := "codemanu_pixel_fx/magickahit"
const CUE_DEATH_DUST := "matheusgg28_pixel_fx/dust_2"
const CUE_DEATH_BURST := "matheusgg28_pixel_fx/shockwave"
const CUE_BOSS_BLAST := "matheusgg28_pixel_fx/explosion_big"
const CUE_BOSS_NOVA := "codemanu_pixel_fx/nebula"
const CUE_PHASE := "codemanu_pixel_fx/nebula"
const CUE_PARRY := "matheusgg28_pixel_fx/shockwave_2"
const CUE_PERFECT_PARRY := "matheusgg28_pixel_fx/shockwave_3"
const CUE_ROLL_DUST := "matheusgg28_pixel_fx/dust_2"
const CUE_LAND_DUST := "matheusgg28_pixel_fx/dust"
const CUE_DRINK := "codemanu_pixel_fx/magicbubbles"
const CUE_STORM_CAST := "codemanu_pixel_fx/casting"
const CUE_REND_CAST := "codemanu_pixel_fx/flamelash"
const CUE_KEG := "matheusgg28_pixel_fx/explosion_big"
const CUE_SLAM := "matheusgg28_pixel_fx/shockwave"
const CUE_SUMMON := "codemanu_pixel_fx/protectioncircle"
## A boss goes out in this many big explosions, this far apart in time and space.
const BOSS_BLASTS: int = 4
const BOSS_BLAST_GAP: float = 0.18
const BOSS_BLAST_SPREAD: float = 22.0

var _player: Player
var _level: Node2D
var _shake: CameraShake
var _last_health: int = -1
## Footsteps while the hero runs, this far apart.
const STEP_SECONDS: float = 0.3
var _step_left: float = 0.0


func bind(level: Node2D, player: Player, camera: Camera2D) -> void:
	_level = level
	_player = player
	_shake = CameraShake.new()
	_shake.name = "CameraShake"
	camera.add_child(_shake)
	player.move_started.connect(_on_move_started)
	player.hit_landed.connect(_on_hit_landed)
	player.parried.connect(_on_parried)
	player.rolled.connect(func() -> void: _at_feet(CUE_ROLL_DUST, -_player.facing(), 1.0))
	player.landed.connect(func() -> void: _at_feet(CUE_LAND_DUST, _player.facing(), 0.8))
	player.drank.connect(func() -> void: LibraryFx.spawn(_level, CUE_DRINK, _player.global_position + Vector2(0.0, -4.0)))
	player.ability_cast.connect(_on_ability_cast)
	player.rolled.connect(func() -> void: Sound.play(&"roll"))
	player.landed.connect(func() -> void: Sound.play(&"land"))
	player.jumped.connect(func() -> void: Sound.play(&"jump"))
	player.drank.connect(func() -> void: Sound.play(&"drink"))
	player.parried.connect(func(_perfect: bool) -> void: Sound.play(&"clash"))
	player.weapon_swapped.connect(func() -> void: Sound.play(&"draw"))
	var health: Health = player.get_node("Health")
	_last_health = health.current
	health.health_changed.connect(_on_hero_health_changed)


func shake() -> CameraShake:
	return _shake


## Hooks an enemy: its death, its blast, its slams, summons and second phase.
func watch_enemy(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemy.exploded.connect(func() -> void:
		LibraryFx.spawn(_level, CUE_KEG, enemy.global_position, false, 1.6)
		_shake.kick(0.5))
	enemy.slammed.connect(func(at: Vector2) -> void: LibraryFx.spawn(_level, CUE_SLAM, at + Vector2(0.0, -6.0), false, 1.4))
	enemy.summoned.connect(func(at: Vector2) -> void: LibraryFx.spawn(_level, CUE_SUMMON, at, false, 1.2))
	enemy.exploded.connect(func() -> void: Sound.play(&"blast"))
	enemy.slammed.connect(func(_at: Vector2) -> void: Sound.play(&"slam"))
	enemy.summoned.connect(func(_at: Vector2) -> void: Sound.play(&"summon"))
	var hp := {"last": enemy.health().current}
	enemy.health().health_changed.connect(func(current: int, _maximum: int) -> void:
		if current < hp["last"] and current > 0:
			Sound.play(&"enemy_hurt")
		hp["last"] = current)
	enemy.phase_changed.connect(func(_phase: int) -> void: Sound.play(&"roar"))
	enemy.phase_changed.connect(func(_phase: int) -> void:
		if is_instance_valid(enemy):
			LibraryFx.spawn(_level, CUE_PHASE, enemy.global_position, false, 1.5)
			_shake.kick(0.6))


## The hero's feet: dust goes there, trailing the way he came from.
func _at_feet(cue: String, facing: float, size: float) -> void:
	var feet := _player.global_position + Vector2(-facing * 4.0, GameConfig.tiles(Player.BODY_SIZE_TILES.y) / 2.0 - 4.0)
	LibraryFx.spawn(_level, cue, feet, facing < 0.0, size)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	if _player.state() == PlayerStateMachine.PlayerState.RUN and _player.is_on_floor():
		_step_left -= delta
		if _step_left <= 0.0:
			_step_left = STEP_SECONDS
			Sound.play(&"step")
	else:
		_step_left = 0.0


func _on_ability_cast(ability: StringName) -> void:
	Sound.play(&"cast")
	var cue := CUE_STORM_CAST if ability == &"storm" else CUE_REND_CAST
	LibraryFx.spawn(_level, cue, _player.global_position + Vector2(_player.facing() * 8.0, -4.0), _player.facing() < 0.0, 1.2)


func _on_move_started(move: WeaponMove, facing: float) -> void:
	if move != null:
		if move.kind == WeaponMove.Kind.PROJECTILE:
			Sound.play(&"spell" if move.projectile_fx != &"" else &"arrow")
		else:
			Sound.play(&"swing_heavy" if move.damage_multiplier >= 1.6 else &"swing")
	if move == null or move.fx == &"":
		return
	var tint := SLASH_STORM_TINT if _player.storm_seconds_left() > 0.0 else SLASH_TINT
	var forward := SLASH_FORWARD_PIXELS + GameConfig.tiles(move.fx_forward_tiles)
	var at := _player.global_position + Vector2(facing * forward, SLASH_CHEST_PIXELS)
	FxSprite.spawn(_level, move.fx, at, 0.0, facing < 0.0, tint, move.fx_scale)


func _on_hit_landed(target: Node, damage: int) -> void:
	if not (target is Node2D):
		return
	var at := (target as Node2D).global_position
	var strength := 0.75 + minf(float(damage) / 20.0, 0.8)
	FxSprite.spawn(_level, &"spark", at, randf() * TAU, false, SPARK_TINT, strength)
	var move := _player.strike_move()
	Sound.play(&"punch" if move != null and String(move.impact_fx) == CUE_PUNCH else &"hit")
	if move != null and move.impact_fx != &"":
		LibraryFx.spawn(_level, String(move.impact_fx), at, at.x < _player.global_position.x, 1.0 + minf(float(damage) / 30.0, 0.6))
	DamageNumber.spawn(_level, damage, at + Vector2(0.0, -NUMBER_RISE_PIXELS))
	_shake.kick(clampf(0.12 + float(damage) * 0.018, 0.12, 0.6))


func _on_enemy_died(enemy: Enemy) -> void:
	var at := enemy.global_position
	FxSprite.spawn(_level, &"ring", at, 0.0, false, BURST_TINT, 0.9)
	FxSprite.spawn(_level, &"spark", at, randf() * TAU, false, SPARK_TINT, 1.6)
	var feet := at + Vector2(0.0, GameConfig.tiles(enemy.data.body_size_tiles.y) / 2.0 - 6.0)
	LibraryFx.spawn(_level, CUE_DEATH_DUST, feet, enemy.facing() < 0.0, 1.2)
	LibraryFx.spawn(_level, CUE_DEATH_BURST, at, false, 1.0)
	Sound.play(&"enemy_die")
	_shake.kick(0.25)
	if enemy.data.boss:
		_boss_finale(at)


## A boss goes out in a chain of big explosions round its body and a burst of light.
func _boss_finale(at: Vector2) -> void:
	LibraryFx.spawn(_level, CUE_BOSS_NOVA, at, false, 2.0)
	_shake.kick(0.9)
	for i in BOSS_BLASTS:
		var spot := at + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 0.6)) * BOSS_BLAST_SPREAD
		if i == 0:
			LibraryFx.spawn(_level, CUE_BOSS_BLAST, spot, false, 2.0)
		else:
			get_tree().create_timer(BOSS_BLAST_GAP * i).timeout.connect(func() -> void:
				if is_instance_valid(_level):
					LibraryFx.spawn(_level, CUE_BOSS_BLAST, spot, false, 2.0)
					_shake.kick(0.5))


func _on_parried(perfect: bool) -> void:
	var tint := PERFECT_PARRY_TINT if perfect else PARRY_TINT
	FxSprite.spawn(_level, &"ring", _player.global_position + Vector2(0.0, -6.0), 0.0, false, tint, 1.6 if perfect else 1.0)
	LibraryFx.spawn(_level, CUE_PERFECT_PARRY if perfect else CUE_PARRY, _player.global_position + Vector2(_player.facing() * 6.0, -6.0), false, 1.5 if perfect else 1.2)
	_shake.kick(0.5 if perfect else 0.3)


func _on_hero_health_changed(current: int, _maximum: int) -> void:
	if _last_health >= 0 and current < _last_health:
		_shake.kick(HURT_SHAKE)
		Sound.play(&"hero_hurt")
	_last_health = current
