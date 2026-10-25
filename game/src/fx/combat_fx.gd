class_name CombatFx
extends Node
## The combat effects: a slash arc on every swing, a spark and a damage number where a hit lands, a burst when an
## enemy dies, a ring when the hero parries, screen shake for all of it. Everything is added over the scene.

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

var _player: Player
var _level: Node2D
var _shake: CameraShake
var _last_health: int = -1


func bind(level: Node2D, player: Player, camera: Camera2D) -> void:
	_level = level
	_player = player
	_shake = CameraShake.new()
	_shake.name = "CameraShake"
	camera.add_child(_shake)
	player.move_started.connect(_on_move_started)
	player.hit_landed.connect(_on_hit_landed)
	player.parried.connect(_on_parried)
	var health: Health = player.get_node("Health")
	_last_health = health.current
	health.health_changed.connect(_on_hero_health_changed)


func shake() -> CameraShake:
	return _shake


## Hooks an enemy: its death bursts.
func watch_enemy(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died.bind(enemy))


func _on_move_started(move: WeaponMove, facing: float) -> void:
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
	DamageNumber.spawn(_level, damage, at + Vector2(0.0, -NUMBER_RISE_PIXELS))
	_shake.kick(clampf(0.12 + float(damage) * 0.018, 0.12, 0.6))


func _on_enemy_died(enemy: Enemy) -> void:
	var at := enemy.global_position
	FxSprite.spawn(_level, &"ring", at, 0.0, false, BURST_TINT, 0.9)
	FxSprite.spawn(_level, &"spark", at, randf() * TAU, false, SPARK_TINT, 1.6)
	_shake.kick(0.25)


func _on_parried(perfect: bool) -> void:
	var tint := PERFECT_PARRY_TINT if perfect else PARRY_TINT
	FxSprite.spawn(_level, &"ring", _player.global_position + Vector2(0.0, -6.0), 0.0, false, tint, 1.6 if perfect else 1.0)
	_shake.kick(0.5 if perfect else 0.3)


func _on_hero_health_changed(current: int, _maximum: int) -> void:
	if _last_health >= 0 and current < _last_health:
		_shake.kick(HURT_SHAKE)
	_last_health = current
