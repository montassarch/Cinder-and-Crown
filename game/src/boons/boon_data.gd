class_name BoonData
extends Resource
## One file per boon: a permanent upgrade offered after clearing a level and kept
## until the run ends. Adding a .tres to data/boons is all it takes to add one.

enum Effect { MAX_HEALTH, HEAL, DAMAGE, SPEED, LIFESTEAL, MANA_GAIN, FLASK_CHARGE }
enum Rarity { COMMON, RARE, EPIC }

## Matches the file name.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effect: Effect = Effect.DAMAGE
## MAX_HEALTH and HEAL: hit points. LIFESTEAL: hit points per sword hit. FLASK_CHARGE: flask charges.
## DAMAGE, SPEED, MANA_GAIN: fraction added to the multiplier (0.15 = +15%).
@export var amount: float = 0.0
@export var rarity: Rarity = Rarity.COMMON
## A unique boon leaves the pool once taken.
@export var unique: bool = false
