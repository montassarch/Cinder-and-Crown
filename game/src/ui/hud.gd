class_name Hud
extends CanvasLayer
## Health bar, both weapon slots, live enemy count. Reads state; owns none.

const BAR_SIZE_TILES := Vector2(6.0, 0.5)
const MARGIN_TILES: float = 0.5

var _player: Player
var _enemy_counter: Callable
var _fraction: float = 1.0

@onready var _back: ColorRect = $HealthBack
@onready var _fill: ColorRect = $HealthFill
@onready var _weapons: Label = $WeaponLabel
@onready var _enemies: Label = $EnemyLabel


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font_size = GameConfig.UI_FONT_SIZE
	var margin := GameConfig.tiles(MARGIN_TILES)
	var bar := GameConfig.tiles_v(BAR_SIZE_TILES.x, BAR_SIZE_TILES.y)
	for rect: ColorRect in [_back, _fill]:
		rect.position = Vector2(margin, margin)
		rect.size = bar
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label: Label in [_weapons, _enemies]:
		label.theme = theme
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapons.position = Vector2(margin, margin + bar.y + GameConfig.tiles(0.15))
	_enemies.position = _weapons.position + Vector2(0.0, GameConfig.tiles(0.8))
	_refresh()


func bind(player: Player, enemy_counter: Callable) -> void:
	_player = player
	_enemy_counter = enemy_counter
	var health: Health = player.get_node("Health")
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current, health.max_health)
	_refresh()


func health_fraction() -> float:
	return _fraction


func weapon_text() -> String:
	if _player == null:
		return ""
	var parts: Array[String] = []
	for slot in Player.WEAPON_SLOTS:
		var data := _player.weapon_in_slot(slot)
		var mark := ">" if slot == _player.active_slot() else " "
		parts.append("%s%s: %s" % [mark, "AB"[slot], data.display_name if data != null else "-"])
	return "  ".join(parts)


func enemy_text() -> String:
	return "Enemies: %d" % (_enemy_counter.call() if _enemy_counter.is_valid() else 0)


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	_weapons.text = weapon_text()
	_enemies.text = enemy_text()


func _on_health_changed(current: int, max_health: int) -> void:
	_fraction = float(current) / float(maxi(max_health, 1))
	_fill.size.x = GameConfig.tiles(BAR_SIZE_TILES.x) * _fraction
