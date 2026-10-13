class_name EnemyData
extends Resource

## One enemy type, as data. A fourth enemy is a new .tres file under
## data/enemies/ -- never a new branch in code. `behaviour` picks a movement
## strategy from the enum below, which is the only thing Enemy switches on.
##
## Every spatial field is in TILES, per the project's resolution rule.

enum Behaviour {
	## Walks along the ground toward the player.
	CHASER,
	## Ignores gravity and drifts toward the player.
	FLYER,
	## Winds up, then commits to a straight-line rush.
	CHARGER,
}

@export var display_name: String = "Unnamed Enemy"

@export var max_health: int = 30

## Movement speed in tiles/second.
@export var move_speed_tiles: float = 3.0

@export var attack_damage: int = 10

## How close the player must be before this enemy starts winding up.
@export var attack_range_tiles: float = 1.2

## Wind-up before the strike lands. This is the player's entire warning,
## so it must never be zero -- an unreadable hit reads as unfair rather
## than difficult. Heavier enemies should telegraph longer.
@export var telegraph_seconds: float = 0.6

## Pause after striking, during which the enemy is punishable. This is the
## window the player is meant to attack into.
@export var recovery_seconds: float = 0.5

@export var behaviour: Behaviour = Behaviour.CHASER

## Placeholder body size in tiles, until real art exists.
@export var body_size_tiles: Vector2 = Vector2(1.0, 2.0)

## Placeholder colour, so the three types are distinguishable on screen.
@export var tint: Color = Color(0.8, 0.3, 0.3)
