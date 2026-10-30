extends SceneTree
## A bot that plays a generated level with the real game logic and reports what happened.
##   godot --headless --path game --fixed-fps 60 -s tools/playtest_bot.gd -- <seed> <max_seconds> <start_depth>
## It walks to enemies, attacks, parries red tells, rolls orange ones, drinks the flask, uses Storm and Rend, takes the
## first boon, buys every upgrade, and steps away from stalled fights. Prints PLAYTEST lines: stats, kills per enemy,
## node counts every minute (leak check) and ISSUE lines for stuck states. 600 game seconds take ~30 s of real time.
## Fully dynamic access (a -s script cannot name autoloads or most classes at compile time).

var level: Node
var player: Node
var router: Node
var seed_value := 1
var max_seconds := 180.0
var start_depth := 0
var t := 0.0
var next_attack := 0.0
var next_skill := 0.0
var pending_release: Array = []
var stats := {"deaths": 0, "levels": 0, "kills": 0, "damage_taken": 0, "parries": 0, "rolls": 0, "flasks": 0, "storms": 0, "rends": 0, "boons": 0}
var issues: Array[String] = []
var last_hp := -1
var progress_x := 0.0
var progress_check := 0.0
var level_time := 0.0
var seen_types := {}
var kills_by_type := {}
var tracked := {}
var last_depth := -1
var max_enemies_seen := 0
var shop_opened := 0
var worlds_seen := {}
## Boss instance id -> [name, time it appeared]; finished fights are printed with their length.
var boss_fights := {}
var boss_results: Array[String] = []


var booted := 0
var last_kill_t := 0.0
var wander_until := 0.0
var wander_dir := 1.0
var wanders := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: seed_value = int(args[0])
	if args.size() > 1: max_seconds = float(args[1])
	if args.size() > 2: start_depth = int(args[2])


## The scene tree is only live from the first frame, so the level is built and set up over the first few frames.
func _boot() -> bool:
	booted += 1
	if booted == 1:
		router = root.get_node("InputRouter")
		level = (load("res://levels/generated_level.tscn") as PackedScene).instantiate()
		level.level_seed = seed_value
		root.add_child(level)
		return false
	if booted == 3:
		level.set_depth(start_depth)
		level.regenerate(seed_value)
		return false
	if booted == 5:
		player = level.player
		player.mana().current = player.mana().max_mana
		last_depth = level.depth()
		return false
	return booted < 6


func _hp() -> int:
	return int(player.get_node("Health").current)


func _max_hp() -> int:
	return int(player.get_node("Health").max_health)


func _alive_enemies() -> Array:
	var out := []
	for e in get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("is_dead") and not e.is_dead():
			out.append(e)
	return out


func _press(action: StringName, hold: float = 0.05) -> void:
	router.set_virtual_button(action, true)
	pending_release.append([action, t + hold])


func _physics_process(delta: float) -> bool:
	if booted < 6:
		_boot()
		return false
	t += delta
	level_time += delta
	for item in pending_release.duplicate():
		if t >= item[1]:
			router.set_virtual_button(item[0], false)
			pending_release.erase(item)
	if t >= max_seconds:
		_report("time limit")
		return true
	if not is_instance_valid(player):
		issues.append("player node vanished")
		_report("player lost")
		return true

	# ---- screens that take over
	var shop = level.get_node_or_null("MetaShop")
	if shop != null and shop.is_open():
		shop_opened += 1
		for i in shop.row_count():
			if shop.buy_enabled(i):
				shop.press_buy(i)
		shop.press_start()
		stats["deaths"] += 1
		level_time = 0.0
		return false
	var picker = level.get_node_or_null("BoonPicker")
	if picker != null and picker.is_open():
		picker.choose(0)
		stats["boons"] += 1
		stats["levels"] += 1
		level_time = 0.0
		return false
	worlds_seen[level.biome().id] = true
	if level.depth() != last_depth:
		last_depth = level.depth()

	# ---- bookkeeping
	var hp := _hp()
	if last_hp >= 0 and hp < last_hp:
		stats["damage_taken"] += last_hp - hp
	last_hp = hp
	var enemies := _alive_enemies()
	max_enemies_seen = maxi(max_enemies_seen, enemies.size())
	for e in enemies:
		var id: String = e.data.display_name
		seen_types[id] = true
		if not tracked.has(e.get_instance_id()):
			tracked[e.get_instance_id()] = id
			if e.data.boss:
				boss_fights[e.get_instance_id()] = [id, t]
		if e.global_position.y > 2000.0 or is_nan(e.global_position.x):
			issues.append("enemy %s out of the world at %s" % [id, e.global_position])
	for k in tracked.keys():
		if not is_instance_valid(instance_from_id(k)) or instance_from_id(k).is_dead():
			var kid: String = tracked[k]
			kills_by_type[kid] = int(kills_by_type.get(kid, 0)) + 1
			if boss_fights.has(k):
				boss_results.append("%s beaten in %.0fs" % [boss_fights[k][0], t - boss_fights[k][1]])
				boss_fights.erase(k)
			stats['kills'] += 1
			last_kill_t = t
			tracked.erase(k)
	if player.global_position.y > 2000.0:
		issues.append("hero fell out of the world at t=%.1f" % t)
		_report("hero lost")
		return true

	var pos: Vector2 = player.global_position
	var axis := 0.0
	var want_attack := false

	# ---- survival first
	if hp < _max_hp() * 0.4 and player.flask_charges() > 0:
		var near := false
		for e in enemies:
			if absf(e.global_position.x - pos.x) < 80.0: near = true
		if not near and t >= next_skill:
			_press(&"flask", 0.1)
			stats["flasks"] += 1
			next_skill = t + 1.0

	# ---- react to telegraphs
	var danger: Node = null
	for e in enemies:
		if e._state == e.State.TELEGRAPH and e._move != null and absf(e.global_position.x - pos.x) < 80.0:
			danger = e
	if danger != null:
		var progress: float = danger.telegraph_progress()
		if danger._move.parryable:
			if progress > 0.78 and t >= next_skill:
				_press(&"parry", 0.12)
				stats["parries"] += 1
				next_skill = t + 0.5
		elif progress > 0.8 and t >= next_skill:
			axis = signf(pos.x - danger.global_position.x)
			_press(&"roll", 0.1)
			stats["rolls"] += 1
			next_skill = t + 0.6

	# ---- a fight that goes nowhere (a flyer out of reach): step away like a person would
	if not enemies.is_empty() and t - last_kill_t > 14.0 and t >= wander_until:
		wander_until = t + 3.0
		wander_dir = -wander_dir
		last_kill_t = t - 6.0
		wanders += 1
	if t < wander_until:
		router.set_virtual_axis(wander_dir)
		if randi() % 40 == 0:
			_press(&"jump", 0.2)
		return false

	# ---- choose a target or head for the exit
	var target: Node = null
	var best := 1e9
	for e in enemies:
		var d := absf(e.global_position.x - pos.x)
		if d < best:
			best = d
			target = e
	if target != null:
		var dx: float = target.global_position.x - pos.x
		if absf(dx) > 28.0:
			axis = signf(dx) if axis == 0.0 else axis
		else:
			if axis == 0.0:
				axis = signf(dx) * 0.3   # face it without walking through it
			want_attack = true
		if target.global_position.y < pos.y - 40.0 and t >= next_skill:
			_press(&"jump", 0.2)           # a flyer overhead: hop
			next_skill = t + 0.6
		if best < 128.0 and player.mana().current >= 40.0 and t >= next_skill + 0.2:
			_press(&"skill1", 0.1)
			stats["storms"] += 1
			next_skill = t + 1.0
		elif best < 96.0 and player.mana().current >= 30.0 and t >= next_skill + 0.2:
			_press(&"skill2", 0.1)
			stats["rends"] += 1
			next_skill = t + 1.0
	else:
		axis = 1.0
		var ex := _exit_x()
		if ex > 0.0 and absf(ex - pos.x) < 6.0:
			axis = 0.0
		if t >= next_skill and randi() % 90 == 0:
			_press(&"jump", 0.2)           # hop up ledges on the way
	if want_attack and t >= next_attack:
		_press(&"attack", 0.08)
		next_attack = t + 0.33
	router.set_virtual_axis(axis)

	# ---- stuck detection (no horizontal progress for a long time while nothing to fight)
	if int(t) % 10 == 0 and int(t * 60) % 60 == 0:
		var desc := []
		for e in enemies:
			desc.append('%s@(%.0f,%.0f) st=%d' % [e.data.display_name, e.global_position.x, e.global_position.y, e._state])
		print('PLAYTEST t=%.0f depth=%d hero=(%.0f,%.0f) hp=%d state=%s enemies=%s exitx=%.0f axis=%.1f' % [t, level.depth(), pos.x, pos.y, hp, str(player.state()), str(desc), _exit_x(), axis])
	if int(t * 60) % 3600 == 0:
		print('PLAYTEST mem t=%.0f nodes=%d orphans=%d objects=%d physics_ms=%.2f process_ms=%.2f attacks_group=%d' % [t, Performance.get_monitor(Performance.OBJECT_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT), Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, get_nodes_in_group('enemy_attacks').size()])
	progress_check += delta
	if progress_check >= 10.0:
		progress_check = 0.0
		if enemies.is_empty() and absf(pos.x - progress_x) < 8.0:
			issues.append("hero stuck at x=%.0f for 10 s with no enemies (t=%.0f, depth %d)" % [pos.x, t, level.depth()])
		progress_x = pos.x
	if level_time > 90.0 and not enemies.is_empty():
		var desc := []
		for e in enemies:
			desc.append('%s@(%.0f,%.0f) st=%d dead=%s' % [e.data.display_name, e.global_position.x, e.global_position.y, e._state, str(e.is_dead())])
		issues.append("one level took over 90 s (depth %d) hero=(%.0f,%.0f) state=%s enemies=%s" % [level.depth(), pos.x, pos.y, str(player.state()), str(desc)])
		level_time = 0.0
	return false


func _exit_x() -> float:
	var best := -1.0
	for z in level._exit_zones:
		if is_instance_valid(z):
			best = z.global_position.x
	return best


func _report(why: String) -> void:
	for a in [&"attack", &"jump", &"roll", &"parry", &"flask", &"skill1", &"skill2"]:
		router.set_virtual_button(a, false)
	print("PLAYTEST seed=%d ended: %s after %.0fs" % [seed_value, why, t])
	print("PLAYTEST stats ", JSON.stringify(stats))
	print("PLAYTEST kills ", JSON.stringify(kills_by_type), " wanders ", wanders)
	print("PLAYTEST world ", level.biome().id, " worlds visited ", worlds_seen.keys())
	print("PLAYTEST depth ", level.depth(), " hp ", _hp(), "/", _max_hp(), " cells ", level.cells_this_run(), " enemy types seen ", seen_types.keys(), " max enemies at once ", max_enemies_seen, " shop opens ", shop_opened)
	for r in boss_results:
		print("PLAYTEST boss ", r)
	for i in issues:
		print("PLAYTEST ISSUE ", i)
