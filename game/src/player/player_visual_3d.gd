class_name PlayerVisual3D
extends Sprite2D
## SPIKE: the hero as a live 3D model, rendered every frame into a tiny viewport
## with flat toon shading and a 1px outline, so it reads as pixel art (the Dead Cells
## trick, done in real time). Animations blend into each other and turning is a real
## 3D turn rather than a mirror flip.

const MODEL := preload("res://art/hero3d/hero_model.scn")
## Viewport size and where the feet sit in it, in game pixels.
const VIEW := Vector2i(224, 184)
const FEET := Vector2(112.0, 172.0)
## How many game pixels one metre of the model covers (sets the hero's on-screen size).
const PX_PER_M: float = 48.0
const BLEND_SECONDS: float = 0.08
const TURN_SPEED: float = 22.0
const HURT_TINT := Color(1.0, 0.55, 0.55)
const BODY_COLOR := Color(0.19, 0.18, 0.23)
const TRIM_COLOR := Color(0.42, 0.28, 0.2)
const BLADE_COLOR := Color(0.62, 0.6, 0.68)
const OUTLINE_COLOR := Color(0.05, 0.035, 0.047)

## Per clip: the slice to play [start, end] in clip seconds, and whether that slice is
## stretched to fit the gameplay action (attacks, roll) or plays at a fixed speed.
const CLIPS := {
	&"Sword_Idle": {"start": 0.0, "end": -1.0, "fit": false, "speed": 1.0},
	&"Sprint": {"start": 0.0, "end": -1.0, "fit": false, "speed": 1.1},
	&"Jump_Start": {"start": 0.35, "end": -1.0, "fit": false, "speed": 1.6},
	&"Jump": {"start": 0.0, "end": -1.0, "fit": false, "speed": 1.0},
	&"Roll": {"start": 0.0, "end": 1.0, "fit": true, "speed": 1.0},
	&"Hit_Chest": {"start": 0.0, "end": -1.0, "fit": false, "speed": 1.2},
	&"Sword_Regular_A": {"start": 0.0, "end": -1.0, "fit": true, "speed": 1.0},
	&"Sword_Regular_B": {"start": 0.0, "end": -1.0, "fit": true, "speed": 1.0},
	&"Sword_Regular_C": {"start": 0.0, "end": 1.2, "fit": true, "speed": 1.0},
}
const COMBO_CLIPS: Array[StringName] = [&"Sword_Regular_A", &"Sword_Regular_B", &"Sword_Regular_C"]

const State := PlayerStateMachine.PlayerState

var _viewport: SubViewport
var _model: Node3D
var _anim: AnimationPlayer
var _clip: StringName = &""
var _facing: float = 1.0


func _ready() -> void:
	centered = false
	_build_stage()
	texture = _viewport.get_texture()
	material = _outline_material()
	_play(&"Sword_Idle", 0.0)


func _process(delta: float) -> void:
	var target := PI / 2.0 if _facing > 0.0 else -PI / 2.0
	_model.rotation.y = lerp_angle(_model.rotation.y, target, minf(1.0, TURN_SPEED * delta))


static func clip_for(state: State, combo_step: int) -> StringName:
	match state:
		State.RUN: return &"Sprint"
		State.JUMP: return &"Jump_Start"
		State.FALL: return &"Jump"
		State.ROLL: return &"Roll"
		State.ATTACK: return COMBO_CLIPS[combo_step % COMBO_CLIPS.size()]
		State.HURT: return &"Hit_Chest"
		_: return &"Sword_Idle"


## feet_y: where the player's feet are relative to the player's origin.
## action_seconds: how long the current attack or roll lasts, so its clip fits exactly.
func show_state(state: State, facing: float, feet_y: float, action_seconds: float, combo_step: int = 0) -> void:
	var clip := clip_for(state, combo_step)
	if clip != _clip:
		_play(clip, action_seconds)
	if facing != 0.0:
		_facing = signf(facing)
	position = Vector2(-FEET.x, feet_y - FEET.y).round()
	modulate = HURT_TINT if state == State.HURT else Color.WHITE


func current_clip() -> StringName:
	return _clip


func facing() -> float:
	return _facing


func has_clip(clip: StringName) -> bool:
	return _anim.has_animation(clip)


func _play(clip: StringName, action_seconds: float) -> void:
	_clip = clip
	var spec: Dictionary = CLIPS[clip]
	var length := _anim.get_animation(clip).length
	var end: float = spec["end"] if spec["end"] > 0.0 else length
	var speed: float = spec["speed"]
	if spec["fit"] and action_seconds > 0.0:
		speed = (end - spec["start"]) / action_seconds
	_anim.play(clip, BLEND_SECONDS, speed)
	if spec["start"] > 0.0:
		_anim.seek(spec["start"], true)


func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.size = VIEW
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.5, 0.6)
	env.environment.ambient_light_energy = 0.6
	_viewport.add_child(env)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW.y / PX_PER_M
	camera.position = Vector3(0.0, (FEET.y - VIEW.y / 2.0) / PX_PER_M, 6.0)
	_viewport.add_child(camera)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, -35.0, 0.0)
	sun.light_energy = 1.3
	_viewport.add_child(sun)

	_model = MODEL.instantiate()
	_model.rotation.y = PI / 2.0
	_viewport.add_child(_model)
	_anim = _model.find_children("*", "AnimationPlayer", true, false)[0]

	var toon := Shader.new()
	toon.code = "shader_type spatial;\nrender_mode diffuse_toon, specular_disabled;\nuniform vec4 albedo : source_color;\nvoid fragment() { ALBEDO = albedo.rgb; }\n"
	for mesh_instance: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh_instance.mesh.get_surface_count():
			mesh_instance.set_surface_override_material(surface, _toon(toon, BODY_COLOR if surface == 0 else TRIM_COLOR))

	# Stand-in greatsword in the right hand.
	var skeleton: Skeleton3D = _model.find_children("*", "Skeleton3D", true, false)[0]
	var hand := BoneAttachment3D.new()
	hand.bone_name = "hand_r"
	skeleton.add_child(hand)
	var blade := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.09, 1.25, 0.02)
	blade.mesh = box
	blade.material_override = _toon(toon, BLADE_COLOR)
	blade.position = Vector3(0.0, 0.68, 0.0)
	hand.add_child(blade)


func _toon(shader: Shader, color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("albedo", color)
	return mat


func _outline_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform vec4 outline_color : source_color;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float n = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		COLOR = n > 0.5 ? outline_color : vec4(0.0);
	} else {
		COLOR = vec4(c.rgb, 1.0) * COLOR;
	}
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("outline_color", OUTLINE_COLOR)
	return mat
