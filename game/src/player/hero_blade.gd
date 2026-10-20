class_name HeroBlade
## Where the sword is in every frame of the hero's animations, found by scanning the art
## (guard to tip, in art pixels). Lets effects follow the real blade. Regenerate if the art changes.

const SEGMENTS := {
	&"idle": [Vector4(31.5, 46.7, 44.8, 38.7), Vector4(31.5, 46.3, 45.2, 38.2), Vector4(30.8, 46.4, 43.6, 39.5), Vector4(30.8, 46.7, 43.3, 39.8), Vector4(31.5, 46.7, 44.8, 38.7), Vector4(31.5, 46.3, 45.2, 38.2), Vector4(30.7, 46.4, 43.6, 39.5), Vector4(30.8, 46.7, 43.3, 39.8)],
	&"run": [Vector4(51.4, 39.2, 40.7, 19.5), Vector4(49.5, 41.4, 42.1, 23.0), Vector4(45.5, 40.1, 52.1, 24.6), Vector4(41.5, 37.6, 60.2, 26.3), Vector4(40.1, 38.3, 60.5, 28.3), Vector4(39.7, 40.4, 59.9, 29.8), Vector4(42.8, 44.2, 57.9, 29.4), Vector4(49.0, 41.1, 50.5, 21.0), Vector4(50.7, 37.9, 46.1, 16.9), Vector4(51.3, 37.2, 42.6, 16.8)],
	&"jump": [Vector4(44.4, 54.9, 63.8, 45.2), Vector4(40.3, 34.0, 60.1, 42.0), Vector4(36.4, 38.0, 59.0, 42.7)],
	&"fall": [Vector4(36.4, 38.0, 59.0, 42.7), Vector4(37.0, 38.8, 59.6, 41.7), Vector4(38.0, 39.0, 60.1, 40.8), Vector4(37.4, 38.3, 59.8, 42.0)],
	&"roll": [Vector4(40.8, 53.3, 61.6, 46.1), Vector4(56.0, 36.3, 49.5, 16.3), Vector4(47.9, 55.4, 67.6, 51.3), Vector4(29.1, 62.6, 28.7, 84.0), Vector4(39.7, 53.7, 26.4, 38.8), Vector4(40.1, 54.0, 60.5, 45.2), Vector4(39.1, 49.9, 61.6, 50.2), Vector4(40.1, 45.6, 60.8, 37.3), Vector4(40.9, 44.2, 60.1, 33.0)],
	&"hurt": [Vector4(42.0, 43.7, 54.7, 24.3), Vector4(42.6, 42.6, 56.6, 24.1), Vector4(40.4, 44.7, 61.0, 34.0)],
	&"death": [Vector4(40.8, 44.6, 60.3, 33.0), Vector4(38.4, 43.9, 51.4, 33.2), Vector4(39.4, 45.6, 50.9, 37.3), Vector4(38.1, 47.5, 39.2, 31.5), Vector4(5.2, 53.5, -15.4, 58.8), Vector4(-1.7, 63.9, -12.0, 58.4), Vector4(-2.3, 66.7, -12.5, 63.2), Vector4(-2.4, 66.8, -12.3, 63.4), Vector4(-2.4, 66.8, -12.2, 63.4), Vector4(-2.4, 66.8, -12.2, 63.4)],
	&"attack1": [Vector4(31.8, 45.9, 45.9, 36.8), Vector4(22.9, 29.1, 36.5, 12.1), Vector4(49.0, 56.2, 54.7, 62.5), Vector4(57.9, 35.1, 56.9, 17.6), Vector4(34.2, 45.3, 53.0, 36.5), Vector4(31.8, 45.9, 45.9, 36.8)],
	&"attack2": [Vector4(31.8, 45.9, 45.9, 36.8), Vector4(34.2, 45.3, 53.0, 36.5), Vector4(57.9, 35.1, 56.9, 17.6), Vector4(49.0, 56.2, 54.7, 62.5), Vector4(22.9, 29.1, 36.5, 12.1), Vector4(31.8, 45.9, 45.9, 36.8)],
	&"attack3": [Vector4(31.8, 45.9, 45.9, 36.8), Vector4(26.7, 33.9, 46.6, 25.4), Vector4(59.5, 51.3, 79.3, 50.3), Vector4(49.8, 55.7, 56.4, 61.1), Vector4(60.7, 38.5, 68.1, 17.5), Vector4(45.6, 44.9, 63.4, 34.4), Vector4(31.4, 45.5, 46.3, 36.4), Vector4(31.8, 45.9, 45.9, 36.8)],
	&"storm": [Vector4(31.8, 45.9, 45.9, 36.8), Vector4(22.9, 29.1, 36.5, 12.1), Vector4(22.9, 29.1, 36.5, 12.1), Vector4(22.9, 29.1, 36.5, 12.1), Vector4(22.9, 29.1, 36.5, 12.1), Vector4(22.9, 29.1, 36.5, 12.1)],
	&"parry": [Vector4(45.6, 44.9, 63.4, 34.4), Vector4(31.4, 45.5, 46.3, 36.4), Vector4(31.4, 45.5, 46.3, 36.4), Vector4(31.4, 45.5, 46.3, 36.4), Vector4(31.4, 45.5, 46.3, 36.4), Vector4(31.8, 45.9, 45.9, 36.8)],
	&"rend": [Vector4(26.7, 33.9, 46.6, 25.4), Vector4(59.5, 51.3, 79.3, 50.3), Vector4(49.8, 55.7, 56.4, 61.1), Vector4(60.7, 38.5, 68.1, 17.5), Vector4(45.6, 44.9, 63.4, 34.4), Vector4(31.4, 45.5, 46.3, 36.4)],
}


## Guard (x, y) and tip (z, w) of the blade for `anim` frame `frame`, in art pixels.
static func segment(anim: StringName, frame: int) -> Vector4:
	var frames: Array = SEGMENTS.get(anim, SEGMENTS[&"idle"])
	return frames[clampi(frame, 0, frames.size() - 1)]
