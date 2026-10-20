class_name HeroBlade
## Where the sword is in every frame of the hero's animations, found by scanning the art
## (guard to tip, in art pixels). Lets effects follow the real blade. Regenerate if the art changes.

const SEGMENTS := {
	&"idle": [Vector4(47.4, 41.5, 39.3, 36.6), Vector4(47.5, 41.1, 39.0, 36.2), Vector4(48.1, 41.2, 40.2, 37.0), Vector4(48.1, 41.5, 40.4, 37.3), Vector4(47.5, 41.5, 39.3, 36.6), Vector4(47.5, 41.1, 39.1, 36.1), Vector4(48.2, 41.2, 40.3, 37.0), Vector4(48.1, 41.5, 40.4, 37.3)],
	&"run": [Vector4(29.9, 34.9, 36.5, 22.8), Vector4(31.6, 36.9, 36.2, 25.5), Vector4(35.2, 35.7, 31.1, 26.2), Vector4(38.7, 33.5, 27.2, 26.5), Vector4(39.9, 34.1, 27.4, 28.0), Vector4(40.3, 36.0, 27.8, 29.5), Vector4(37.5, 39.3, 28.3, 30.2), Vector4(32.1, 36.6, 31.2, 24.2), Vector4(30.6, 33.7, 33.4, 20.9), Vector4(30.0, 33.2, 35.4, 20.6)],
	&"jump": [Vector4(36.1, 48.7, 24.2, 42.7), Vector4(39.7, 30.3, 27.6, 35.3), Vector4(43.2, 33.9, 29.3, 36.7)],
	&"fall": [Vector4(43.2, 33.9, 29.3, 36.7), Vector4(42.6, 34.6, 28.8, 36.3), Vector4(41.8, 34.7, 28.2, 35.8), Vector4(42.3, 34.1, 28.5, 36.4)],
	&"roll": [Vector4(39.3, 47.3, 26.5, 42.9), Vector4(25.9, 32.3, 29.9, 20.0), Vector4(33.1, 49.2, 20.9, 46.7), Vector4(49.6, 55.5, 49.8, 68.6), Vector4(40.3, 47.6, 48.5, 38.5), Vector4(39.9, 48.0, 27.4, 42.5), Vector4(40.8, 44.3, 26.9, 44.5), Vector4(39.9, 40.6, 27.2, 35.5), Vector4(39.2, 39.3, 27.4, 32.4)],
	&"hurt": [Vector4(38.3, 38.9, 30.5, 26.9), Vector4(37.7, 37.9, 29.1, 26.6), Vector4(39.6, 39.7, 27.0, 33.2)],
	&"death": [Vector4(39.3, 39.7, 27.3, 32.6), Vector4(41.4, 39.0, 33.4, 32.5), Vector4(40.5, 40.5, 33.4, 35.4), Vector4(41.6, 42.2, 41.0, 32.4), Vector4(70.6, 47.5, 83.3, 50.8), Vector4(76.7, 56.7, 83.0, 53.3), Vector4(77.3, 59.1, 83.5, 57.0), Vector4(77.4, 59.2, 83.4, 57.1), Vector4(77.4, 59.2, 83.4, 57.1), Vector4(77.4, 59.2, 83.4, 57.1)],
	&"attack1": [Vector4(47.2, 40.8, 38.5, 35.2), Vector4(55.1, 26.0, 46.7, 15.5), Vector4(32.1, 49.9, 28.5, 53.7), Vector4(24.3, 31.3, 24.9, 20.5), Vector4(45.1, 40.2, 33.5, 34.8), Vector4(47.2, 40.8, 38.5, 35.2)],
	&"attack2": [Vector4(47.2, 40.8, 38.5, 35.2), Vector4(45.1, 40.2, 33.5, 34.8), Vector4(24.3, 31.3, 24.9, 20.5), Vector4(32.1, 49.9, 28.5, 53.7), Vector4(55.1, 26.0, 46.7, 15.5), Vector4(47.2, 40.8, 38.5, 35.2)],
	&"attack3": [Vector4(47.2, 40.8, 38.5, 35.2), Vector4(51.7, 30.3, 39.5, 25.0), Vector4(22.8, 45.6, 10.6, 44.9), Vector4(31.4, 49.4, 27.4, 52.7), Vector4(21.8, 34.3, 17.3, 21.4), Vector4(35.1, 39.9, 24.1, 33.5), Vector4(47.5, 40.4, 38.4, 34.9), Vector4(47.2, 40.8, 38.5, 35.2)],
	&"storm": [Vector4(47.2, 40.8, 38.5, 35.2), Vector4(55.1, 26.0, 46.7, 15.5), Vector4(55.1, 26.0, 46.7, 15.5), Vector4(55.1, 26.0, 46.7, 15.5), Vector4(55.1, 26.0, 46.7, 15.5), Vector4(55.1, 26.0, 46.7, 15.5)],
	&"parry": [Vector4(35.1, 39.9, 24.1, 33.5), Vector4(47.5, 40.4, 38.4, 34.9), Vector4(47.5, 40.4, 38.4, 34.9), Vector4(47.5, 40.4, 38.4, 34.9), Vector4(47.5, 40.4, 38.4, 34.9), Vector4(47.2, 40.8, 38.5, 35.2)],
	&"rend": [Vector4(51.7, 30.3, 39.5, 25.0), Vector4(22.8, 45.6, 10.6, 44.9), Vector4(31.4, 49.4, 27.4, 52.7), Vector4(21.8, 34.3, 17.3, 21.4), Vector4(35.1, 39.9, 24.1, 33.5), Vector4(47.5, 40.4, 38.4, 34.9)],
}


## Guard (x, y) and tip (z, w) of the blade for `anim` frame `frame`, in art pixels.
static func segment(anim: StringName, frame: int) -> Vector4:
	var frames: Array = SEGMENTS.get(anim, SEGMENTS[&"idle"])
	return frames[clampi(frame, 0, frames.size() - 1)]
