extends Node

## Brief global slowdown on a landed hit.
##
## This is most of what makes a hit feel like contact rather than a number
## changing. Dead Cells freezes for a few frames on impact; the duration is
## per-weapon, so a heavy spear lands heavier than a quick blade.
##
## Implemented as a slowdown rather than a true freeze so animations do not
## visibly snap, and the timer ignores time_scale -- otherwise scaling time
## down would also stretch the timer that is meant to undo it.

## How far time slows during the stop. Not zero: a hard freeze reads as a
## stutter or a dropped frame rather than as impact.
const FREEZE_SCALE: float = 0.05

var _frozen: bool = false


func is_frozen() -> bool:
	return _frozen


## Slows time for `seconds` of real time. Nested calls are ignored rather
## than stacked, so three enemies hit on one frame do not triple the stop.
func freeze(seconds: float) -> void:
	if seconds <= 0.0 or _frozen:
		return
	_frozen = true
	Engine.time_scale = FREEZE_SCALE
	# process_always = true, process_in_physics = false, ignore_time_scale = true
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
	_frozen = false
