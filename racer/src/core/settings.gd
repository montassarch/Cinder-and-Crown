extends RefCounted
## Player-adjustable control and camera settings. Saved to disk on every change (in the web
## build, user:// is the browser's local storage) and restored on the next launch.

signal changed

const DEFAULT_PATH: String = "user://racer_settings.cfg"
const SECTION: String = "settings"
const DEFAULTS: Dictionary = {
	"steer_sensitivity": 1.0,
	"steer_deadzone": 0.08,
	"button_scale": 1.0,
	"button_opacity": 0.9,
	"mirror_layout": false,
	"camera_distance": 4.8,
}
## Inclusive (min, max) for every numeric setting.
const LIMITS: Dictionary = {
	"steer_sensitivity": Vector2(0.4, 2.5),
	"steer_deadzone": Vector2(0.0, 0.3),
	"button_scale": Vector2(0.6, 1.6),
	"button_opacity": Vector2(0.3, 1.0),
	"camera_distance": Vector2(3.2, 9.0),
}

## How far you must drag, at sensitivity 1, for full steering lock (screen units).
var steer_sensitivity: float = 1.0
## Fraction of the drag range ignored around the centre, so small wobbles do nothing.
var steer_deadzone: float = 0.08
var button_scale: float = 1.0
var button_opacity: float = 0.9
## Steering on the right half of the screen and the buttons on the left.
var mirror_layout: bool = false
## Metres from the car to the camera; the camera height follows from it.
var camera_distance: float = 4.8

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path
	load_from_disk()


func camera_height() -> float:
	return camera_distance * 0.5


func set_value(key: String, value: Variant) -> void:
	assert(DEFAULTS.has(key), "unknown setting: " + key)
	if LIMITS.has(key):
		var limits: Vector2 = LIMITS[key]
		value = clampf(float(value), limits.x, limits.y)
	set(key, value)
	save_to_disk()
	changed.emit()


func reset() -> void:
	for key in DEFAULTS:
		set(key, DEFAULTS[key])
	save_to_disk()
	changed.emit()


func load_from_disk() -> void:
	var file := ConfigFile.new()
	if file.load(_path) != OK:
		return
	for key in DEFAULTS:
		var value: Variant = file.get_value(SECTION, key, DEFAULTS[key])
		if LIMITS.has(key):
			var limits: Vector2 = LIMITS[key]
			value = clampf(float(value), limits.x, limits.y)
		set(key, value)


func save_to_disk() -> void:
	var file := ConfigFile.new()
	for key in DEFAULTS:
		file.set_value(SECTION, key, get(key))
	file.save(_path)
