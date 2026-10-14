class_name StormEffect
extends Node2D
## The hero's sword lightning, drawn along the real blade (HeroBlade has its position in every
## animation frame) in hard-edged pixel style: a bold dark-outlined bolt from the sky onto the
## sword, then violet-and-cyan lightning spiralling around the blade and a thick cream crescent
## that trails each swing while charged. Crimson Rend swings leave a crescent in black, red and
## violet. Charge fades over the final STORM_FADE_SECONDS.

const BOLT_SECONDS: float = 0.22
const BOLT_TOP_TILES: float = 9.0
const BOLT_SEGMENTS: int = 7
const BOLT_SWAY: float = 7.0
## Trail only shows while the blade is really moving, in art pixels per physics tick.
const TRAIL_LENGTH: int = 30
const TRAIL_MIN_SPEED: float = 2.0
## The blade only moves when the animation changes frame; this many points fill each jump.
const TRAIL_FILL: int = 5
## How far the crescent's thick end reaches back from the tip toward the hand.
const TRAIL_WIDTH: float = 0.62
## Jumps bigger than this between ticks are an animation change, not a swing.
const TRAIL_MAX_STEP: float = 30.0

# Storm: cream crescent with a dark outline and cyan body; bold bolt; C's spiralling blade.
const STORM_LAYERS: Array[Color] = [Color8(8, 16, 60), Color8(60, 210, 255), Color8(255, 252, 210)]
const BOLT_OUTLINE := Color8(8, 16, 60)
const BOLT_BODY := Color8(60, 210, 255)
const BOLT_CORE := Color8(255, 252, 210)
const WRAP_CYAN := Color8(110, 220, 255)
const WRAP_VIOLET := Color8(190, 140, 255)
const WRAP_FORK := Color8(210, 170, 255)
const WRAP_SPARK := Color8(255, 255, 255)
const WRAP_AMPLITUDE: float = 2.8
const WRAP_TURNS: float = 5.0
const WRAP_FORKS: int = 3
# Rend: red-orange rim, violet glow, black core (outer to inner), like the claw wave.
const REND_LAYERS: Array[Color] = [Color(1.0, 0.33, 0.2), Color(0.62, 0.14, 0.55), Color(0.04, 0.0, 0.02)]
const REND_SHRINK: Array[float] = [0.0, 0.08, 0.2]
## Each crescent layer's inner edge, as a fraction of the way from its root to the tip.
const LAYER_SHRINK: Array[float] = [-0.12, 0.05, 0.6]

const State := PlayerStateMachine.PlayerState

var _player: Player
var _visual: PlayerVisual
var _bolt_left: float = 0.0
var _tick: int = 0
var _trail_anim: StringName = &""
## Recent blade tips and hands in the player's own coordinates, newest last.
var _tips: Array[Vector2] = []
var _guards: Array[Vector2] = []


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
		if _visual.animation != _trail_anim:
			# A new animation starts a new swing; do not smear across the cut.
			_trail_anim = _visual.animation
			_tips.clear()
			_guards.clear()
		var seg := blade()
		var jump := seg[1].distance_to(_tips.back()) if not _tips.is_empty() else 0.0
		if jump >= TRAIL_MIN_SPEED and jump <= TRAIL_MAX_STEP:
			var from_guard: Vector2 = _guards.back()
			var from_tip: Vector2 = _tips.back()
			for n in range(1, TRAIL_FILL + 1):
				var u := float(n) / TRAIL_FILL
				_guards.append(from_guard.lerp(seg[0], u))
				_tips.append(from_tip.lerp(seg[1], u))
		else:
			_guards.append(seg[0])
			_tips.append(seg[1])
		while _tips.size() > TRAIL_LENGTH:
			_guards.pop_front()
			_tips.pop_front()
	queue_redraw()


func _draw() -> void:
	if _player == null:
		return
	var seg := blade()
	var alpha := charge_alpha()
	if _player.state() == State.REND:
		_draw_crescent(REND_LAYERS, 1.0, REND_SHRINK)
	elif alpha > 0.0:
		_draw_crescent(STORM_LAYERS, alpha, LAYER_SHRINK)
	if alpha > 0.0:
		_draw_storm_wrap(seg[0], seg[1], alpha)
	if _bolt_left > 0.0:
		_draw_bolt(seg[1])


## Two strands, cyan and violet, spiral round the blade while jagged forks jump off it.
func _draw_storm_wrap(guard: Vector2, tip: Vector2, alpha: float) -> void:
	var along := tip - guard
	var length := maxf(along.length(), 0.001)
	var dir := along / length
	var normal := Vector2(-dir.y, dir.x)
	var twist := float(_tick) * 0.35
	for strand in 2:
		var phase := twist + PI * float(strand)
		var points := PackedVector2Array()
		for k in 31:
			var u := float(k) / 30.0
			points.append(guard + along * u + normal * WRAP_AMPLITUDE * sin(u * TAU * WRAP_TURNS / 2.0 + phase))
		draw_polyline(points, Color(WRAP_CYAN if strand == 0 else WRAP_VIOLET, alpha), 1.0)
	for k in WRAP_FORKS:
		# Forks re-roll every other tick; a fading charge drops some out.
		var h := (_tick / 2) * 11 + k * 29
		if float(h % 10) / 10.0 >= alpha:
			continue
		var root := guard + along * (0.3 + 0.7 * float((h * 3) % 10) / 10.0)
		var angle := float(h % 63) / 10.0
		var reach := 6.0 + float((h * 7) % 6)
		var fork := PackedVector2Array([root])
		var cursor := root
		for step in 4:
			cursor += Vector2.from_angle(angle + float(((h + step * 5) % 7) - 3) * 0.35) * reach / 4.0
			fork.append(cursor)
		draw_polyline(fork, Color(WRAP_FORK, alpha), 1.0)
		draw_rect(Rect2(floorf(cursor.x), floorf(cursor.y), 1, 1), Color(WRAP_SPARK, alpha))
	draw_rect(Rect2(floorf(tip.x), floorf(tip.y), 1, 1), Color(WRAP_SPARK, alpha))


## A crescent filling the path the blade just swept: thin at the old end, thick at the new,
## with lighter bands hugging the leading edge. Layers run outer to inner.
func _draw_crescent(layers: Array[Color], strength: float, shrinks: Array[float]) -> void:
	var count := _tips.size()
	for i in range(1, count):
		if _tips[i].distance_to(_tips[i - 1]) < 0.5:
			continue
		var width_a := pow(float(i - 1) / float(count - 1), 0.7) * TRAIL_WIDTH
		var width_b := pow(float(i) / float(count - 1), 0.7) * TRAIL_WIDTH
		var root_a := _tips[i - 1].lerp(_guards[i - 1], width_a)
		var root_b := _tips[i].lerp(_guards[i], width_b)
		for layer in layers.size():
			var shrink: float = shrinks[layer]
			_draw_quad(root_a.lerp(_tips[i - 1], shrink), _tips[i - 1], _tips[i], root_b.lerp(_tips[i], shrink), Color(layers[layer], strength))


## Two triangles rather than a polygon, so thin or twisted pieces never fail to triangulate.
func _draw_quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, colour: Color) -> void:
	var colours := PackedColorArray([colour, colour, colour])
	draw_primitive(PackedVector2Array([a, b, c]), colours, PackedVector2Array())
	draw_primitive(PackedVector2Array([a, c, d]), colours, PackedVector2Array())


## A chunky dark-outlined bolt falling from the sky onto the sword tip.
func _draw_bolt(tip: Vector2) -> void:
	var strength := clampf(_bolt_left / BOLT_SECONDS * 1.5, 0.0, 1.0)
	var top := tip + Vector2(-7.0, -GameConfig.tiles(BOLT_TOP_TILES))
	var points := PackedVector2Array()
	for i in BOLT_SEGMENTS + 1:
		var p := top.lerp(tip, float(i) / BOLT_SEGMENTS)
		if i > 0 and i < BOLT_SEGMENTS:
			var h := (_tick / 2) * 31 + i * 17
			p.x += (fposmod(sin(float(h) * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0) * BOLT_SWAY
		points.append(p)
	draw_polyline(points, Color(BOLT_OUTLINE, strength), 7.0)
	draw_polyline(points, Color(BOLT_BODY, strength), 5.0)
	draw_polyline(points, Color(BOLT_CORE, strength), 2.0)
	draw_circle(tip, 5.0, Color(BOLT_OUTLINE, strength))
	draw_circle(tip, 3.5, Color(BOLT_BODY, strength))
	draw_circle(tip, 1.8, Color(BOLT_CORE, strength))
