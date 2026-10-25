class_name DamageNumber
extends Label
## A number that pops up where a hit landed, floats up and fades. Big hits are larger and golden.

const LIFETIME: float = 0.7
const RISE_PIXELS: float = 22.0
const BIG_HIT: int = 14
const SMALL_SIZE: int = 9
const BIG_SIZE: int = 14
const SMALL_COLOR := Color(1.0, 0.97, 0.9)
const BIG_COLOR := Color(1.0, 0.82, 0.3)


static func spawn(parent: Node, amount: int, at: Vector2) -> DamageNumber:
	var number := DamageNumber.new()
	number.text = str(amount)
	var big := amount >= BIG_HIT
	number.add_theme_font_size_override(&"font_size", BIG_SIZE if big else SMALL_SIZE)
	number.add_theme_color_override(&"font_color", BIG_COLOR if big else SMALL_COLOR)
	number.add_theme_color_override(&"font_outline_color", Color(0.05, 0.02, 0.08))
	number.add_theme_constant_override(&"outline_size", 3)
	number.z_index = 30
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(number)
	number.reset_size()
	number.global_position = at - number.size / 2.0
	var tween := number.create_tween()
	tween.set_parallel(true)
	tween.tween_property(number, "global_position:y", number.global_position.y - RISE_PIXELS, LIFETIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(number, "modulate:a", 0.0, LIFETIME * 0.4).set_delay(LIFETIME * 0.6)
	tween.chain().tween_callback(number.queue_free)
	return number
