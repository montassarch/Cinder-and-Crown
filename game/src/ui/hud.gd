class_name Hud
extends CanvasLayer
## Health bar, mana bar, both weapon slots, live enemy count. Reads state; owns none.

const BAR_SIZE_TILES := Vector2(6.0, 0.5)
const MANA_BAR_SIZE_TILES := Vector2(6.0, 0.3)
const MARGIN_TILES: float = 0.5
const MANA_GAP_TILES: float = 0.1
const MANA_COLOR := Color(0.25, 0.55, 1.0)
const MANA_DENIED_COLOR := Color(1.0, 0.95, 0.95)
const MANA_FLASH_SECONDS: float = 0.35

var _player: Player
var _enemy_counter: Callable
var _fraction: float = 1.0
var _mana_fraction: float = 1.0
var _mana_flash: float = 0.0

@onready var _back: ColorRect = $HealthBack
@onready var _fill: ColorRect = $HealthFill
@onready var _mana_back: ColorRect = $ManaBack
@onready var _mana_fill: ColorRect = $ManaFill
@onready var _weapons: Label = $WeaponLabel
@onready var _enemies: Label = $EnemyLabel
var _flask_label: Label
var _cells_label: Label


func _ready() -> void:
	var theme := Theme.new()
	theme.default_font_size = GameConfig.UI_FONT_SIZE
	var margin := GameConfig.tiles(MARGIN_TILES)
	var bar := GameConfig.tiles_v(BAR_SIZE_TILES.x, BAR_SIZE_TILES.y)
	for rect: ColorRect in [_back, _fill]:
		rect.position = Vector2(margin, margin)
		rect.size = bar
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mana_bar := GameConfig.tiles_v(MANA_BAR_SIZE_TILES.x, MANA_BAR_SIZE_TILES.y)
	var mana_top := margin + bar.y + GameConfig.tiles(MANA_GAP_TILES)
	for rect: ColorRect in [_mana_back, _mana_fill]:
		rect.position = Vector2(margin, mana_top)
		rect.size = mana_bar
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flask_label = Label.new()
	_flask_label.name = "FlaskLabel"
	add_child(_flask_label)
	_cells_label = Label.new()
	_cells_label.name = "CellsLabel"
	add_child(_cells_label)
	for label: Label in [_weapons, _enemies, _flask_label, _cells_label]:
		label.theme = theme
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapons.position = Vector2(margin, mana_top + mana_bar.y + GameConfig.tiles(0.15))
	_enemies.position = _weapons.position + Vector2(0.0, GameConfig.tiles(0.8))
	_flask_label.position = _enemies.position + Vector2(0.0, GameConfig.tiles(0.8))
	_cells_label.position = _flask_label.position + Vector2(0.0, GameConfig.tiles(0.8))
	_cells_label.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	_refresh()


func bind(player: Player, enemy_counter: Callable) -> void:
	_player = player
	_enemy_counter = enemy_counter
	var health: Health = player.get_node("Health")
	health.health_changed.connect(_on_health_changed)
	_on_health_changed(health.current, health.max_health)
	var mana := player.mana()
	mana.mana_changed.connect(_on_mana_changed)
	_on_mana_changed(mana.current, mana.max_mana)
	player.mana_denied.connect(_on_mana_denied)
	player.flask_changed.connect(func(_charges: int, _maximum: int) -> void: _refresh())
	_refresh()


func health_fraction() -> float:
	return _fraction


func mana_fraction() -> float:
	return _mana_fraction


## True while the mana bar is flashing after a cast was refused.
func mana_flashing() -> bool:
	return _mana_flash > 0.0


func weapon_text() -> String:
	if _player == null:
		return ""
	var parts: Array[String] = []
	for slot in Player.WEAPON_SLOTS:
		var data := _player.weapon_in_slot(slot)
		var mark := ">" if slot == _player.active_slot() else " "
		parts.append("%s%s: %s" % [mark, "AB"[slot], data.display_name if data != null else "-"])
	return "  ".join(parts)


func flask_text() -> String:
	if _player == null:
		return ""
	return "Flask: %d/%d" % [_player.flask_charges(), _player.flask_max()]


func cells_text() -> String:
	return "Cells: %d" % MetaSave.cells()


func enemy_text() -> String:
	return "Enemies: %d" % (_enemy_counter.call() if _enemy_counter.is_valid() else 0)


func _process(delta: float) -> void:
	if _mana_flash > 0.0:
		_mana_flash = maxf(0.0, _mana_flash - delta)
		_mana_fill.color = MANA_COLOR.lerp(MANA_DENIED_COLOR, _mana_flash / MANA_FLASH_SECONDS)
		_mana_back.color = Color(0.04, 0.07, 0.15, 0.85).lerp(MANA_DENIED_COLOR, 0.5 * _mana_flash / MANA_FLASH_SECONDS)
	_refresh()


func _refresh() -> void:
	_weapons.text = weapon_text()
	_enemies.text = enemy_text()
	_flask_label.text = flask_text()
	_cells_label.text = cells_text()


func _on_health_changed(current: int, max_health: int) -> void:
	_fraction = float(current) / float(maxi(max_health, 1))
	_fill.size.x = GameConfig.tiles(BAR_SIZE_TILES.x) * _fraction


func _on_mana_changed(current: float, max_mana: float) -> void:
	_mana_fraction = current / maxf(max_mana, 0.001)
	_mana_fill.size.x = GameConfig.tiles(MANA_BAR_SIZE_TILES.x) * _mana_fraction


func _on_mana_denied() -> void:
	_mana_flash = MANA_FLASH_SECONDS
