@tool
@icon("res://addons/wyvernshield_triggers/icons/stat_modification.svg")
class_name StatModification
extends Resource

## The type of a stat modification.
enum Type {
	BASE = 0, ## Base stat, added together before other calculations.
	PERCENT_CHANGE, ## Percent increase/decrease, added together to then modify base.
	PERCENT_MAGNITUDE, ## Multiplier of percent changes, MULTIPLIED together.
	MULTIPLIER, ## Multiplier of total value, MULTIPLIED together.
	MAX ## The size of the enumeration.
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

## Names of modified stats.
var stat_names : Array[StringName]
## Values of modified stats.
var stat_values : Array[float]
## Modification types of modified stats. See [enum Type].
var stat_modification_types : Array[Type]


func _init():
	at_path = &"init"  # Triggers setter.


## Applies modifications. Overrides modifications at [member at_path].
## The [code]with_magnitude[/code] parameter will be multiplied by this object's [member magnitude].
func apply(to: StatSheet, with_magnitude : float = 1.0):
	to.lock()
	for i in stat_names.size():
		var new_value := 0.0

		if stat_modification_types[i] <= Type.PERCENT_CHANGE:
			new_value = stat_values[i] * magnitude * with_magnitude

		else:
			new_value = (stat_values[i] - 1.0) * magnitude * with_magnitude + 1.0

		to.set_stat(stat_names[i], new_value, at_path, stat_modification_types[i])

	to.unlock()
	if expires_in != 0.0:
		to.clear_timed(at_path, expires_in)

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
