class_name StormEffect
extends Node2D
## The hero's sword lightning, drawn along the real blade (HeroBlade has its position in every
## animation frame): a blue bolt from the sky onto the sword, then a glowing, crackling blade
## and a swoosh that trails the sword through each swing while charged. Crimson Rend swings
## leave the same swoosh in red. Charge fades over the final STORM_FADE_SECONDS.

const BOLT_SECONDS: float = 0.22
const BOLT_TOP_TILES: float = 9.0
const TRAIL_LENGTH: int = 9
## Trail only shows while the blade is really moving, in art pixels per physics tick.
const TRAIL_MIN_SPEED: float = 2.0
const TRAIL_ROOT: float = 0.55
const ARC_COUNT: int = 5

const BOLT := Color(0.55, 0.85, 1.0)
const CORE := Color(0.95, 0.99, 1.0)
const ARC := Color(0.4, 0.75, 1.0)
const SWOOSH := Color(0.45, 0.8, 1.0)
const REND_EDGE := Color(1.0, 0.33, 0.2)
const REND_GLOW := Color(0.78, 0.2, 0.62)

const State := PlayerStateMachine.PlayerState

var _player: Player
var _visual: PlayerVisual
var _bolt_left: float = 0.0
var _tick: int = 0
## Recent blade tips and roots in the player's own coordinates, newest last.
var _tips: Array[Vector2] = []
var _roots: Array[Vector2] = []


func bind(player: Player) -> void:
	_player = player
	_visual = player.get_node("Visual")
	player.storm_struck.connect(func() -> void: _bolt_left = BOLT_SECONDS)


## 1 while the charge is fresh, falling to 0 across the last STORM_FADE_SECONDS.
func charge_alpha() -> float:
	if _player == null:
		return 0.0
	var left := _player.storm_seconds_left()
	if left <= 0.0:
		return 0.0
	return clampf(left / Player.STORM_FADE_SECONDS, 0.0, 1.0)


func bolt_active() -> bool:
	return _bolt_left > 0.0


## The sword as (guard, tip) in the player's coordinates, for the frame being shown.
func blade() -> PackedVector2Array:
	var seg := HeroBlade.segment(_visual.animation, _visual.frame)
	var guard := _art_to_local(Vector2(seg.x, seg.y))
	var tip := _art_to_local(Vector2(seg.z, seg.w))
	return PackedVector2Array([guard, tip])


func _art_to_local(art: Vector2) -> Vector2:
	var x := PlayerVisual.FRAME.x - art.x if _visual.flip_h else art.x
	return _visual.position + Vector2(x, art.y)


func _physics_process(delta: float) -> void:
	_bolt_left = maxf(0.0, _bolt_left - delta)
	_tick += 1
	if _player != null:
		var seg := blade()
		_tips.append(seg[1])
		_roots.append(seg[0].lerp(seg[1], TRAIL_ROOT))
		if _tips.size() > TRAIL_LENGTH:
			_tips.pop_front()
			_roots.pop_front()
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var seg := blade()
	var guard := seg[0]
	var tip := seg[1]
	var state := _player.state()
	var alpha := charge_alpha()
	if state == State.REND:
		_draw_swoosh(REND_GLOW, 0.55)
		_draw_swoosh(REND_EDGE, 0.8, 0.6)
	elif alpha > 0.0:
		_draw_swoosh(SWOOSH, alpha)
	if alpha > 0.0:
		_draw_charged_blade(guard, tip, alpha)
	if _bolt_left > 0.0:
		_draw_bolt(tip)


## Soft glow along the sword plus short crackling arcs that jump off it.
func _draw_charged_blade(guard: Vector2, tip: Vector2, alpha: float) -> void:
	var flicker := 0.75 + 0.25 * sin(float(_tick) * 1.7)
	var a := alpha * flicker
	draw_line(guard, tip, Color(ARC.r, ARC.g, ARC.b, 0.25 * a), 7.0)
	draw_line(guard, tip, Color(ARC.r, ARC.g, ARC.b, 0.55 * a), 4.0)
	draw_line(guard, tip, Color(CORE.r, CORE.g, CORE.b, 0.95 * a), 1.5)
	var dir := (tip - guard).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var length := guard.distance_to(tip)
	for k in ARC_COUNT:
		# Each arc re-rolls every other tick; a fading charge drops arcs out.
		var seed_value := (_tick / 2) * 7 + k * 13
		if float(seed_value % 10) / 10.0 > a:
			continue
		var along := guard + dir * length * (float((seed_value * 3) % 10) / 10.0)
		var side := 1.0 if (seed_value % 2) == 0 else -1.0
		var points := PackedVector2Array([along])
		var cursor := along
		for step in 3:
			cursor += normal * side * (2.5 + float((seed_value + step * 5) % 4)) + dir * float(((seed_value + step * 3) % 5) - 2)
			points.append(cursor)
			side = -side * 0.6
		draw_polyline(points, Color(CORE.r, CORE.g, CORE.b, 0.9 * a), 1.0)
		draw_polyline(points, Color(ARC.r, ARC.g, ARC.b, 0.4 * a), 3.0)
	draw_circle(tip, 2.0 + 1.5 * a, Color(CORE.r, CORE.g, CORE.b, 0.5 * a))


## A crescent filling the path the blade just swept, brightest at its newest end.
func _draw_swoosh(colour: Color, strength: float, width: float = 1.0) -> void:
	var count := _tips.size()
	for i in range(1, count):
		var speed := _tips[i].distance_to(_tips[i - 1])
		if speed < TRAIL_MIN_SPEED:
			continue
		var age := float(i) / float(count)
		var root_a := _roots[i - 1].lerp(_tips[i - 1], 1.0 - width)
		var root_b := _roots[i].lerp(_tips[i], 1.0 - width)
		var quad := PackedVector2Array([root_a, _tips[i - 1], _tips[i], root_b])
		draw_colored_polygon(quad, Color(colour.r, colour.g, colour.b, colour.a * strength * age * 0.8))


## A forked bolt falling from the sky onto the sword tip, with a flash where it lands.
func _draw_bolt(tip: Vector2) -> void:
	var strength := _bolt_left / BOLT_SECONDS
	var top := tip + Vector2(0.0, -GameConfig.tiles(BOLT_TOP_TILES))
	var points := PackedVector2Array()
	var steps := 12
	for i in steps + 1:
		var p := top.lerp(tip, float(i) / steps)
		if i > 0 and i < steps:
			p.x += float(((_tick * 31 + i * 17) % 15) - 7)
		points.append(p)
	draw_polyline(points, Color(BOLT.r, BOLT.g, BOLT.b, 0.35 * strength), 9.0)
	draw_polyline(points, Color(BOLT.r, BOLT.g, BOLT.b, 0.7 * strength), 5.0)
	draw_polyline(points, Color(CORE.r, CORE.g, CORE.b, strength), 2.0)
	draw_circle(tip, 7.0 * strength + 3.0, Color(BOLT.r, BOLT.g, BOLT.b, 0.6 * strength))
	draw_circle(tip, 3.0 * strength + 1.0, Color(CORE.r, CORE.g, CORE.b, strength))
