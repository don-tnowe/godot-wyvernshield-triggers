@tool
@icon("res://addons/wyvernshield_triggers/icons/stat_modification.svg")
class_name StatModification
extends Resource

## Stores a collection of stat modifications.

## The type of a stat modification.
enum Type {
	BASE = 0, ## Base stat, added together before other calculations.
	PERCENT_CHANGE, ## Percent increase/decrease, added together to then modify base.
	PERCENT_MAGNITUDE, ## Multiplier of percent changes, MULTIPLIED together.
	MULTIPLIER, ## Multiplier of total value, MULTIPLIED together.
	FLAT_BONUS, ## Flat bonus, added to the value [b]after[/b] all multipliers.
	_5, ## Currently unused. If you have ideas, open an issue on https://github.com/don-tnowe/godot-wyvernshield-triggers/issues
	LOWER_LIMIT, ## Lower limit of the resulting value. The highest modification will be applied.
	UPPER_LIMIT, ## Upper limit of the resulting value. The lowest modification will be applied.
	MAX ## The size of the enumeration.
}

## The character to append to the end of a string. use with [method StatSheet.set_suffixed]. Also see [enum Type].
const type_suffix = {
	Type.BASE : "+",
	Type.PERCENT_CHANGE : "%",
	Type.PERCENT_MAGNITUDE : "$",
	Type.MULTIPLIER : "*",
	Type.FLAT_BONUS : "&",
	Type._5 : "'",
	Type.LOWER_LIMIT : "^",
	Type.UPPER_LIMIT : "_",
}

## The path where the stat changes will be stored. Path units are separated by [code]/[/code], like in a file or node path.
## Group changes by paths so they can be removed together, and recalculate faster.
@export var at_path := &"":
	set(v):
		at_path = v
		_update_name()

## The amount of change. All stat modifications are multiplied by this.
@export var magnitude := 1.0

## If not [code]0[/code], the stat modification will be temporary, and cleared after this many seconds.
@export var expires_in := 0.0:
	set(v):
		expires_in = max(v, 0)
		_update_name()

## If [code]true[/code], adds a unique number to the path, so that if a modification with the same [member at_path] was already applied, it is still applied independently.
@export var non_repeat := false

## Names of modified stats.
var stat_names : Array[StringName] = []
## Values of modified stats.
var stat_values : Array[float] = []
## Modification types of modified stats. See [enum Type].
var stat_modification_types : Array[Type] = []


func _init():
	at_path = &"init"  # Triggers setter.


## Applies modifications. Overrides modifications at [member at_path]. [br]
## The [code]with_magnitude[/code] parameter will be multiplied by this object's [member magnitude]. [br]
## Returns the path applied to, which may differ if [member non_repeat] is set, to then remove it using [method StatSheet.clear]. [br]
func apply(to: StatSheet, with_magnitude : float = 1.0) -> StringName:
	var applied_path = to.get_non_repeating_path(at_path) if non_repeat else at_path
	for i in stat_names.size():
		var new_value := 0.0

		if stat_modification_types[i] <= Type.PERCENT_CHANGE:
			new_value = stat_values[i] * magnitude * with_magnitude

		else:
			new_value = (stat_values[i] - 1.0) * magnitude * with_magnitude + 1.0

		to.set_stat(stat_names[i], new_value, applied_path, stat_modification_types[i])

	if expires_in != 0.0:
		to.clear_timed(applied_path, expires_in)

	return applied_path

## Creates a new StatModification that combines entries from both sources. Path and other meta-properties are taken from the resource this method was called on.
func merge(with : StatModification) -> StatModification:
	var result := duplicate()
	result.stat_names = stat_names + with.stat_names
	result.stat_values = stat_values + with.stat_values
	result.stat_modification_types = stat_modification_types + with.stat_modification_types
	return result


## Returns a copy of this modification, but with [member magnitude] multiplied by a value.
## If you only need to apply magnitude once, use [method apply] with the [code]with_magnitude[/code] parameter set.
func with_magnitude(multiplier : float) -> StatModification:
	var new_instance : StatModification = duplicate()
	new_instance.magnitude *= multiplier
	return new_instance

## Returns a copy of this modification that will be cleared after a certain amount of time, in seconds.
func with_timer(time : float) -> StatModification:
	var new_instance : StatModification = duplicate()
	new_instance.expires_in = time
	return new_instance

## Returns a dictionary, to use with [method StatSheet.set_from_dict].
func to_dict() -> Dictionary:
	var dict := {}
	for i in stat_names.size():
		dict[stat_names[i] + type_suffix[stat_modification_types[i]]] = stat_values[i]

	return dict

## Returns a new stat modification resource created from a dicitonary. See [member type_suffix] and [enum Type].
static func from_dict(dict : Dictionary, with_at_path : StringName = &".", with_magnitude : float = 1.0, with_expires_in : float = 0.0, with_non_repeat : bool = false):
	var result := StatModification.new()
	result.at_path = with_at_path
	result.magnitude = with_magnitude
	result.expires_in = with_expires_in
	result.non_repeat = with_non_repeat
	for k in dict:
		result.stat_values.append(dict[k])

		var len : int = k.length() - 1
		var suffix_char := StatSheet._modification_suffix.get(k.unicode_at(len), -1)
		if suffix_char == -1:
			result.stat_names.append(k)
			result.stat_modification_types.append(Type.BASE)
			continue

		result.stat_names.append(k.left(len))
		result.stat_modification_types.append(suffix_char)


func _update_name():
	var new_name := ""
	new_name = "./%s (%s)" % [at_path, stat_names.size()]
	if expires_in > 0:
		new_name += " (%.2fs)" % [expires_in]

	resource_name = new_name


func _set(property : StringName, value) -> bool:
	if property == "stat_count":
		stat_names.resize(value)
		stat_values.resize(value)
		stat_modification_types.resize(value)
		for i in stat_names.size():
			if ! stat_names[i] is StringName:
				stat_names[i] = &""

			if ! stat_values[i] is float:
				stat_values[i] = 0.0

			if ! stat_modification_types[i] is int:
				stat_modification_types[i] = Type.BASE

		notify_property_list_changed()
		_update_name()
		return true

	elif property.begins_with("stat_"):
		var name_split := property.trim_prefix("stat_").split("/")
		var index := name_split[0].to_int()
		match name_split[1]:
			"stat": stat_names[index] = value
			"value": stat_values[index] = value
			"type": stat_modification_types[index] = value

		return true

	return false


func _get(property : StringName):
	if property == "stat_count":
		return stat_names.size()

	if property.begins_with("stat_"):
		var name_split := property.trim_prefix("stat_").split("/")
		var index := name_split[0].to_int()
		match name_split[1]:
			"stat": return stat_names[index]
			"value": return stat_values[index]
			"type": return stat_modification_types[index]

	return null


func _get_property_list() -> Array:
	var result := []
	result.append({
		&"name": "stat_count",
		&"type": TYPE_INT,
		&"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_ARRAY,
		&"hint": PROPERTY_HINT_NONE,
		&"hint_string": "",
		&"class_name": "stats,stat_",
	})
	for i in stat_names.size():
		result.append({
			&"name": "stat_%d/stat" % i,
			&"type": TYPE_STRING_NAME,
		})
		result.append({
			&"name": "stat_%d/value" % i,
			&"type": TYPE_FLOAT,
		})
		result.append({
			&"name": "stat_%d/type" % i,
			&"type": TYPE_INT,
			&"hint": PROPERTY_HINT_ENUM,
			&"hint_string": ",".join(Type.keys())
		})
	
	return result
