extends Node

const TILE_SIZE: int = 16
const BASE_WIDTH: int = 384
const BASE_HEIGHT: int = 216
## UI text size at base resolution; raise with the viewport.
const UI_FONT_SIZE: int = 8

static func tiles(n: float) -> float:
	return n * TILE_SIZE

static func tiles_v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * TILE_SIZE
