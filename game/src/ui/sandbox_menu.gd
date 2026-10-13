extends CanvasLayer

## The sandbox's control panel.
##
## It scans data/enemies/ and data/weapons/ at RUNTIME rather than listing
## them in code. That is the data-driven rule made visible: drop a new
## .tres into either folder and it appears here with no rebuild. If this
## menu ever needs editing to show a new weapon, the system has regressed.

# Directories come from Content, the one place that knows where content
# lives, so this menu and the level generator can never disagree.
const ENEMY_DIR := Content.ENEMY_DIR
const WEAPON_DIR := Content.WEAPON_DIR

var _sandbox: Node2D = null

@onready var _enemy_list: VBoxContainer = %EnemyList
@onready var _weapon_list: VBoxContainer = %WeaponList

var _weapons: Array[WeaponData] = []


## Wired by the sandbox in its own _ready. See the note on HUD.bind.
func bind(sandbox: Node2D) -> void:
	_sandbox = sandbox
	_build_enemy_buttons()
	_build_weapon_buttons()
	%ClearButton.pressed.connect(_sandbox.clear_enemies)
	%ResetButton.pressed.connect(_sandbox.reset_player)
	%DebugToggle.toggled.connect(_on_debug_toggled)
	%CollapseButton.pressed.connect(_on_collapse)
	%RunButton.pressed.connect(_on_run_pressed)


## Delegates to Content so there is exactly one scanner in the project.
static func list_resources(dir_path: String) -> Array[String]:
	return Content.list_resources(dir_path)


func _build_enemy_buttons() -> void:
	for path: String in list_resources(ENEMY_DIR):
		var data: EnemyData = load(path)
		if data == null:
			continue
		var button := Button.new()
		button.text = "+ %s" % data.display_name
		button.pressed.connect(func() -> void: _sandbox.spawn_enemy(data))
		_enemy_list.add_child(button)


func _build_weapon_buttons() -> void:
	for path: String in list_resources(WEAPON_DIR):
		var data: WeaponData = load(path)
		if data == null:
			continue
		_weapons.append(data)

	# One row per weapon, with a button per slot, so any weapon can go in
	# either hand without a dropdown to fight.
	for data: WeaponData in _weapons:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = data.display_name
		label.custom_minimum_size.x = 96.0
		row.add_child(label)
		for slot: int in range(Player.WEAPON_SLOTS):
			var button := Button.new()
			button.text = "slot %d" % (slot + 1)
			button.pressed.connect(
				func() -> void: _sandbox.player.equip_slot(slot, data)
			)
			row.add_child(button)
		_weapon_list.add_child(row)


func _on_debug_toggled(pressed: bool) -> void:
	(%DebugOverlay as Node2D).visible = pressed


func _on_collapse() -> void:
	var panel := %Panel as Control
	panel.visible = not panel.visible
	(%CollapseButton as Button).text = "menu" if not panel.visible else "hide"


func _on_run_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/run_level.tscn")
