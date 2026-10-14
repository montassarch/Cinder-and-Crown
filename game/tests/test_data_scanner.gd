extends GdUnitTestSuite

const TMP_DIR := "user://scanner_test"

func after_test() -> void:
	if DirAccess.dir_exists_absolute(TMP_DIR):
		for f in DirAccess.get_files_at(TMP_DIR):
			DirAccess.remove_absolute(TMP_DIR.path_join(f))
		DirAccess.remove_absolute(TMP_DIR)

func test_normalize_keeps_tres_strips_remap_dedups_and_sorts() -> void:
	var files := PackedStringArray(["b.tres.remap", "a.tres", "c.gd", "a.tres.remap", "readme.md", "c.gd.uid"])
	assert_array(DataScanner.normalize("res://x", files)).is_equal(["res://x/a.tres", "res://x/b.tres"])

func test_lists_every_shipped_enemy_and_weapon() -> void:
	assert_array(DataScanner.list("res://data/enemies")).contains_exactly([
		"res://data/enemies/cinder_bat.tres",
		"res://data/enemies/crown_brute.tres",
		"res://data/enemies/shambler.tres",
	])
	assert_array(DataScanner.list("res://data/weapons")).contains_exactly([
		"res://data/weapons/ember_spear.tres",
		"res://data/weapons/rusty_blade.tres",
	])

func test_missing_directory_lists_nothing() -> void:
	assert_array(DataScanner.list("res://data/nope")).is_empty()

func test_a_file_dropped_into_the_directory_appears_with_no_code_change() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	var f := FileAccess.open(TMP_DIR.path_join("fourth.tres"), FileAccess.WRITE)
	f.store_string("x")
	f.close()
	assert_array(DataScanner.list(TMP_DIR)).is_equal([TMP_DIR + "/fourth.tres"])
