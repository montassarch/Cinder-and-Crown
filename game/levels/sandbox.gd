class_name Sandbox
extends Node2D
## The test room: flat arena, a few platforms, a player, and a menu to spawn enemies
## and swap weapons. Geometry is expressed in tiles and derived from the player's
## jump height so it stays reachable when the tuning changes.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const ENEMY_SCENE := preload("res://src/enemies/enemy.tscn")

const ARENA_WIDTH_TILES: float = 48.0
const GROUND_TOP_TILES: float = 12.0
const GROUND_THICKNESS_TILES: float = 3.0
const WALL_HEIGHT_TILES: float = 30.0
const PLATFORM_STEP_TILES: float = Player.JUMP_HEIGHT * 0.8
const PLATFORM_THICKNESS_TILES: float = 0.5
## The camera runs this far past each end of the level (half a screen), and the end walls are this thick, so the
## hero can stand mid-screen at the ends instead of hiding under the stick or the thumb cluster.
const CAMERA_MARGIN_TILES: float = 12.0
const SPAWN_DISTANCE_TILES: float = 8.0
const GROUND_SPAWN_HEIGHT_TILES: float = 2.0
const AIR_SPAWN_HEIGHT_TILES: float = 5.0
const RESPAWN_DELAY: float = 2.0
const SANDBOX_PATH := "res://levels/sandbox.tscn"
const GENERATED_PATH := "res://levels/generated_level.tscn"

const GROUND_COLOR := Color(0.22, 0.2, 0.26)
const PLATFORM_COLOR := Color(0.35, 0.3, 0.4)
const BACKGROUND_COLOR := Color(0.09, 0.08, 0.11)
const GROUND_TEXTURE := preload("res://art/cathedral/ground_tile.png")
const LEDGE_TEXTURE := preload("res://art/cathedral/ledge_tile.png")

var player: Player

@onready var _camera: Camera2D = $Camera
@onready var _hud: Hud = $Hud
@onready var _menu: SandboxMenu = $Menu
@onready var _touch: Node = $TouchControls
@onready var _overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	var backdrop := Backdrop.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	move_child(backdrop, 0)
	_build_arena()

	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = spawn_point()
	player.died.connect(_on_player_died)

	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 12.0  # tight follow: a lagging camera makes the run feel slow
	_apply_camera_limits()
	_camera.global_position = player.global_position

	_hud.bind(player, enemy_count)
	_touch.bind(player)
	_menu.spawn_requested.connect(spawn_enemy)
	_menu.clear_requested.connect(clear_enemies)
	_menu.weapon_assigned.connect(assign_weapon)
	_menu.reset_requested.connect(reset_player)
	_menu.debug_toggled.connect(func(on: bool) -> void: _overlay.enabled = on)
	_menu.opened.connect(_on_menu_opened)
	_menu.scene_requested.connect(_switch_scene)
	var switch := _scene_switch()
	_menu.set_scene_switch(switch[0], switch[1])
	_menu.sync_weapons(player)


func _process(_delta: float) -> void:
	_camera.global_position = player.global_position


## Hooks: a level that builds its own geometry overrides these.
func spawn_point() -> Vector2:
	return GameConfig.tiles_v(4.0, GROUND_TOP_TILES - 1.5)


func arena_width_tiles() -> float:
	return ARENA_WIDTH_TILES


func arena_height_tiles() -> float:
	return float(GameConfig.BASE_HEIGHT) / GameConfig.TILE_SIZE


## [button label, scene path] for the menu's "go somewhere else" button.
func _scene_switch() -> Array:
	return ["Generated level", GENERATED_PATH]


func platform_rects_tiles() -> Array[Rect2]:
	var ground := GROUND_TOP_TILES
	return [
		Rect2(10.0, ground - PLATFORM_STEP_TILES, 6.0, PLATFORM_THICKNESS_TILES),
		Rect2(18.0, ground - 2.0 * PLATFORM_STEP_TILES, 6.0, PLATFORM_THICKNESS_TILES),
		Rect2(30.0, ground - PLATFORM_STEP_TILES, 8.0, PLATFORM_THICKNESS_TILES),
	]


func spawn_enemy_at(data: EnemyData, at: Vector2) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.configure(data)
	enemy.target = player
	enemy.global_position = at
	return enemy


func spawn_enemy(data: EnemyData) -> Enemy:
	var toward_center := 1.0 if player.global_position.x < GameConfig.tiles(arena_width_tiles() / 2.0) else -1.0
	var x := player.global_position.x + toward_center * GameConfig.tiles(SPAWN_DISTANCE_TILES)
	x = clampf(x, GameConfig.tiles(2.0), GameConfig.tiles(arena_width_tiles() - 2.0))
	var height := AIR_SPAWN_HEIGHT_TILES if data.behaviour == EnemyData.Behaviour.FLYER else GROUND_SPAWN_HEIGHT_TILES
	return spawn_enemy_at(data, Vector2(x, GameConfig.tiles(GROUND_TOP_TILES - height)))


func clear_enemies() -> void:
	for child in get_children():
		if child is Enemy or child.is_in_group(Enemy.ATTACK_GROUP):  # their shots and waves go too
			child.queue_free()


func enemy_count() -> int:
	var count := 0
	for child in get_children():
		if child is Enemy and not child.is_dead() and not child.is_queued_for_deletion():
			count += 1
	return count


func assign_weapon(slot: int, data: WeaponData) -> void:
	player.set_weapon(slot, data)


## A fresh run: boons are dropped, so this is not for moving between levels.
func reset_player() -> void:
	player.start_new_run()
	player.reset(spawn_point())


func _on_player_died() -> void:
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(reset_player)


func _apply_camera_limits() -> void:
	_camera.limit_left = int(-GameConfig.tiles(CAMERA_MARGIN_TILES))
	_camera.limit_top = 0
	_camera.limit_right = int(GameConfig.tiles(arena_width_tiles() + CAMERA_MARGIN_TILES))
	_camera.limit_bottom = int(GameConfig.tiles(arena_height_tiles()))


func _switch_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func _on_menu_opened(is_open: bool) -> void:
	if is_open:
		_touch.release_all()
		_menu.sync_weapons(player)


func _build_arena() -> void:
	_add_block(Rect2(0.0, GROUND_TOP_TILES, ARENA_WIDTH_TILES, GROUND_THICKNESS_TILES), GROUND_COLOR, false)
	var wall_top := GROUND_TOP_TILES - WALL_HEIGHT_TILES
	var wall_height := WALL_HEIGHT_TILES + GROUND_THICKNESS_TILES
	_add_block(Rect2(-CAMERA_MARGIN_TILES, wall_top, CAMERA_MARGIN_TILES, wall_height), GROUND_COLOR, false)
	_add_block(Rect2(ARENA_WIDTH_TILES, wall_top, CAMERA_MARGIN_TILES, wall_height), GROUND_COLOR, false)
	for rect in platform_rects_tiles():
		_add_block(rect, PLATFORM_COLOR, true)


func _add_block(rect_tiles: Rect2, color: Color, one_way: bool, parent: Node = self) -> void:
	var size := GameConfig.tiles_v(rect_tiles.size.x, rect_tiles.size.y)
	var body := StaticBody2D.new()
	body.position = GameConfig.tiles_v(rect_tiles.position.x, rect_tiles.position.y) + size / 2.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.one_way_collision = one_way
	body.add_child(shape)
	var visual := TextureRect.new()
	visual.texture = LEDGE_TEXTURE if one_way else GROUND_TEXTURE
	visual.stretch_mode = TextureRect.STRETCH_TILE
	visual.size = size
	visual.position = -size / 2.0
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(visual)
	parent.add_child(body)
