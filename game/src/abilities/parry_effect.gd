class_name ParryEffect
extends Node2D
## The spark where a strike is deflected: a ring and a burst of rays in front of the hero,
## white for a parry, gold and larger for a perfect one. Ticks in real time, so the hit-stop
## that follows a deflect still shows it.

const SECONDS: float = 0.22
const PERFECT_SECONDS: float = 0.34
const REACH_TILES: float = 1.0
const RADIUS: float = 15.0
const PERFECT_RADIUS: float = 24.0
const RAYS: int = 8
const COLOR := Color(1.0, 1.0, 1.0)
const PERFECT_COLOR := Color(1.0, 0.82, 0.3)

var _player: Player
var _age: float = 0.0
var _active: bool = false
var _perfect: bool = false


func bind(player: Player) -> void:
	_player = player
	player.parried.connect(_on_parried)


func is_active() -> bool:
	return _active


func is_perfect() -> bool:
	return _perfect


## 0 when the flash starts, 1 when it is gone.
func progress() -> float:
	return clampf(_age / _length(), 0.0, 1.0)


func advance(delta: float) -> void:
	if not _active:
		return
	_age += delta
	if _age >= _length():
		_active = false
	queue_redraw()


func _process(_delta: float) -> void:
	if _active:
		advance(get_process_delta_time() / maxf(Engine.time_scale, 0.001))


func _on_parried(perfect: bool) -> void:
	_perfect = perfect
	_age = 0.0
	_active = true
	position = Vector2(_player.facing() * GameConfig.tiles(REACH_TILES), 0.0)
	queue_redraw()


func _length() -> float:
	return PERFECT_SECONDS if _perfect else SECONDS


func _draw() -> void:
	if not _active:
		return
	var t := progress()
	var color := PERFECT_COLOR if _perfect else COLOR
	color.a = 1.0 - t
	var radius := (PERFECT_RADIUS if _perfect else RADIUS) * (0.35 + 0.65 * t)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color, 2.0)
	for i in RAYS:
		var angle := TAU * float(i) / RAYS
		var direction := Vector2.from_angle(angle)
		draw_line(direction * radius * 0.55, direction * radius * 1.25, color, 1.0)
