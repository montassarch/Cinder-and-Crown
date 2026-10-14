class_name StormEffect
extends Node2D
## Storm Blade's lightning: a blue bolt from the sky onto the raised sword, then crackling
## arcs along the blade for as long as it is charged (fading over the final seconds).

const BOLT_SECONDS: float = 0.18
const BOLT_TOP_TILES: float = 9.0
## Where the blade sits relative to the player's origin, in tiles (x mirrors with facing).
const BLADE_TILES := Vector2(0.9, -1.1)
const BLADE_LENGTH_TILES: float = 1.4
const BOLT := Color(0.55, 0.85, 1.0)
const CORE := Color(0.95, 0.99, 1.0)
const ARC := Color(0.4, 0.75, 1.0)

var _player: Player
var _bolt_left: float = 0.0
var _tick: int = 0


func bind(player: Player) -> void:
	_player = player
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


func _physics_process(delta: float) -> void:
	_bolt_left = maxf(0.0, _bolt_left - delta)
	_tick += 1
	queue_redraw()


func _blade_base() -> Vector2:
	return Vector2(_facing() * GameConfig.tiles(BLADE_TILES.x), GameConfig.tiles(BLADE_TILES.y))


func _facing() -> float:
	return _player.facing() if _player != null else 1.0


func _draw() -> void:
	if _player == null:
		return
	var base := _blade_base()
	var tip := base + Vector2(_facing() * GameConfig.tiles(0.3), -GameConfig.tiles(BLADE_LENGTH_TILES))
	if _bolt_left > 0.0:
		var strength := _bolt_left / BOLT_SECONDS
		var pts := PackedVector2Array()
		var top := tip + Vector2(0.0, -GameConfig.tiles(BOLT_TOP_TILES))
		var steps := 9
		for i in steps + 1:
			var t := float(i) / steps
			var p := top.lerp(tip, t)
			if i > 0 and i < steps:
				p.x += float(((_tick * 31 + i * 17) % 13) - 6)
			pts.append(p)
		draw_polyline(pts, Color(BOLT.r, BOLT.g, BOLT.b, 0.5 * strength), 5.0)
		draw_polyline(pts, Color(CORE.r, CORE.g, CORE.b, strength), 2.0)
	var alpha := charge_alpha()
	if alpha > 0.0:
		# Short arcs flicker off the blade; a fading charge flickers less and dimmer.
		for k in 4:
			if (_tick + k * 3) % 4 == 0 and alpha < 1.0 and randf() > alpha:
				continue
			var along := base.lerp(tip, (float(k) + 0.5) / 4.0)
			var jag := Vector2(float(((_tick * 7 + k * 11) % 9) - 4), float(((_tick * 5 + k * 3) % 7) - 3))
			var colour := Color(ARC.r, ARC.g, ARC.b, 0.35 + 0.65 * alpha)
			draw_line(along, along + jag + Vector2(_facing() * 4.0, -3.0), colour, 1.0)
			draw_line(along, along - jag, colour, 1.0)
		draw_line(base, tip, Color(CORE.r, CORE.g, CORE.b, 0.6 * alpha), 1.0)
