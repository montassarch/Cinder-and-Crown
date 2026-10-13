class_name Damage
extends RefCounted

## Pure damage arithmetic. No engine access, no state.
##
## Every clamp here guards against a badly authored data file: a weapon
## .tres with a negative damage value, an enemy with negative defense, a
## multiplier someone typed as -2 instead of 2. None of those may ever
## turn an attack into healing.


## Applies the multiplier to base, subtracts defense, floors the result,
## and clamps to zero. Returns damage that is always >= 0.
static func compute(base: int, multiplier: float, defense: int) -> int:
	var scaled := float(maxi(base, 0)) * maxf(multiplier, 0.0)
	return maxi(floori(scaled) - maxi(defense, 0), 0)
