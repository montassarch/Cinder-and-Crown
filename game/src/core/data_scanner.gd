class_name DataScanner
extends RefCounted
## Finds data files at runtime so dropping a .tres into a folder is all it takes
## to add content. Exported builds list resources as "name.tres.remap"; those count.


static func list(dir: String) -> Array[String]:
	if not DirAccess.dir_exists_absolute(dir):
		return []
	return normalize(dir, DirAccess.get_files_at(dir))


static func normalize(dir: String, files: PackedStringArray) -> Array[String]:
	var found: Array[String] = []
	for file in files:
		var name := file.trim_suffix(".remap")
		var path := dir.path_join(name)
		if name.ends_with(".tres") and not found.has(path):
			found.append(path)
	found.sort()
	return found
