class_name EnemyVisual
extends AnimatedSprite2D
## An enemy drawn from its pre-rendered sprites (art/enemies/<id>/<Anim>_<n>.png, made in Blender by
## tools/art/enemy_render.py). The art faces right; flip_h turns it. Which animation plays follows the enemy's
## state, and wind-up / strike / recovery are stretched to last exactly as long as the gameplay moment.

const ART_DIR := "res://art/enemies"
const BASE_FPS: float = 12.0
## A hit turns the sprite white for this long.
const FLASH_SECONDS: float = 0.09
const FLASH_SHADER := preload("res://src/enemies/hit_flash.gdshader")
## Where the feet sit across the frame (40%) and how far above the bottom edge (2 px), set by the art tool.
const FEET_X_FRACTION: float = 0.40
const FEET_MARGIN: float = 2.0
const REQUIRED_ANIMS: Array[StringName] = [&"Idle", &"Move", &"Windup", &"Strike", &"Recover", &"Stun", &"Death"]
## These play across the gameplay time rather than at their own speed.
const FITTED: Array[StringName] = [&"Windup", &"Strike", &"Recover"]

static var _cache: Dictionary = {}

var art_id: String = ""
var _feet_y: float = 0.0
var _flash_until_msec: int = 0
var _flash_material: ShaderMaterial


static func has_art(id: String) -> bool:
	return EnemyArtData.ENTRIES.has(id)


static func eye_colour(id: String) -> Color:
	return EnemyArtData.ENTRIES[id]["eye"]


static func frames_for(id: String) -> SpriteFrames:
	if _cache.has(id):
		return _cache[id]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var anims: Dictionary = EnemyArtData.ENTRIES[id]["anims"]
	for anim in anims:
		var key := StringName(anim)
		frames.add_animation(key)
		frames.set_animation_speed(key, BASE_FPS)
		frames.set_animation_loop(key, anim in ["Idle", "Move", "Dash"])
		for i in int(anims[anim]):
			frames.add_frame(key, load("%s/%s/%s_%d.png" % [ART_DIR, id, anim, i]))
	_cache[id] = frames
	return frames


static func animation_for(state: Enemy.State, moving: bool, kind: EnemyMove.Kind) -> StringName:
	match state:
		Enemy.State.MOVE: return &"Move" if moving else &"Idle"
		Enemy.State.TELEGRAPH: return &"Windup"
		Enemy.State.STRIKE: return &"Dash" if kind == EnemyMove.Kind.DASH else &"Strike"
		Enemy.State.RECOVER: return &"Recover"
		Enemy.State.STUNNED: return &"Stun"
		Enemy.State.DEAD: return &"Death"
	return &"Idle"


## feet_y: where the enemy's feet are, in the enemy's own coordinates.
func setup(id: String, feet_y: float) -> void:
	art_id = id
	_feet_y = feet_y
	sprite_frames = frames_for(id)
	centered = false
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = FLASH_SHADER
	_flash_material.set_shader_parameter(&"amount", 0.0)
	material = _flash_material
	play(&"Idle")
	_place(false)


## Highest opaque row of the idle pose, in the enemy's own coordinates (where a tell ring should clear).
func head_top() -> float:
	var size := _canvas()
	var img := sprite_frames.get_frame_texture(&"Idle", 0).get_image()
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				return _feet_y - (size.y - FEET_MARGIN) + float(y)
	return _feet_y


func show_state(state: Enemy.State, facing: float, moving: bool, kind: EnemyMove.Kind, windup: float, strike: float, recovery: float, tint: Color) -> void:
	var anim := animation_for(state, moving, kind)
	if anim == &"Dash" and not sprite_frames.has_animation(&"Dash"):
		anim = &"Strike"
	if anim != animation:
		var seconds := {&"Windup": windup, &"Strike": strike, &"Recover": recovery}.get(anim, 0.0) as float
		if anim in FITTED and seconds > 0.0:
			speed_scale = float(sprite_frames.get_frame_count(anim)) / seconds / BASE_FPS
		else:
			speed_scale = 1.0
		play(anim)
	flip_h = facing < 0.0
	_place(flip_h)
	modulate = tint


## Turns the sprite white for a moment (an enemy has just been hit).
func flash() -> void:
	_flash_until_msec = Time.get_ticks_msec() + int(FLASH_SECONDS * 1000.0)
	_flash_material.set_shader_parameter(&"amount", 1.0)


func _process(_delta: float) -> void:
	if _flash_until_msec > 0 and Time.get_ticks_msec() >= _flash_until_msec:
		_flash_until_msec = 0
		_flash_material.set_shader_parameter(&"amount", 0.0)


## The enemy is gone but its body is not: play the death, then the enemy frees itself.
func play_death() -> void:
	speed_scale = 1.0
	play(&"Death")


func _canvas() -> Vector2i:
	return EnemyArtData.ENTRIES[art_id]["canvas"]


func _place(flipped: bool) -> void:
	var size := _canvas()
	var feet_x := float(size.x) * FEET_X_FRACTION
	position = Vector2((feet_x - size.x) if flipped else -feet_x, _feet_y - (float(size.y) - FEET_MARGIN))
