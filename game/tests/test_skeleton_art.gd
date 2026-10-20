extends GdUnitTestSuite
## The hero's art must face the way he moves: right when facing +1, left when facing -1.
## Measured on the frame as the player would see it (flip included): the bone-white skull sits
## in front of the hood's centre, so its side tells which way he looks.

const State := PlayerStateMachine.PlayerState


func _visual() -> PlayerVisual:
	var visual: PlayerVisual = auto_free(PlayerVisual.new())
	add_child(visual)
	return visual


## +1 if the skull is right of the hood centre in the displayed image, -1 if left, 0 if no skull pixels.
func _skull_side(visual: PlayerVisual) -> int:
	var img := visual.frame_image(visual.animation, visual.frame, false)
	var w := img.get_width()
	var top := img.get_height()
	var bottom := 0
	for y in img.get_height():
		for x in w:
			if img.get_pixel(x, y).a > 0.0:
				top = mini(top, y)
				bottom = maxi(bottom, y)
	var head_rows := top + int((bottom - top) * 0.3)
	var head_sum := 0.0
	var head_count := 0
	var skull_sum := 0.0
	var skull_count := 0
	for y in range(top, head_rows + 1):
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var shown_x := (w - 1 - x) if visual.flip_h else x
			head_sum += shown_x
			head_count += 1
			if minf(c.r, minf(c.g, c.b)) >= 0.55:
				skull_sum += shown_x
				skull_count += 1
	if skull_count == 0 or head_count == 0:
		return 0
	return 1 if skull_sum / skull_count > head_sum / head_count else -1


func test_facing_right_shows_the_skull_on_the_right() -> void:
	for state in [State.IDLE, State.RUN, State.HURT]:
		var visual := _visual()
		visual.show_state(state, 1.0, 0.0, 0.0)
		visual.frame = 0
		assert_int(_skull_side(visual)).is_equal(1)


func test_facing_left_shows_the_skull_on_the_left() -> void:
	for state in [State.IDLE, State.RUN, State.HURT]:
		var visual := _visual()
		visual.show_state(state, -1.0, 0.0, 0.0)
		visual.frame = 0
		assert_int(_skull_side(visual)).is_equal(-1)
