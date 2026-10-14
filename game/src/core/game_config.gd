extends Node

const TILE_SIZE: int = 16
const BASE_WIDTH: int = 384
const BASE_HEIGHT: int = 216

static func tiles(n: float) -> float:
	return n * TILE_SIZE

static func tiles_v(x: float, y: float) -> Vector2:
	return Vector2(x, y) * TILE_SIZE
