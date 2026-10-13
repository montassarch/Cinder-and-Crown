extends Node2D

## A generated level: rooms laid end to end from a seed.
##
## The sandbox is for tuning one thing at a time; this is for seeing the
## pieces in sequence. Both stay reachable -- the sandbox remains the main
## scene, and this is launched from its menu.

## 0 means "pick a seed at random and report it". Any other value rebuilds
## that exact level, which is how a bad layout gets looked at twice.
@export var level_seed: int = 0

@export var room_count: int = 5

# Rooms and enemy types are discovered by scanning data/, never listed
# here. A fixed list meant a new room could not reach the generator at all
# and a new enemy appeared in the sandbox but never in a generated level --
# the same file behaving differently in two places.

## Emitted when the player reaches the exit, and when they die, carrying
## the seed so a layout worth revisiting can be rebuilt.
signal run_completed(seed_value: int)
signal run_died(seed_value: int)

var used_seed: int = 0
var rooms: Array[RoomData] = []

## World x of the exit marker. 0 means "not placed yet or already taken".
var _exit_x: float = 0.0

@onready var player: Player = %Player
@onready var _rooms_parent: Node2D = %Rooms
@onready var enemies: Node2D = %Enemies


## Horizontal offset in PIXELS for each room, laid end to end.
##
## Static and pure so the placement maths is checkable without building a
## scene -- an off-by-one here shows up as rooms overlapping or a gap the
## player falls through, both tedious to diagnose by eye.
static func room_offsets(level: Array[RoomData]) -> Array[float]:
	var offsets: Array[float] = []
	var cursor := 0.0
	for room: RoomData in level:
		offsets.append(cursor)
		cursor += GameConfig.tiles(float(room.size_tiles.x))
	return offsets


static func total_width(level: Array[RoomData]) -> float:
	var width := 0.0
	for room: RoomData in level:
		width += GameConfig.tiles(float(room.size_tiles.x))
	return width


func _ready() -> void:
	used_seed = level_seed if level_seed != 0 else randi()

	rooms = LevelGenerator.generate(Content.rooms(), room_count, used_seed)
	if rooms.is_empty():
		push_warning("Room pool cannot build a level; nothing placed.")
		return

	_place_rooms()
	_populate_enemies()
	# Same contract the sandbox honours: the parent wires the HUD, because a
	# child's _ready runs first and cannot reach up for `player` safely.
	(%HUD as CanvasLayer).bind(self)
	player.died.connect(_on_player_died)
	print("Cinder & Crown — level seed %d, %d rooms" % [used_seed, rooms.size()])


## Part of the interface the HUD expects of whatever hosts it.
func enemy_count() -> int:
	var alive := 0
	for child: Node in enemies.get_children():
		if child is Enemy and (child as Enemy).health.is_alive():
			alive += 1
	return alive


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_tree().change_scene_to_file("res://levels/sandbox.tscn")


func _physics_process(_delta: float) -> void:
	# Reaching the exit is what makes this a level rather than a corridor.
	# The ExitPoint marker existed and nothing read it, so a player who
	# fought through five rooms arrived at the Iron Gate and stood there.
	if _exit_x > 0.0 and player.global_position.x >= _exit_x:
		_exit_x = 0.0
		run_completed.emit(used_seed)
		restart(0)


## Rebuilds the level. A seed of 0 picks a new one.
##
## Used both by the exit and by death, so neither leaves the player stuck:
## without this, dying in a generated level dropped them to 0 HP and then
## handed control back permanently immortal, since Health refuses damage
## to something already dead.
func restart(new_seed: int) -> void:
	level_seed = new_seed
	get_tree().reload_current_scene()


func _on_player_died() -> void:
	run_died.emit(used_seed)
	restart(used_seed)


func _place_rooms() -> void:
	var offsets := room_offsets(rooms)
	for i: int in range(rooms.size()):
		var instance := rooms[i].scene.instantiate() as Node2D
		instance.position = Vector2(offsets[i], 0.0)
		_rooms_parent.add_child(instance)

		if rooms[i].kind == RoomData.Kind.SPAWN:
			var spawn := instance.get_node_or_null("SpawnPoint") as Marker2D
			if spawn != null:
				player.global_position = spawn.global_position
		elif rooms[i].kind == RoomData.Kind.EXIT:
			var exit_marker := instance.get_node_or_null("ExitPoint") as Marker2D
			if exit_marker != null:
				_exit_x = exit_marker.global_position.x

	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.limit_right = int(total_width(rooms))


## One enemy per marker, type chosen from the same seed so a given level
## always holds the same enemies.
func _populate_enemies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = used_seed

	var types := Content.enemies()
	if types.is_empty():
		return

	for room: Node in _rooms_parent.get_children():
		var markers := room.get_node_or_null("EnemySpawns")
		if markers == null:
			continue
		for marker: Node in markers.get_children():
			var enemy: Enemy = (
				load("res://src/enemies/enemy.tscn") as PackedScene
			).instantiate()
			enemies.add_child(enemy)
			enemy.configure(types[rng.randi_range(0, types.size() - 1)])
			enemy.target = player
			enemy.global_position = (marker as Marker2D).global_position
