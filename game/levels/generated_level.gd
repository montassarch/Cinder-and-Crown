class_name GeneratedLevel
extends Sandbox
## Rooms chosen by LevelGenerator from data/rooms, laid end to end. Reaching the exit
## builds the next level from the next seed. Everything else (player, HUD, menu, touch)
## comes from Sandbox.

signal level_completed

const ROOM_DIR := "res://data/rooms"
const BOON_DIR := "res://data/boons"
const ENEMY_DIR := "res://data/enemies"
## The hero is this far into a room when its wave appears.
const ENCOUNTER_TRIGGER_TILES: float = 3.0
## A wave stands between this far from the room's left edge and a margin from its right.
const WAVE_FIRST_SLOT_TILES: float = 9.0
const WAVE_END_MARGIN_TILES: float = 2.0
const GATE_SHUT_COLOR := Color(0.9, 0.2, 0.2, 0.45)
const OFFER_COUNT: int = 3

@export var level_seed: int = 1
@export var room_count: int = 6
## Off, the rooms are empty and the exit is always open (for layout tests).
@export var encounters_enabled: bool = true

var _layout: Array[RoomData] = []
var _width_tiles: float = 0.0
var _spawn: Vector2 = Vector2.ZERO
var _boon_pool: Array[BoonData] = []
var _exit_zones: Array[Area2D] = []
var _enemy_pool: Array[EnemyData] = []
var _encounters: Array[Dictionary] = []
var _gate_open_color := Color.WHITE
var _gate_color := Color.WHITE
var _depth: int = 0

@onready var _rooms: Node2D = $Rooms
@onready var _walls: Node2D = $Walls
@onready var _picker: BoonPicker = $BoonPicker


func _ready() -> void:
	super()
	for path in DataScanner.list(BOON_DIR):
		var boon := load(path) as BoonData
		if boon != null:
			_boon_pool.append(boon)
	for path in DataScanner.list(ENEMY_DIR):
		var enemy := load(path) as EnemyData
		if enemy != null:
			_enemy_pool.append(enemy)
	_picker.chosen.connect(_on_boon_chosen)


func layout() -> Array[RoomData]:
	return _layout


## Levels cleared this run; picks which enemies can appear and how big the waves are.
func depth() -> int:
	return _depth


func set_depth(value: int) -> void:
	_depth = maxi(value, 0)


func encounter_room_count() -> int:
	return _encounters.size()


## The colour the exit gate is showing right now.
func exit_gate_color() -> Color:
	return _gate_color


func _process(delta: float) -> void:
	super(delta)
	_trigger_encounters()
	_update_exit_gate()


func _exit_open() -> bool:
	return not encounters_enabled or enemy_count() == 0


func _trigger_encounters() -> void:
	if not encounters_enabled or player == null:
		return
	for encounter in _encounters:
		if not encounter.spawned and player.global_position.x >= GameConfig.tiles(encounter.start + ENCOUNTER_TRIGGER_TILES):
			encounter.spawned = true
			_spawn_wave(encounter)


func _spawn_wave(encounter: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed * 7919 + int(encounter.index) * 104729 + _depth * 31
	var wave := WaveGenerator.roll(_enemy_pool, _depth, rng)
	for i in wave.size():
		var along := (i + 0.5) / wave.size()
		var x_tiles := lerpf(encounter.start + WAVE_FIRST_SLOT_TILES, encounter.end - WAVE_END_MARGIN_TILES, along)
		var height := AIR_SPAWN_HEIGHT_TILES if wave[i].behaviour == EnemyData.Behaviour.FLYER else GROUND_SPAWN_HEIGHT_TILES
		spawn_enemy_at(wave[i], GameConfig.tiles_v(x_tiles, GROUND_TOP_TILES - height))


## The gate glows red while enemies live and shows its normal colour once the level is clear.
func _update_exit_gate() -> void:
	_gate_color = _gate_open_color if _exit_open() else GATE_SHUT_COLOR
	for zone in _exit_zones:
		if is_instance_valid(zone) and zone.has_node("Visual"):
			(zone.get_node("Visual") as ColorRect).color = _gate_color


func spawn_point() -> Vector2:
	return _spawn


func arena_width_tiles() -> float:
	return _width_tiles


func arena_height_tiles() -> float:
	var tallest := 0
	for room in _layout:
		tallest = maxi(tallest, room.size_tiles.y)
	return float(tallest) if tallest > 0 else super.arena_height_tiles()


## Builds the next level and puts the player back at its spawn.
func regenerate(new_seed: int) -> void:
	level_seed = new_seed
	for container in [_rooms, _walls]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	clear_enemies()
	_build_arena()
	_apply_camera_limits()
	player.reset(spawn_point())


func _scene_switch() -> Array:
	return ["Sandbox", SANDBOX_PATH]


func _build_arena() -> void:
	_exit_zones.clear()
	_encounters.clear()
	var pool: Array[RoomData] = []
	for path in DataScanner.list(ROOM_DIR):
		var room := load(path) as RoomData
		if room != null:
			pool.append(room)
	_layout = LevelGenerator.generate(pool, room_count, level_seed)
	if _layout.is_empty():
		push_error("GeneratedLevel: no valid level from %d rooms in %s (seed %d)" % [pool.size(), ROOM_DIR, level_seed])
		_width_tiles = ARENA_WIDTH_TILES
		_spawn = super.spawn_point()
		return

	var cursor := 0.0
	for room in _layout:
		if room.kind == RoomData.Kind.NORMAL:
			_encounters.append({"index": _encounters.size(), "start": cursor, "end": cursor + room.size_tiles.x, "spawned": false})
		var instance: Node2D = room.scene.instantiate()
		instance.position = GameConfig.tiles_v(cursor, 0.0)
		_rooms.add_child(instance)
		if room.kind == RoomData.Kind.SPAWN:
			_spawn = (instance.get_node("PlayerSpawn") as Marker2D).global_position
		elif room.kind == RoomData.Kind.EXIT:
			var zone := instance.get_node("ExitZone") as Area2D
			_exit_zones.append(zone)
			_gate_open_color = (zone.get_node("Visual") as ColorRect).color
			# Physics callbacks may not free bodies, so build the next level a frame later.
			zone.body_entered.connect(func(body: Node) -> void: _on_exit_entered.call_deferred(body))
		cursor += room.size_tiles.x
	_width_tiles = cursor

	var wall_top := GROUND_TOP_TILES - WALL_HEIGHT_TILES
	var wall_height := WALL_HEIGHT_TILES + GROUND_THICKNESS_TILES
	_add_block(Rect2(-1.0, wall_top, 1.0, wall_height), GROUND_COLOR, false, _walls)
	_add_block(Rect2(_width_tiles, wall_top, 1.0, wall_height), GROUND_COLOR, false, _walls)


## True when the hero's body really overlaps an exit zone. The physics engine can report
## a zone built this frame as entered by a hero who has since been moved to the spawn.
func _hero_on_exit(hero: Player) -> bool:
	var size := GameConfig.tiles_v(Player.BODY_SIZE_TILES.x, Player.BODY_SIZE_TILES.y)
	var body_rect := Rect2(hero.global_position - size / 2.0, size)
	for zone in _exit_zones:
		if not is_instance_valid(zone) or not zone.is_inside_tree():
			continue
		for child in zone.get_children():
			var shape := (child as CollisionShape2D).shape as RectangleShape2D if child is CollisionShape2D else null
			if shape != null and Rect2(zone.global_position - shape.size / 2.0, shape.size).intersects(body_rect, true):
				return true
	return false


## Reaching the exit offers boons; the next level is built once one is taken.
func _on_exit_entered(body: Node) -> void:
	if not (body is Player) or _picker.is_open() or not _hero_on_exit(body) or not _exit_open():
		return
	level_completed.emit()
	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed
	var offers := player.build().roll_offers(_boon_pool, OFFER_COUNT, rng)
	if offers.is_empty():
		regenerate(level_seed + 1)
		return
	_touch.release_all()
	_picker.offer(offers)


func _on_boon_chosen(boon: BoonData) -> void:
	player.apply_boon(boon)
	_depth += 1
	regenerate(level_seed + 1)


## A fresh run: back to depth 0 on a fresh copy of this level, boons dropped.
func reset_player() -> void:
	_depth = 0
	player.start_new_run()
	regenerate(level_seed)
