extends Node2D

## The test room: a flat floor, a few platforms, and a menu for spawning
## things at them.
##
## This is a workbench, not a level. Its job is to let a human answer the
## questions no test can: does the jump arc feel right, does the roll go far
## enough, does a hit land with weight, can you read a wind-up in time.

## Where enemies appear, in tiles from the player.
const SPAWN_OFFSET_TILES: float = 6.0

## The room, in tile space. 48x13.5 tiles is the 384x216 viewport at
## TILE_SIZE 16, widened to 48 so the camera has somewhere to travel.
const ROOM_WIDTH_TILES: float = 48.0
const FLOOR_TOP_TILES: float = 11.0
const FLOOR_THICKNESS_TILES: float = 2.0
const WALL_THICKNESS_TILES: float = 1.0
const PLATFORM_THICKNESS_TILES: float = 0.5

## A rise the player can clear from a standing jump, derived from their
## jump height rather than guessed. The plan requires platform heights be
## derived; at 0.78 of a 3.2-tile jump this leaves real headroom for the
## 2-tile-tall player rather than demanding a pixel-perfect apex.
const REACHABLE_RISE_TILES: float = Player.JUMP_HEIGHT_TILES * 0.78

const FLOOR_COLOUR := Color(0.18, 0.16, 0.2)
const PLATFORM_COLOUR := Color(0.26, 0.22, 0.28)

@onready var _world: StaticBody2D = %World
@onready var _visuals: Node2D = %Visuals

@onready var player: Player = %Player
@onready var enemies: Node2D = %Enemies

var _spawn_side: float = 1.0


## Platform rectangles in tile space, each stacked a reachable rise above
## the surface below it. Returned from a function rather than stored as a
## const so the heights stay derived from the player's jump.
static func platform_rects() -> Array[Rect2]:
	var first_rise := FLOOR_TOP_TILES - REACHABLE_RISE_TILES
	var second_rise := first_rise - REACHABLE_RISE_TILES
	return [
		Rect2(13.0, first_rise, 6.0, PLATFORM_THICKNESS_TILES),
		Rect2(25.0, second_rise, 5.0, PLATFORM_THICKNESS_TILES),
		Rect2(36.0, first_rise, 7.0, PLATFORM_THICKNESS_TILES),
	]


func _build_world() -> void:
	WorldBuilder.add_solid(
		_world, _visuals,
		Rect2(0.0, FLOOR_TOP_TILES, ROOM_WIDTH_TILES, FLOOR_THICKNESS_TILES),
		FLOOR_COLOUR
	)
	# Walls sit just outside the room so the player cannot run off either end.
	for wall_x: float in [-WALL_THICKNESS_TILES, ROOM_WIDTH_TILES]:
		WorldBuilder.add_solid(
			_world, _visuals,
			Rect2(wall_x, 0.0, WALL_THICKNESS_TILES, FLOOR_TOP_TILES + FLOOR_THICKNESS_TILES),
			FLOOR_COLOUR
		)
	for platform: Rect2 in platform_rects():
		WorldBuilder.add_solid(_world, _visuals, platform, PLATFORM_COLOUR)


func _ready() -> void:
	_build_world()

	var spawn := %PlayerSpawn as Marker2D
	spawn.position = GameConfig.tiles_v(4.0, FLOOR_TOP_TILES - 1.0)
	player.global_position = spawn.global_position

	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.limit_right = int(GameConfig.tiles(ROOM_WIDTH_TILES))
		camera.limit_bottom = int(
			GameConfig.tiles(FLOOR_TOP_TILES + FLOOR_THICKNESS_TILES)
		)

	player.died.connect(_on_player_died)
	# Children wire upward only on request: a child's _ready runs before
	# the parent's, so they cannot safely reach for sandbox.player themselves.
	(%HUD as CanvasLayer).bind(self)
	(%SandboxMenu as CanvasLayer).bind(self)


## Spawns one enemy of the given type, alternating sides so repeated
## spawns do not stack on top of each other.
func spawn_enemy(data: EnemyData) -> Enemy:
	if data == null:
		return null
	var enemy: Enemy = (load("res://src/enemies/enemy.tscn") as PackedScene).instantiate()
	enemies.add_child(enemy)
	enemy.configure(data)
	enemy.target = player
	enemy.global_position = player.global_position + Vector2(
		GameConfig.tiles(SPAWN_OFFSET_TILES) * _spawn_side,
		-GameConfig.tiles(1.0)
	)
	_spawn_side *= -1.0
	return enemy


func clear_enemies() -> void:
	for child: Node in enemies.get_children():
		child.queue_free()


func enemy_count() -> int:
	var alive := 0
	for child: Node in enemies.get_children():
		if child is Enemy and (child as Enemy).health.is_alive():
			alive += 1
	return alive


## Puts the player back at full health in their starting position. The
## sandbox never ends a run -- dying here just resets.
func reset_player() -> void:
	player.health.configure(Player.MAX_HEALTH)
	player.global_position = (%PlayerSpawn as Marker2D).global_position
	player.velocity = Vector2.ZERO


func _on_player_died() -> void:
	reset_player()
