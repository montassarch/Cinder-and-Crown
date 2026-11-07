extends RefCounted
## Loads every CarSpec found in res://data/cars. Add a car by dropping a .tres file there.

const CarSpec := preload("res://src/cars/car_spec.gd")
const FOLDER: String = "res://data/cars"


static func load_all() -> Array[CarSpec]:
	var specs: Array[CarSpec] = []
	var names: PackedStringArray = DirAccess.get_files_at(FOLDER)
	names.sort()
	for file_name in names:
		# Exported builds list imported resources with a .remap suffix.
		var clean: String = file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var spec: CarSpec = load(FOLDER + "/" + clean) as CarSpec
		if spec != null:
			specs.append(spec)
	return specs
