class_name StormEffect
extends Node2D
## The hero's sword lightning, played from pre-rendered sprites (see LightningArt): a blue bolt falls from the
## sky onto the sword tip when the Storm strikes, the blade crackles blue while the charge lasts (fading over the
## final STORM_FADE_SECONDS), and it crackles red during Crimson Rend (the wave itself is RendWave).
## HeroBlade has the blade's position in every animation frame, so the sprites follow the real sword.

const BOLT_SECONDS: float = 0.22
const BOLT_FPS: float = 8.0 / BOLT_SECONDS
const CRACKLE_FPS: float = 18.0
## Where along the blade (guard 0 .. tip 1) each crackle sits.
const CRACKLE_AT: Array[float] = [1.0, 0.5]

const State := PlayerStateMachine.PlayerState

var _player: Player
var _visual: PlayerVisual
var _bolt: AnimatedSprite2D
var _bolt_left: float = 0.0
var _blue: Node2D
var _red: Node2D


func _ready() -> void:
	_bolt = LightningArt.sprite(&"bolt_blue", BOLT_FPS, false)
	_bolt.name = "Bolt"
	_bolt.centered = false
	_bolt.visible = false
	add_child(_bolt)
	_blue = _crackles(&"crackle_blue", "Blue")
	_red = _crackles(&"crackle_red", "Red")


func _crackles(art: StringName, node_name: String) -> Node2D:
	var group := Node2D.new()
	group.name = node_name
	for at in CRACKLE_AT:
		var sprite := LightningArt.sprite(art, CRACKLE_FPS, true)
		sprite.visible = false
		group.add_child(sprite)
	add_child(group)
	return group


func bind(player: Player) -> void:
	_player = player
	_visual = player.get_node("Visual")
	player.storm_struck.connect(_on_storm_struck)


func _on_storm_struck() -> void:
	_bolt_left = BOLT_SECONDS
	_bolt.visible = true
	_bolt.frame = 0
	_bolt.play(&"default")


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
	if _player == null:
		return
	_bolt_left = maxf(0.0, _bolt_left - delta)
	var seg := blade()
	if _bolt_left <= 0.0:
		_bolt.visible = false
	else:
		var size := Vector2(_bolt.sprite_frames.get_frame_texture(&"default", 0).get_size())
		_bolt.position = seg[1] - Vector2(size.x / 2.0, size.y)
	var raging := _player.state() == State.REND
	var alpha := 1.0 if raging else charge_alpha()
	_place_crackles(_blue, seg, alpha if not raging else 0.0)
	_place_crackles(_red, seg, alpha if raging else 0.0)


## Shows a group of crackles along the blade at `alpha`, or hides it.
func _place_crackles(group: Node2D, seg: PackedVector2Array, alpha: float) -> void:
	var on := alpha > 0.0
	for i in group.get_child_count():
		var sprite := group.get_child(i) as AnimatedSprite2D
		sprite.visible = on
		if on:
			sprite.modulate.a = alpha
			sprite.position = seg[0].lerp(seg[1], CRACKLE_AT[i])
