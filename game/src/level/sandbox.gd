extends Node2D

## The test room: a flat floor, a few platforms, and a menu for spawning
## things at them.
##
## This is a workbench, not a level. Its job is to let a human answer the
## questions no test can: does the jump arc feel right, does the roll go far
## enough, does a hit land with weight, can you read a wind-up in time.

## Where enemies appear, in tiles from the player.
const SPAWN_OFFSET_TILES: float = 6.0

@onready var player: Player = %Player
@onready var enemies: Node2D = %Enemies

var _spawn_side: float = 1.0


func _ready() -> void:
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
