@icon("res://addons/wyvernshield_triggers/icons/stat_sheet.svg")
class_name DerivativeStatSheet
extends StatSheet

## A [StatSheet] that supports [StatDerivative] to make primary stats whose value adds to other stats at different ratios.

## The primary stat sheet of the actor. This node will read primary stats and convert them to derivative stats.[br]
## The source stat sheet should have this node as their [member parent_sheet], to read the calculated derivatives.
@export var source_stats : StatSheet:
	set(v):
		if source_stats != null:
			source_stats.stat_changed_raw.disconnect(_on_source_stat_changed)

		source_stats = v
		if v != null:
			v.stat_changed_raw.connect(_on_source_stat_changed)

		for k in v._toplevel_stats:
			_on_source_stat_changed(k)

		_update_all_derivatives()
## The list of primary stats to convert into derivative stats.
@export var derivatives : Array[StatDerivative] = []:
	set(v):
		for x in derivatives:
			remove_derivative(x)

		for x in v:
			add_derivative(x)

var _derivatives_dict := {}

## Add a [member StatDerivative] to the list and update stats.
func add_derivative(deriv : StatDerivative):
	var cur_array : Array = _derivatives_dict.get(deriv.source_stat, [])
	cur_array.append(deriv)
	derivatives.append(deriv)
	_derivatives_dict[deriv.source_stat] = cur_array
	if source_stats != null:
		deriv.apply(self, source_stats)

## Remove a [member StatDerivative] from the list and update stats.
func remove_derivative(deriv : StatDerivative):
	_derivatives_dict[deriv.source_stat].erase(deriv)
	derivatives.erase(deriv)
	clear(deriv.derivative_stats.at_path)


func _update_all_derivatives():
	clear()
	if source_stats == null:
		return

	for x in derivatives:
		x.apply(self, source_stats)


func _on_source_stat_changed(stat : StringName, new_value : float = 0.0, old_value : float = 0.0):
	if !_derivatives_dict.has(stat):
		return

	for x in _derivatives_dict[stat]:
		x.apply(self, source_stats)

	pass