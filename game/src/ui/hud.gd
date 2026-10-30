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
## A world's name shows across the screen this long when the hero arrives in it (the last half fades out).
const BANNER_SECONDS: float = 3.2
const BANNER_TITLE_SIZE: int = 22
const BANNER_COLOR := Color(1.0, 0.86, 0.6)

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
var _banner: VBoxContainer
var _banner_title: Label
var _banner_sub: Label
var _banner_left: float = 0.0


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
	_make_banner(theme)
	_refresh()


func _make_banner(theme: Theme) -> void:
	_banner = VBoxContainer.new()
	_banner.name = "Banner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position.y = GameConfig.tiles(5.0)   # below the HUD text on the left
	_banner.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner_title = Label.new()
	_banner_title.add_theme_font_size_override("font_size", BANNER_TITLE_SIZE)
	_banner_title.add_theme_color_override("font_color", BANNER_COLOR)
	_banner_title.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.04))
	_banner_title.add_theme_constant_override("outline_size", 6)
	_banner_sub = Label.new()
	_banner_sub.theme = theme
	_banner_sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
	_banner_sub.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.04))
	_banner_sub.add_theme_constant_override("outline_size", 4)
	for label: Label in [_banner_title, _banner_sub]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_banner.add_child(label)
	add_child(_banner)
	_banner.visible = false


## Shows a world's name (and a line under it) across the top of the screen for a few seconds.
func show_banner(title: String, subtitle: String = "") -> void:
	_banner_title.text = title
	_banner_sub.text = subtitle
	_banner_left = BANNER_SECONDS
	_banner.modulate.a = 1.0
	_banner.visible = true
	_banner.reset_size()
	_banner.position.x = (get_viewport().get_visible_rect().size.x - _banner.size.x) / 2.0


func hide_banner() -> void:
	_banner_left = 0.0
	_banner.visible = false


func banner_visible() -> bool:
	return _banner.visible


func banner_text() -> String:
	return "%s\n%s" % [_banner_title.text, _banner_sub.text]


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
	if _banner_left > 0.0:
		_banner_left = maxf(0.0, _banner_left - delta)
		_banner.modulate.a = minf(1.0, _banner_left / (BANNER_SECONDS * 0.5))
		_banner.visible = _banner_left > 0.0
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
