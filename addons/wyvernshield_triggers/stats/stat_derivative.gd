class_name StatDerivative
extends Resource

enum RoundingMode {
	NONE,
	FLOOR,
	NEAREST,
	CEILING,
}

## The base stat to base the derivative stats on.
@export var source_stat : StringName
## The [enum RoundingMode] to apply to [member source_stat] before applying derivatives.
@export var source_rounding_mode : RoundingMode
## The stat modification to apply, multiplied by [member source_stat].
@export var derivative_stats : StatModification

## Apply a [enum RoundingMode] to a number.
static func use_rounding_mode(value : float, rounding_mode : RoundingMode) -> float:
	match rounding_mode:
		RoundingMode.NONE:
			return value
		RoundingMode.FLOOR:
			return floorf(value)
		RoundingMode.NEAREST:
			return roundf(value)
		RoundingMode.CEILING:
			return ceilf(value)

	return value

## Apply this stat conversion.
func apply(to_sheet : StatSheet, source_sheet : StatSheet):
	derivative_stats.apply(to_sheet, use_rounding_mode(
		source_sheet._toplevel_stats.get(source_stat, 0.0),
		source_rounding_mode
	))
