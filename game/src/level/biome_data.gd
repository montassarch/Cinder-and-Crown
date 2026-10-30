class_name BiomeData
extends Resource
## One world of a run: from `first_depth` on (until the next world starts) levels wear its art, weather, light
## and enemies. Art lives in `art_dir`: four parallax layers, fog, floor and ledge tiles, a glow and four light frames.

enum Weather { EMBERS, SNOW, ASH, RAIN }

const DIR := "res://data/biomes"

@export var id: String = ""
@export var display_name: String = ""
@export var subtitle: String = ""
@export var first_depth: int = 0
@export var art_dir: String = ""
## The colour behind everything (seen past the far layer's top).
@export var clear_color: Color = Color(0.09, 0.08, 0.11)
@export var weather: Weather = Weather.EMBERS
@export var weather_color: Color = Color(1.0, 0.62, 0.25, 0.9)
## Light sources in the Mid layer (that layer's own pixels; it repeats every 384 px): flames, crystals, furnaces.
@export var light_prefix: String = "flame"
@export var light_x: Array[float] = [96.0, 352.0]
@export var light_y: float = 158.0
@export var light_fps: float = 9.0
## The enemies its waves are drawn from.
@export var enemies: Array[EnemyData] = []


func art_path(name: String) -> String:
	return "%s/%s.png" % [art_dir, name]


## Every world, in the order a run reaches them.
static func load_all() -> Array[BiomeData]:
	var biomes: Array[BiomeData] = []
	for path in DataScanner.list(DIR):
		var biome := load(path) as BiomeData
		if biome != null:
			biomes.append(biome)
	biomes.sort_custom(func(a: BiomeData, b: BiomeData) -> bool: return a.first_depth < b.first_depth)
	return biomes


## The world a level at `depth` belongs to: the last one that has started by then.
static func for_depth(biomes: Array[BiomeData], depth: int) -> BiomeData:
	var found: BiomeData = biomes[0] if not biomes.is_empty() else null
	for biome in biomes:
		if biome.first_depth <= depth:
			found = biome
	return found
