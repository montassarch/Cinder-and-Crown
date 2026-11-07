extends RefCounted
## The dusk-city look: sky, fog, colour grade, bloom, plus the small procedural textures the
## scenery uses. Keeping this in one place makes the whole mood easy to retune.

const WINDOW_COLUMNS: int = 8
const WINDOW_ROWS: int = 16
const WINDOW_CELL_PX: int = 8


static func make_environment() -> Environment:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.03, 0.04, 0.18)
	sky_material.sky_horizon_color = Color(0.80, 0.30, 0.42)
	sky_material.ground_horizon_color = Color(0.55, 0.25, 0.28)
	sky_material.ground_bottom_color = Color(0.03, 0.03, 0.06)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.40, 0.42, 0.70)
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.50, 0.24, 0.42)
	environment.fog_density = 0.0030
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 0.9
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.2
	environment.adjustment_contrast = 1.08
	return environment


static func make_sun() -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-17.0, 38.0, 0.0)
	sun.light_color = Color(1.0, 0.62, 0.38)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 70.0
	return sun


## A dark facade texture with a grid of lit windows. One texture unit spans
## WINDOW_COLUMNS x WINDOW_ROWS windows, so scenery can map it in world units.
static func window_texture() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var width: int = WINDOW_COLUMNS * WINDOW_CELL_PX
	var height: int = WINDOW_ROWS * WINDOW_CELL_PX
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.035, 0.04, 0.07))
	for row in WINDOW_ROWS:
		for column in WINDOW_COLUMNS:
			var roll: float = rng.randf()
			if roll > 0.58:
				continue
			var lit := Color(1.0, 0.78, 0.45) if roll < 0.36 else Color(0.6, 0.8, 1.0)
			if roll > 0.5:
				lit = lit.darkened(0.55)
			for y in range(2, WINDOW_CELL_PX - 2):
				for x in range(2, WINDOW_CELL_PX - 2):
					image.set_pixel(column * WINDOW_CELL_PX + x, row * WINDOW_CELL_PX + y, lit)
	return ImageTexture.create_from_image(image)


## A soft white radial blob, used as an additive light pool on the road.
static func glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
