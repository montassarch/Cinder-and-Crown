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
const SPAWN_DISTANCE_TILES: float = 8.0
const GROUND_SPAWN_HEIGHT_TILES: float = 2.0
const AIR_SPAWN_HEIGHT_TILES: float = 5.0
const RESPAWN_DELAY: float = 2.0

const GROUND_COLOR := Color(0.22, 0.2, 0.26)
const PLATFORM_COLOR := Color(0.35, 0.3, 0.4)
const BACKGROUND_COLOR := Color(0.09, 0.08, 0.11)

var player: Player

@onready var _camera: Camera2D = $Camera
@onready var _hud: Hud = $Hud
@onready var _menu: SandboxMenu = $Menu
@onready var _touch: Node = $TouchControls
@onready var _overlay: DebugOverlay = $DebugOverlay


func _ready() -> void:
	RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
	_build_arena()

	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = spawn_point()
	player.died.connect(_on_player_died)

	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(GameConfig.tiles(ARENA_WIDTH_TILES))
	_camera.limit_bottom = GameConfig.BASE_HEIGHT
	_camera.position_smoothing_enabled = true
	_camera.global_position = player.global_position

	_hud.bind(player, enemy_count)
	_menu.spawn_requested.connect(spawn_enemy)
	_menu.clear_requested.connect(clear_enemies)
	_menu.weapon_assigned.connect(assign_weapon)
	_menu.reset_requested.connect(reset_player)
	_menu.debug_toggled.connect(func(on: bool) -> void: _overlay.enabled = on)
	_menu.opened.connect(_on_menu_opened)
	_menu.sync_weapons(player)


func _process(_delta: float) -> void:
	_camera.global_position = player.global_position


func spawn_point() -> Vector2:
	return GameConfig.tiles_v(4.0, GROUND_TOP_TILES - 1.5)


func platform_rects_tiles() -> Array[Rect2]:
	var ground := GROUND_TOP_TILES
	return [
		Rect2(10.0, ground - PLATFORM_STEP_TILES, 6.0, PLATFORM_THICKNESS_TILES),
		Rect2(18.0, ground - 2.0 * PLATFORM_STEP_TILES, 6.0, PLATFORM_THICKNESS_TILES),
		Rect2(30.0, ground - PLATFORM_STEP_TILES, 8.0, PLATFORM_THICKNESS_TILES),
	]


func spawn_enemy(data: EnemyData) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.configure(data)
	enemy.target = player
	var toward_center := 1.0 if player.global_position.x < GameConfig.tiles(ARENA_WIDTH_TILES / 2.0) else -1.0
	var x := player.global_position.x + toward_center * GameConfig.tiles(SPAWN_DISTANCE_TILES)
	x = clampf(x, GameConfig.tiles(2.0), GameConfig.tiles(ARENA_WIDTH_TILES - 2.0))
	var height := AIR_SPAWN_HEIGHT_TILES if data.behaviour == EnemyData.Behaviour.FLYER else GROUND_SPAWN_HEIGHT_TILES
	enemy.global_position = Vector2(x, GameConfig.tiles(GROUND_TOP_TILES - height))
	return enemy


func clear_enemies() -> void:
	for child in get_children():
		if child is Enemy:
			child.queue_free()


func enemy_count() -> int:
	var count := 0
	for child in get_children():
		if child is Enemy and not child.is_dead() and not child.is_queued_for_deletion():
			count += 1
	return count


func assign_weapon(slot: int, data: WeaponData) -> void:
	player.set_weapon(slot, data)


func reset_player() -> void:
	player.reset(spawn_point())


func _on_player_died() -> void:
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(reset_player)


func _on_menu_opened(is_open: bool) -> void:
	if is_open:
		_touch.release_all()
		_menu.sync_weapons(player)


func _build_arena() -> void:
	_add_block(Rect2(0.0, GROUND_TOP_TILES, ARENA_WIDTH_TILES, GROUND_THICKNESS_TILES), GROUND_COLOR, false)
	var wall_top := GROUND_TOP_TILES - WALL_HEIGHT_TILES
	var wall_height := WALL_HEIGHT_TILES + GROUND_THICKNESS_TILES
	_add_block(Rect2(-1.0, wall_top, 1.0, wall_height), GROUND_COLOR, false)
	_add_block(Rect2(ARENA_WIDTH_TILES, wall_top, 1.0, wall_height), GROUND_COLOR, false)
	for rect in platform_rects_tiles():
		_add_block(rect, PLATFORM_COLOR, true)


func _add_block(rect_tiles: Rect2, color: Color, one_way: bool) -> void:
	var size := GameConfig.tiles_v(rect_tiles.size.x, rect_tiles.size.y)
	var body := StaticBody2D.new()
	body.position = GameConfig.tiles_v(rect_tiles.position.x, rect_tiles.position.y) + size / 2.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.one_way_collision = one_way
	body.add_child(shape)
	var visual := ColorRect.new()
	visual.size = size
	visual.position = -size / 2.0
	visual.color = color
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(visual)
	add_child(body)
