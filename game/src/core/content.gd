class_name Content
extends RefCounted

## Discovers game content by scanning disk.
##
## This is the data-driven rule's only real enforcement. Anything that
## enumerates weapons, enemies or rooms goes through here, so dropping a
## new .tres into data/ reaches every consumer at once. A hardcoded list
## anywhere means the same file behaves differently in two places --
## which is exactly the bug this replaces: the sandbox menu scanned the
## folder while the level generator used a fixed list, so a new enemy
## appeared in one and never in the other, and a new room reached neither.

const WEAPON_DIR := "res://data/weapons"
const ENEMY_DIR := "res://data/enemies"
const ROOM_DIR := "res://data/rooms"


## Resource paths in a directory, sorted for determinism.
##
## Tolerates the renaming that export does: a .tres can ship as .res, and
## either can gain a .remap suffix. A scan matching only ".tres" finds
## nothing in an exported build — so the menu would come up empty on the
## very build that goes to a phone.
static func list_resources(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for file_name: String in dir.get_files():
		var clean := file_name.trim_suffix(".remap")
		if clean.get_extension() in ["tres", "res"]:
			found.append(dir_path.path_join(clean))
	found.sort()
	return found


## Loads every resource in a directory, skipping any that fail to load.
static func load_all(dir_path: String) -> Array[Resource]:
	var loaded: Array[Resource] = []
	for path: String in list_resources(dir_path):
		var resource: Resource = load(path)
		if resource != null:
			loaded.append(resource)
	return loaded


static func weapons() -> Array[WeaponData]:
	var typed: Array[WeaponData] = []
	for resource: Resource in load_all(WEAPON_DIR):
		if resource is WeaponData:
			typed.append(resource)
	return typed


static func enemies() -> Array[EnemyData]:
	var typed: Array[EnemyData] = []
	for resource: Resource in load_all(ENEMY_DIR):
		if resource is EnemyData:
			typed.append(resource)
	return typed


static func rooms() -> Array[RoomData]:
	var typed: Array[RoomData] = []
	for resource: Resource in load_all(ROOM_DIR):
		if resource is RoomData:
			typed.append(resource)
	return typed
