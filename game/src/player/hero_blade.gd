class_name HeroBlade
## Where the sword is in every frame of the hero's animations, found by scanning the art
## (guard to tip, in art pixels). Lets effects follow the real blade. Regenerate if the art changes.

const SEGMENTS := {
	&"idle": [Vector4(48.5, 46.7, 35.2, 38.7), Vector4(48.5, 46.3, 34.8, 38.2), Vector4(49.2, 46.4, 36.4, 39.5), Vector4(49.2, 46.7, 36.7, 39.8), Vector4(48.5, 46.7, 35.2, 38.7), Vector4(48.5, 46.3, 34.8, 38.2), Vector4(49.3, 46.4, 36.4, 39.5), Vector4(49.2, 46.7, 36.7, 39.8)],
	&"run": [Vector4(28.6, 39.2, 39.3, 19.5), Vector4(30.5, 41.4, 37.9, 23.0), Vector4(34.5, 40.1, 27.9, 24.6), Vector4(38.5, 37.6, 19.8, 26.3), Vector4(39.9, 38.3, 19.5, 28.3), Vector4(40.3, 40.4, 20.1, 29.8), Vector4(37.2, 44.2, 22.1, 29.4), Vector4(31.0, 41.1, 29.5, 21.0), Vector4(29.3, 37.9, 33.9, 16.9), Vector4(28.7, 37.2, 37.4, 16.8)],
	&"jump": [Vector4(35.6, 54.9, 16.2, 45.2), Vector4(39.7, 34.0, 19.9, 42.0), Vector4(43.6, 38.0, 21.0, 42.7)],
	&"fall": [Vector4(43.6, 38.0, 21.0, 42.7), Vector4(43.0, 38.8, 20.4, 41.7), Vector4(42.0, 39.0, 19.9, 40.8), Vector4(42.6, 38.3, 20.2, 42.0)],
	&"roll": [Vector4(39.2, 53.3, 18.4, 46.1), Vector4(24.0, 36.3, 30.5, 16.3), Vector4(32.1, 55.4, 12.4, 51.3), Vector4(50.9, 62.6, 51.3, 84.0), Vector4(40.3, 53.7, 53.6, 38.8), Vector4(39.9, 54.0, 19.5, 45.2), Vector4(40.9, 49.9, 18.4, 50.2), Vector4(39.9, 45.6, 19.2, 37.3), Vector4(39.1, 44.2, 19.9, 33.0)],
	&"hurt": [Vector4(38.0, 43.7, 25.3, 24.3), Vector4(37.4, 42.6, 23.4, 24.1), Vector4(39.6, 44.7, 19.0, 34.0)],
	&"death": [Vector4(39.2, 44.6, 19.7, 33.0), Vector4(41.6, 43.9, 28.6, 33.2), Vector4(40.6, 45.6, 29.1, 37.3), Vector4(41.9, 47.5, 40.8, 31.5), Vector4(74.8, 53.5, 95.4, 58.8), Vector4(81.7, 63.9, 92.0, 58.4), Vector4(82.3, 66.7, 92.5, 63.2), Vector4(82.4, 66.8, 92.3, 63.4), Vector4(82.4, 66.8, 92.2, 63.4), Vector4(82.4, 66.8, 92.2, 63.4)],
	&"attack1": [Vector4(48.2, 45.9, 34.1, 36.8), Vector4(57.1, 29.1, 43.5, 12.1), Vector4(31.0, 56.2, 25.3, 62.5), Vector4(22.1, 35.1, 23.1, 17.6), Vector4(45.8, 45.3, 27.0, 36.5), Vector4(48.2, 45.9, 34.1, 36.8)],
	&"attack2": [Vector4(48.2, 45.9, 34.1, 36.8), Vector4(45.8, 45.3, 27.0, 36.5), Vector4(22.1, 35.1, 23.1, 17.6), Vector4(31.0, 56.2, 25.3, 62.5), Vector4(57.1, 29.1, 43.5, 12.1), Vector4(48.2, 45.9, 34.1, 36.8)],
	&"attack3": [Vector4(48.2, 45.9, 34.1, 36.8), Vector4(53.3, 33.9, 33.4, 25.4), Vector4(20.5, 51.3, 0.7, 50.3), Vector4(30.2, 55.7, 23.6, 61.1), Vector4(19.3, 38.5, 11.9, 17.5), Vector4(34.4, 44.9, 16.6, 34.4), Vector4(48.6, 45.5, 33.7, 36.4), Vector4(48.2, 45.9, 34.1, 36.8)],
	&"storm": [Vector4(48.2, 45.9, 34.1, 36.8), Vector4(57.1, 29.1, 43.5, 12.1), Vector4(57.1, 29.1, 43.5, 12.1), Vector4(57.1, 29.1, 43.5, 12.1), Vector4(57.1, 29.1, 43.5, 12.1), Vector4(57.1, 29.1, 43.5, 12.1)],
	&"parry": [Vector4(34.4, 44.9, 16.6, 34.4), Vector4(48.6, 45.5, 33.7, 36.4), Vector4(48.6, 45.5, 33.7, 36.4), Vector4(48.6, 45.5, 33.7, 36.4), Vector4(48.6, 45.5, 33.7, 36.4), Vector4(48.2, 45.9, 34.1, 36.8)],
	&"rend": [Vector4(53.3, 33.9, 33.4, 25.4), Vector4(20.5, 51.3, 0.7, 50.3), Vector4(30.2, 55.7, 23.6, 61.1), Vector4(19.3, 38.5, 11.9, 17.5), Vector4(34.4, 44.9, 16.6, 34.4), Vector4(48.6, 45.5, 33.7, 36.4)],
}


## Guard (x, y) and tip (z, w) of the blade for `anim` frame `frame`, in art pixels.
static func segment(anim: StringName, frame: int) -> Vector4:
	var frames: Array = SEGMENTS.get(anim, SEGMENTS[&"idle"])
	return frames[clampi(frame, 0, frames.size() - 1)]
