extends GdUnitTestSuite

var _picker: BoonPicker
var _chosen: Array[BoonData] = []

func before_test() -> void:
	_chosen.clear()
	_picker = auto_free(BoonPicker.new())
	add_child(_picker)
	_picker.chosen.connect(func(b: BoonData) -> void: _chosen.append(b))

func after_test() -> void:
	get_tree().paused = false

func _boon(name: String, rarity: BoonData.Rarity = BoonData.Rarity.COMMON) -> BoonData:
	var b := BoonData.new()
	b.id = name.to_lower()
	b.display_name = name
	b.description = "Does %s things." % name
	b.rarity = rarity
	return b

func _three() -> Array[BoonData]:
	return [_boon("Alpha"), _boon("Beta", BoonData.Rarity.RARE), _boon("Gamma", BoonData.Rarity.EPIC)]

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func test_it_starts_hidden_and_the_game_runs() -> void:
	assert_bool(_picker.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()

func test_offering_boons_opens_it_and_pauses_the_game() -> void:
	_picker.offer(_three())
	assert_bool(_picker.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()

func test_one_card_per_boon_showing_its_name_and_description() -> void:
	_picker.offer(_three())
	assert_int(_picker.card_count()).is_equal(3)
	assert_str(_picker.card_title(0)).is_equal("Alpha")
	assert_str(_picker.card_description(2)).is_equal("Does Gamma things.")

func test_rarities_are_told_apart_by_colour() -> void:
	_picker.offer(_three())
	assert_object(_picker.card_color(0)).is_not_equal(_picker.card_color(1))
	assert_object(_picker.card_color(1)).is_not_equal(_picker.card_color(2))

func test_choosing_a_card_reports_that_boon_closes_and_unpauses() -> void:
	var offers := _three()
	_picker.offer(offers)
	_picker.choose(1)
	assert_array(_chosen).is_equal([offers[1]])
	assert_bool(_picker.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()

func test_pressing_a_card_button_chooses_it() -> void:
	var offers := _three()
	_picker.offer(offers)
	_picker.press_card(2)
	assert_array(_chosen).is_equal([offers[2]])

func test_number_keys_choose_the_matching_card() -> void:
	var offers := _three()
	_picker.offer(offers)
	_picker._unhandled_input(_key(KEY_2))
	assert_array(_chosen).is_equal([offers[1]])

func test_a_number_key_with_no_such_card_does_nothing() -> void:
	_picker.offer([_boon("Solo")] as Array[BoonData])
	_picker._unhandled_input(_key(KEY_3))
	assert_array(_chosen).is_empty()
	assert_bool(_picker.is_open()).is_true()

func test_it_only_chooses_once_per_offer() -> void:
	_picker.offer(_three())
	_picker.choose(0)
	_picker.choose(1)
	assert_int(_chosen.size()).is_equal(1)

func test_offering_nothing_stays_closed() -> void:
	_picker.offer([] as Array[BoonData])
	assert_bool(_picker.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()

func test_a_second_offer_replaces_the_cards() -> void:
	_picker.offer(_three())
	_picker.choose(0)
	_picker.offer([_boon("Delta"), _boon("Echo")] as Array[BoonData])
	assert_int(_picker.card_count()).is_equal(2)
	assert_str(_picker.card_title(0)).is_equal("Delta")
