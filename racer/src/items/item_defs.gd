extends RefCounted
## The seven items: their names, neon colours and balance numbers in one place.

enum Kind { NONE, NITRO, BOLT, SHUNT, MINE, SHOCK, BARGE, REPAIR }

const SLOT_COUNT: int = 3

## damage = health removed, stun = seconds the victim loses control.
const DEFINITIONS: Dictionary = {
	Kind.NITRO: {"name": "NITRO", "color": Color(1.0, 0.55, 0.10)},
	Kind.BOLT: {"name": "BOLT", "color": Color(1.0, 0.95, 0.30), "damage": 12.0, "stun": 0.5, "speed": 100.0},
	Kind.SHUNT: {"name": "SHUNT", "color": Color(1.0, 0.25, 0.20), "damage": 25.0, "stun": 1.6, "speed": 72.0},
	Kind.MINE: {"name": "MINE", "color": Color(0.95, 0.15, 0.55), "damage": 20.0, "stun": 1.4},
	Kind.SHOCK: {"name": "SHOCK", "color": Color(0.45, 0.70, 1.00), "damage": 8.0, "stun": 1.0, "radius": 35.0},
	Kind.BARGE: {"name": "BARGE", "color": Color(0.30, 1.00, 0.85), "seconds": 4.0, "ram_damage": 10.0, "ram_stun": 0.8},
	Kind.REPAIR: {"name": "REPAIR", "color": Color(0.35, 1.00, 0.35), "heal": 50.0},
}

const ALL_KINDS: Array[int] = [Kind.NITRO, Kind.BOLT, Kind.SHUNT, Kind.MINE, Kind.SHOCK, Kind.BARGE, Kind.REPAIR]


static func item_name(kind: int) -> String:
	return "" if kind == Kind.NONE else DEFINITIONS[kind]["name"]


static func color(kind: int) -> Color:
	return Color(0.6, 0.6, 0.6) if kind == Kind.NONE else DEFINITIONS[kind]["color"]


static func value(kind: int, key: String) -> float:
	return float(DEFINITIONS[kind][key])
