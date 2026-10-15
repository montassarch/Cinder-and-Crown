class_name HeroBlade
## Where the sword is in every frame of the hero's animations, found by scanning the art
## (guard to tip, in art pixels). Lets effects follow the real blade. Regenerate if the art changes.

const SEGMENTS := {
	&"idle": [Vector4(36.0, 37.3, 18.5, 44.5), Vector4(35.0, 37.3, 17.5, 44.5), Vector4(34.0, 38.3, 16.5, 45.5), Vector4(34.0, 38.3, 16.5, 45.5), Vector4(34.0, 37.3, 16.5, 44.5), Vector4(35.0, 37.3, 17.5, 44.5), Vector4(36.0, 38.3, 18.5, 45.5), Vector4(36.0, 38.3, 18.5, 45.5)],
	&"run": [Vector4(36.0, 37.3, 18.5, 46.5), Vector4(35.0, 36.3, 17.5, 45.5), Vector4(35.0, 36.3, 17.5, 45.5), Vector4(34.0, 36.3, 16.5, 45.5), Vector4(34.0, 36.3, 16.5, 45.5), Vector4(35.0, 36.3, 17.5, 45.5), Vector4(35.0, 36.3, 17.5, 45.5), Vector4(35.0, 36.3, 17.5, 45.5), Vector4(35.0, 36.3, 17.5, 45.5), Vector4(35.0, 37.3, 17.5, 46.5)],
	&"jump": [Vector4(36.0, 39.3, 18.5, 48.5), Vector4(36.0, 38.3, 18.5, 47.5), Vector4(36.0, 36.3, 18.5, 45.5)],
	&"fall": [Vector4(35.0, 35.3, 17.5, 44.5), Vector4(35.0, 35.3, 17.5, 44.5), Vector4(35.0, 35.3, 17.5, 44.5), Vector4(35.0, 35.3, 17.5, 44.5)],
	&"roll": [Vector4(47.8, 39.2, 66.5, 44.5), Vector4(58.1, 50.2, 80.5, 51.5), Vector4(53.3, 50.2, 75.5, 51.5), Vector4(43.1, 44.2, 58.5, 52.5), Vector4(47.8, 32.3, 40.5, 49.5), Vector4(59.9, 37.8, 44.5, 30.5), Vector4(54.2, 49.7, 61.5, 33.5), Vector4(43.9, 48.4, 60.5, 52.5), Vector4(41.0, 39.3, 23.5, 48.5)],
	&"hurt": [Vector4(34.0, 37.3, 16.5, 44.5), Vector4(34.0, 37.3, 16.5, 44.5), Vector4(35.0, 37.3, 17.5, 44.5)],
	&"death": [Vector4(35.1, 38.1, 17.5, 45.5), Vector4(35.1, 38.1, 17.5, 45.5), Vector4(37.4, 47.0, 19.5, 52.5), Vector4(37.5, 51.1, 15.5, 49.5), Vector4(36.7, 48.4, 14.5, 50.5), Vector4(34.1, 51.1, 12.5, 52.5), Vector4(34.1, 51.1, 12.5, 52.5), Vector4(34.1, 51.1, 12.5, 52.5), Vector4(34.1, 51.1, 12.5, 52.5), Vector4(34.1, 51.1, 12.5, 52.5)],
	&"attack1": [Vector4(37.3, 18.2, 21.5, 26.5), Vector4(58.4, 9.8, 37.5, 12.5), Vector4(40.0, 35.3, 22.5, 42.5), Vector4(40.0, 34.3, 22.5, 41.5), Vector4(43.0, 34.3, 25.5, 41.5), Vector4(57.6, 33.6, 57.5, 22.5)],
	&"attack2": [Vector4(59.5, 20.0, 61.5, 37.5), Vector4(31.4, 17.4, 11.5, 14.5), Vector4(31.4, 16.4, 11.5, 13.5), Vector4(31.4, 16.4, 11.5, 13.5), Vector4(31.6, 28.1, 10.5, 29.5), Vector4(31.0, 33.5, 14.5, 38.5)],
	&"attack3": [Vector4(35.3, 20.2, 19.5, 28.5), Vector4(56.7, 10.0, 35.5, 12.5), Vector4(71.2, 43.3, 89.5, 50.5), Vector4(70.2, 43.5, 88.5, 52.5), Vector4(70.2, 43.5, 97.5, 44.5), Vector4(70.2, 43.5, 88.5, 52.5), Vector4(57.2, 40.5, 75.5, 49.5), Vector4(38.0, 37.3, 20.5, 44.5)],
	&"storm": [Vector4(37.3, 18.2, 21.5, 26.5), Vector4(58.4, 9.8, 37.5, 12.5), Vector4(58.4, 9.8, 37.5, 12.5), Vector4(58.4, 9.8, 37.5, 12.5), Vector4(58.4, 9.8, 37.5, 12.5), Vector4(58.4, 9.8, 37.5, 12.5)],
	&"rend": [Vector4(56.7, 10.0, 35.5, 12.5), Vector4(71.2, 43.3, 89.5, 50.5), Vector4(70.2, 43.5, 88.5, 52.5), Vector4(70.2, 43.5, 97.5, 44.5), Vector4(70.2, 43.5, 88.5, 52.5), Vector4(57.2, 40.5, 75.5, 49.5)],
}


## Guard (x, y) and tip (z, w) of the blade for `anim` frame `frame`, in art pixels.
static func segment(anim: StringName, frame: int) -> Vector4:
	var frames: Array = SEGMENTS.get(anim, SEGMENTS[&"idle"])
	return frames[clampi(frame, 0, frames.size() - 1)]
