class_name HeroBlade
## Where the sword is in every frame of the hero's animations, found by scanning the art
## (guard to tip, in art pixels). Lets effects follow the real blade. Regenerate if the art changes.

const SEGMENTS := {
	&"idle": [Vector4(48.5, 46.7, 39.2, 41.1), Vector4(48.5, 46.3, 38.9, 40.6), Vector4(49.2, 46.4, 40.3, 41.6), Vector4(49.2, 46.7, 40.5, 41.9), Vector4(48.5, 46.7, 39.2, 41.1), Vector4(48.5, 46.3, 38.9, 40.6), Vector4(49.3, 46.4, 40.3, 41.6), Vector4(49.2, 46.7, 40.5, 41.9)],
	&"run": [Vector4(28.6, 39.2, 36.0, 25.5), Vector4(30.5, 41.4, 35.7, 28.5), Vector4(34.5, 40.1, 29.9, 29.3), Vector4(38.5, 37.6, 25.4, 29.7), Vector4(39.9, 38.3, 25.6, 31.3), Vector4(40.3, 40.4, 26.2, 33.0), Vector4(37.2, 44.2, 26.7, 33.9), Vector4(31.0, 41.1, 30.0, 27.1), Vector4(29.3, 37.9, 32.6, 23.2), Vector4(28.7, 37.2, 34.8, 22.9)],
	&"jump": [Vector4(35.6, 54.9, 22.0, 48.1), Vector4(39.7, 34.0, 25.9, 39.6), Vector4(43.6, 38.0, 27.8, 41.3)],
	&"fall": [Vector4(43.6, 38.0, 27.8, 41.3), Vector4(43.0, 38.8, 27.2, 40.8), Vector4(42.0, 39.0, 26.6, 40.2), Vector4(42.6, 38.3, 26.9, 40.9)],
	&"roll": [Vector4(39.2, 53.3, 24.7, 48.3), Vector4(24.0, 36.3, 28.5, 22.3), Vector4(32.1, 55.4, 18.3, 52.6), Vector4(50.9, 62.6, 51.1, 77.5), Vector4(40.3, 53.7, 49.6, 43.3), Vector4(39.9, 54.0, 25.6, 47.9), Vector4(40.9, 49.9, 25.1, 50.1), Vector4(39.9, 45.6, 25.4, 39.8), Vector4(39.1, 44.2, 25.6, 36.4)],
	&"hurt": [Vector4(38.0, 43.7, 29.2, 30.2), Vector4(37.4, 42.6, 27.6, 29.7), Vector4(39.6, 44.7, 25.2, 37.2)],
	&"death": [Vector4(39.2, 44.6, 25.6, 36.5), Vector4(41.6, 43.9, 32.5, 36.4), Vector4(40.6, 45.6, 32.6, 39.8), Vector4(41.9, 47.5, 41.1, 36.3), Vector4(74.8, 53.5, 89.2, 57.2), Vector4(81.7, 63.9, 88.9, 60.1), Vector4(82.3, 66.7, 89.4, 64.3), Vector4(82.4, 66.8, 89.3, 64.5), Vector4(82.4, 66.8, 89.3, 64.4), Vector4(82.4, 66.8, 89.3, 64.4)],
	&"attack1": [Vector4(48.2, 45.9, 38.3, 39.5), Vector4(57.1, 29.1, 47.6, 17.2), Vector4(31.0, 56.2, 27.0, 60.6), Vector4(22.1, 35.1, 22.8, 22.9), Vector4(45.8, 45.3, 32.6, 39.1), Vector4(48.2, 45.9, 38.3, 39.5)],
	&"attack2": [Vector4(48.2, 45.9, 38.3, 39.5), Vector4(45.8, 45.3, 32.6, 39.1), Vector4(22.1, 35.1, 22.8, 22.9), Vector4(31.0, 56.2, 27.0, 60.6), Vector4(57.1, 29.1, 47.6, 17.2), Vector4(48.2, 45.9, 38.3, 39.5)],
	&"attack3": [Vector4(48.2, 45.9, 38.3, 39.5), Vector4(53.3, 33.9, 39.4, 28.0), Vector4(20.5, 51.3, 6.6, 50.6), Vector4(30.2, 55.7, 25.6, 59.5), Vector4(19.3, 38.5, 14.2, 23.8), Vector4(34.4, 44.9, 22.0, 37.6), Vector4(48.6, 45.5, 38.2, 39.2), Vector4(48.2, 45.9, 38.3, 39.5)],
	&"storm": [Vector4(48.2, 45.9, 38.3, 39.5), Vector4(57.1, 29.1, 47.6, 17.2), Vector4(57.1, 29.1, 47.6, 17.2), Vector4(57.1, 29.1, 47.6, 17.2), Vector4(57.1, 29.1, 47.6, 17.2), Vector4(57.1, 29.1, 47.6, 17.2)],
	&"parry": [Vector4(34.4, 44.9, 22.0, 37.6), Vector4(48.6, 45.5, 38.2, 39.2), Vector4(48.6, 45.5, 38.2, 39.2), Vector4(48.6, 45.5, 38.2, 39.2), Vector4(48.6, 45.5, 38.2, 39.2), Vector4(48.2, 45.9, 38.3, 39.5)],
	&"rend": [Vector4(53.3, 33.9, 39.4, 28.0), Vector4(20.5, 51.3, 6.6, 50.6), Vector4(30.2, 55.7, 25.6, 59.5), Vector4(19.3, 38.5, 14.2, 23.8), Vector4(34.4, 44.9, 22.0, 37.6), Vector4(48.6, 45.5, 38.2, 39.2)],
}


## Guard (x, y) and tip (z, w) of the blade for `anim` frame `frame`, in art pixels.
static func segment(anim: StringName, frame: int) -> Vector4:
	var frames: Array = SEGMENTS.get(anim, SEGMENTS[&"idle"])
	return frames[clampi(frame, 0, frames.size() - 1)]
