extends Resource
## One car's real-world figures plus the rules that turn them into game handling.
## Figures are manufacturer claims (see source_note); the game numbers are derived, never typed in.

## 1 real m/s = this many game m/s. Keeps a 350 km/h car at a playable ~45 m/s on a ~1 km lap.
const SPEED_SCALE: float = 0.47
## A car that does 0-100 km/h in this many seconds gets exactly BASE_ACCEL.
const REFERENCE_ZERO_TO_100: float = 2.7
const BASE_ACCEL: float = 24.0

@export var id: String = ""
@export var display_name: String = ""
@export var make: String = ""
@export var year: int = 2025
@export var power_hp: int = 0
@export var zero_to_100_s: float = 3.0
@export var top_speed_kmh: float = 300.0
@export_enum("AWD", "RWD") var drivetrain: String = "AWD"
@export_file("*.glb") var model_path: String = ""
@export_multiline var source_note: String = ""


func game_top_speed() -> float:
	return top_speed_kmh / 3.6 * SPEED_SCALE


func game_accel() -> float:
	return BASE_ACCEL * REFERENCE_ZERO_TO_100 / zero_to_100_s


## All-wheel drive grips harder and is more forgiving; rear-wheel drive slides more easily.
func game_grip() -> float:
	return 10.0 if drivetrain == "AWD" else 8.4


func game_drift_grip() -> float:
	return 2.8 if drivetrain == "AWD" else 2.1


func summary() -> String:
	return "%s %s  %d hp  0-100 %.2f s  %d km/h  %s" % [make, display_name, power_hp, zero_to_100_s, roundi(top_speed_kmh), drivetrain]
