extends CanvasLayer

## Minimal readout: health, both weapon slots, and a live enemy count.
##
## Deliberately plain. Its purpose is to make the sandbox legible while
## tuning feel, not to be the game's real interface.

var _sandbox: Node2D = null

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _slots_label: Label = %SlotsLabel
@onready var _enemies_label: Label = %EnemiesLabel


## Wired by the sandbox in its own _ready, not pulled from the parent here.
## A child's _ready runs BEFORE its parent's, so reaching up for
## sandbox.player at this point finds an uninitialised @onready and fails.
func bind(sandbox: Node2D) -> void:
	_sandbox = sandbox
	var player: Player = _sandbox.player
	player.health.health_changed.connect(_on_health_changed)
	player.weapon_changed.connect(func(_slot: int, _data: WeaponData) -> void: _refresh_slots())
	_on_health_changed(player.health.current, player.health.max_health)
	_refresh_slots()


func _process(_delta: float) -> void:
	if _sandbox == null:
		return
	_enemies_label.text = "enemies: %d" % _sandbox.enemy_count()


func _on_health_changed(current: int, max_health: int) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = current
	_health_label.text = "%d / %d" % [current, max_health]


func _refresh_slots() -> void:
	var player: Player = _sandbox.player
	var names: Array[String] = []
	for slot: int in range(Player.WEAPON_SLOTS):
		var data: WeaponData = player.slots[slot]
		var label := data.display_name if data != null else "empty"
		# The active hand is marked, since swapping is the core verb here.
		names.append("[%s]" % label if slot == player.active_slot else " %s " % label)
	_slots_label.text = " | ".join(names)
