class_name MetaSave
extends RefCounted
## What carries over between runs: cells (the currency) and the rank of each upgrade bought
## with them. Stored as JSON in user://. The parsed file is cached; every write goes to a
## temp file first, so a crash mid-write cannot lose progress.

const DEFAULT_PATH := "user://cinder_and_crown_save.json"

## Tests point this at a scratch file. Setting it drops the cached copy.
static var path: String = DEFAULT_PATH:
	set(value):
		path = value
		_cache = {}
static var _cache: Dictionary = {}


static func cells() -> int:
	return _data().cells


static func add_cells(amount: int) -> void:
	if amount <= 0:
		return
	_data().cells += amount
	_write()


static func rank(id: String) -> int:
	return _data().ranks.get(id, 0)


## The price of the next rank, or -1 when the upgrade is maxed out.
static func next_cost(upgrade: MetaUpgradeData) -> int:
	var owned := rank(upgrade.id)
	return upgrade.costs[owned] if owned < upgrade.costs.size() else -1


static func can_afford(upgrade: MetaUpgradeData) -> bool:
	var cost := next_cost(upgrade)
	return cost >= 0 and cells() >= cost


static func buy(upgrade: MetaUpgradeData) -> bool:
	if not can_afford(upgrade):
		return false
	var data := _data()
	data.cells -= next_cost(upgrade)
	data.ranks[upgrade.id] = rank(upgrade.id) + 1
	_write()
	return true


## One stand-in boon per owned upgrade, worth its rank times its per-rank amount.
static func bonus_boons(upgrades: Array[MetaUpgradeData]) -> Array[BoonData]:
	var bonuses: Array[BoonData] = []
	for upgrade in upgrades:
		var owned := rank(upgrade.id)
		if owned <= 0:
			continue
		var boon := BoonData.new()
		boon.id = "meta_" + upgrade.id
		boon.display_name = upgrade.display_name
		boon.effect = upgrade.effect
		boon.amount = upgrade.amount_per_rank * owned
		bonuses.append(boon)
	return bonuses


static func _data() -> Dictionary:
	if _cache.is_empty():
		_cache = _coerced(_read(path))
		if _cache.is_empty():
			_cache = _coerced({})
	return _cache


static func _read(file: String) -> Dictionary:
	for candidate in [file, file + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(candidate)) == OK and json.data is Dictionary:
			return json.data
	return {}


## A hand-edited or damaged file still yields sane types.
static func _coerced(raw: Dictionary) -> Dictionary:
	var cells_value: Variant = raw.get("cells", 0)
	var clean := {"cells": maxi(int(cells_value), 0) if (cells_value is int or cells_value is float) else 0, "ranks": {}}
	var raw_ranks: Variant = raw.get("ranks", {})
	if raw_ranks is Dictionary:
		for key in raw_ranks:
			var value: Variant = raw_ranks[key]
			if value is int or value is float:
				clean.ranks[str(key)] = maxi(int(value), 0)
	return clean


static func _write() -> void:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("MetaSave: cannot write %s" % temp)
		return
	file.store_string(JSON.stringify(_data()))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.copy_absolute(path, path + ".bak")
	DirAccess.rename_absolute(temp, path)
