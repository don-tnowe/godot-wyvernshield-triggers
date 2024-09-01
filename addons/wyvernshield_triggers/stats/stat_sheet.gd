@icon("res://addons/wyvernshield_triggers/icons/stat_sheet.svg")
class_name StatSheet
extends Node

## A node that holds stats, input as various modifications and output as a single number. [br]
##
## Modify stats via [method set_stat], [method set_from_modification], [method set_suffixed] or other [code]set_*[/code] methods. Retrieve them using [method use_stat] or [method get_stat].[br]
## [br]
## Most setter methods have a [code]path[/code] parameter - modifications at different paths stack together, applying the same stat and type to the same path overwrites the value. [br]
## Paths can be imagined as folders of files - use "/" to divide units, like [code]equip/helmet[/code] or [code]meta/skilltree/warrior/vital_might[/code]. When a modification occurs at a path, stats under all paths above get recalculated, so that rarely-changed paths don't get fully recalculated every time. [br]
## For stacking rules, check [enum StatModification.Type].[br]

## Emitted when stat gets changed through any means.
signal stat_changed(stat : StringName, new_value : float, old_value : float)
## Emitted when stat gets changed through any means, [b]without considering [member parent_sheet] contributions[/b].
signal stat_changed_raw(stat : StringName, new_value : float, old_value : float)

## Emitted when [method clear_timed] adds a timer.
signal clear_timer_added(path : StringName, time_seconds : float, index_in_queue : int)
## Emitted when [method clear_time_set] changes a timer's expire time.
signal clear_timer_changed(path : StringName, time_seconds : float, new_index_in_queue : int)
## Emitted when a timer set by [method clear_timed] expires.
signal clear_timer_expired(path : StringName)

const _modification_suffix := {
	43 : StatModification.Type.BASE, ## Base stat, added together before other calculations.
	37 : StatModification.Type.PERCENT_CHANGE, ## Percent increase/decrease, added together to then modify base.
	36 : StatModification.Type.PERCENT_MAGNITUDE, ## Multiplier of percent changes, MULTIPLIED together.
	42 : StatModification.Type.MULTIPLIER, ## Multiplier of total value, MULTIPLIED together.
	38 : StatModification.Type.FLAT_BONUS, ## Flat bonus, added to the value [b]after[/b] all multipliers.
	39 : StatModification.Type._5,
	94 : StatModification.Type.LOWER_LIMIT, ## Lower limit of the resulting value. The highest modification will be applied.
	95 : StatModification.Type.UPPER_LIMIT, ## Upper limit of the resulting value. The lowest modification will be applied.
}

const _stat_default := Projection(
	Vector4(0, 0, 1, 1),
	Vector4(0, 0, -3.4028235e38, 3.4028235e38),
	# Vector4(0, 0, -1, 1),
	Vector4.ZERO,
	Vector4.ZERO,
)

## [StatModification]s to apply at start. [br]
## To add more at runtime, call [method set_from_modification] or the modification's [method StatModification.apply]. [br]
## To set a specific stat, call one of the [code]set_[/code] methods.
@export var initial_stats : Array[StatModification]:
	set(v):
		initial_stats = v
		for i in v.size():
			if v[i] == null:
				v[i] = StatModification.new()

			elif !Engine.is_editor_hint():
				v[i].apply(self)

## The process function that updates the timer for [method clear_timed].
@export_enum("Physics", "Idle", "Off") var process_callback : int = 0:
	set(v):
		process_callback = v
		_update_process_callback()

## When using [method get_stat], consider parent sheet's stat modifications as well. This only works in one direction. [br]
## Useful for stat derivatives (like "strength" affecting "health" and "damage").
@export var parent_sheet : StatSheet:
	set(v):
		if parent_sheet != null:
			parent_sheet.stat_changed_raw.disconnect(_on_parent_stat_changed)

		parent_sheet = v
		if v != null:
			v.stat_changed_raw.connect(_on_parent_stat_changed)

var _children_of := {}
var _parents_of := {}
var _path_stats := {}  # Set through set_*()
var _precalculated_stats_at := {}  # Updated from _path_stats when recalculating
var _toplevel_stats := {}
var _timed_queue : TimedQueue
var _timer_conflict := -1
var _locks := 0


func _init():
	_create_path(&".")
	_timed_queue = TimedQueue.new()
	_timed_queue.expired.connect(_on_timer_expired)
	_timed_queue.add_conflict.connect(_on_timer_add_conflict)
	_update_process_callback()


func _ready():
	# IDK why I need to do this, but I do.  
	_update_process_callback()

## Retrieves a stat's value, calculated from all paths. [br]
## [code]parent_modifications[/code] is used as extra modifications, using the [enum StatModification.Type] rules. [br]
func get_stat(stat : StringName, default_value : float = 0.0, with_parent_sheet : bool = true) -> float:
	if parent_sheet == null || !with_parent_sheet:
		return _toplevel_stats.get(stat, default_value)

	var precalc := _get_toplevel_precalculated(stat)
	if precalc != _stat_default:
		return _precalculated_to_value(precalc)

	return default_value

## Retrieves a stat's modifications, applying them to the specified base value, using all [enum StatModification.Type] rules. [br]
func use_stat(on_value : float, stat : StringName) -> float:
	if stat == &"":
		return on_value

	var precalc := _get_toplevel_precalculated(stat)
	if precalc != _stat_default:
		precalc.x.x += on_value
		return _precalculated_to_value(precalc)

	return on_value

## Uses [method use_stat] on several stats to modify one base value, using all [enum StatModification.Type] rules. [br]
func use_stats(on_value : float, stats : Array[StringName]) -> float:
	var precalc := _stat_default
	precalc.x.x += on_value
	for x in stats:
		precalc = _combine_precalculated(precalc, _get_toplevel_precalculated(x))

	return _precalculated_to_value(precalc)

## Retrieves a stat's value from a specific path, of a specific modification type.
func get_stat_at_path(stat : StringName, default_value : float = 0.0, path : StringName = &".", modification_type : StatModification.Type = -1) -> float:
	var result_matrix : Projection = _precalculated_stats_at.get(path, {}).get(stat, _stat_default)
	match modification_type:
		StatModification.Type.BASE:
			return result_matrix.x.x
		StatModification.Type.PERCENT_CHANGE:
			return result_matrix.x.y
		StatModification.Type.PERCENT_MAGNITUDE:
			return result_matrix.x.z
		StatModification.Type.MULTIPLIER:
			return result_matrix.x.w
		StatModification.Type.FLAT_BONUS:
			return result_matrix.y.x
		StatModification.Type._5:
			return result_matrix.y.y
		StatModification.Type.LOWER_LIMIT:
			return result_matrix.y.z
		StatModification.Type.UPPER_LIMIT:
			return result_matrix.y.w
		_:
			return _precalculated_to_value(result_matrix)

	return default_value

## Retrieves all stats from all paths.
func get_stats() -> Dictionary:
	return _toplevel_stats.duplicate()

## Changes a stat according to the set [enum StatModification.Type]. [br]
func set_stat(stat : StringName, value : float, path : StringName = &".", modification_type : StatModification.Type = StatModification.Type.BASE):
	_create_path(path)
	var stat_matrix : Projection = _path_stats[path].get(stat, _stat_default)
	match modification_type:
		StatModification.Type.BASE:
			stat_matrix.x.x = value
		StatModification.Type.PERCENT_CHANGE:
			stat_matrix.x.y = value
		StatModification.Type.PERCENT_MAGNITUDE:
			stat_matrix.x.z = value
		StatModification.Type.MULTIPLIER:
			stat_matrix.x.w = value
		StatModification.Type.FLAT_BONUS:
			stat_matrix.y.x = value
		StatModification.Type._5:
			stat_matrix.y.y = value
		StatModification.Type.LOWER_LIMIT:
			stat_matrix.y.z = value
		StatModification.Type.UPPER_LIMIT:
			stat_matrix.y.w = value

	_path_stats[path][stat] = stat_matrix
	_recalculate_upwards_one(path, stat)

## Applies a [StatModification], returning the path it was applied to. If modification is [code]null[/code], returns empty StringName.
## Returns the path applied to, which may differ if [member StatModification.non_repeat] is set, to then remove it using [method clear]. [br]
func set_from_modification(mod : StatModification, magnitude : float = 1.0) -> StringName:
	if mod == null: return &""
	return mod.apply(self, magnitude)

## Applies a stat modification from a dictionary. See [method set_suffixed].
func set_from_dict(mods : Dictionary, path : StringName = &".", non_repeat : bool = false) -> StringName:
	if mods.size() == 0: return &""
	if non_repeat: path = get_non_repeating_path(path)

	var stat_names : Array = mods.keys()
	var stat_values : Array = mods.values()

	for i in stat_names.size():
		set_suffixed(stat_names[i], stat_values[i], path)

	return path

## Applies a stat modification, taking a string that is the stat's key with a special character after it.
## This allows storage of modifications in form of dictionaries.[br]
## To modify a stat called [code]stat[/code], one of these StringNames must be used: [br]
## - [b]&"stat+":[/b] [method set_base][br]
## - [b]&"stat%":[/b] [method set_percentage][br]
## - [b]&"stat$":[/b] [method set_percentage_magnitude][br]
## - [b]&"stat*":[/b] [method set_multiplier][br]
## - [b]&"stat&":[/b] [method set_flat_bonus][br]
## - [b]&"stat^":[/b] [method set_lower_limit][br]
## - [b]&"stat_":[/b] [method set_upper_limit][br]
func set_suffixed(stat_suffixed : StringName, value : float = 1.0, path : StringName = &"."):
	var len := stat_suffixed.length() - 1
	var suffix_char := _modification_suffix.get(stat_suffixed.unicode_at(len), -1)
	if suffix_char == -1:
		set_stat(stat_suffixed, value, path, StatModification.Type.BASE)
		return

	set_stat(stat_suffixed.left(len), value, path, _modification_suffix[suffix_char])

## Sets the base value of a stat.
## Base values are added together.
func set_base(stat : StringName, value : float, path : StringName = &"."):
	set_stat(stat, value, path, StatModification.Type.BASE)

## Sets the percentage increase of a stat.
## Percentage increases are added together: if two paths have a +50%, it would result in a 2x (= 100% + 50% + 50%) of the base stat value.
func set_percentage(stat : StringName, value : float, path : StringName = &"."):
	set_stat(stat, value, path, StatModification.Type.PERCENT_CHANGE)

## Sets the magnitude of percentage increases to a stat.
## The magnitude is a muliplier of the total percentage boosts: a +1205% boost multiplied by a 0.5x magnitude will become +602.5%, multiplying the base stat by 7.025x (= 100% + 602.5%).
## Magnitudes are MULTIPLIED together: if two paths have a x1.5, it would result in a x2.25 (= 1.5 x 1.5) multiplier of percentages.
func set_percentage_magnitude(stat : StringName, value : float, path : StringName = &"."):
	set_stat(stat, value, path, StatModification.Type.PERCENT_MAGNITUDE)

## Sets the multiplier increase of a stat.
## Multipliers are MULTIPLIED together: if two paths have a x1.5, it would result in a x2.25 (= 1.5 x 1.5) of the base stat value.
func set_multiplier(stat : StringName, value : float, path : StringName = &"."):
	set_stat(stat, value, path, StatModification.Type.MULTIPLIER)

## Sets the flat bonus increase of a stat.
## Similar to [method set_base], but multipliers like [method set_percentage] and [method set_multiplier] don't apply.
func set_flat_bonus(stat : StringName, value : float, path : StringName = &"."):
	set_stat(stat, value, path, StatModification.Type.FLAT_BONUS)


func set_idk(stat : StringName, value : float, path : StringName = &"."):
	set_stat(stat, value, path, StatModification.Type._5)

## Sets the lower limit of a stat - its value won't go below that.
func set_lower_limit(stat : StringName, value : float, path : StringName = &"."):
	set_stat(stat, value, path, StatModification.Type.LOWER_LIMIT)

## Sets the upper limit of a stat - its value won't go above that.
func set_upper_limit(stat : StringName, value : float, path : StringName = &"."):
	set_stat(stat, value, path, StatModification.Type.UPPER_LIMIT)

## Reset all stats to zero. [br]
## Provide a path to only clear that path - if recursive, with all subpaths as well. Subpath units are separated by "/".
func clear(path : StringName = &".", recursive : bool = true, _current_recursion : int = 0):
	if !_path_stats.has(path):
		return

	var keys : Array = _precalculated_stats_at[path].keys()
	_precalculated_stats_at[path].clear()
	_path_stats[path].clear()
	if recursive:
		for x in _children_of[path]:
			clear(x, true, _current_recursion + 1)

	if _current_recursion == 0:
		for x in keys:
			_recalculate_upwards_one(path, x)

## Reset stats by path to zero after a timer passes. Time is set in seconds. [br]
## Use this just before or after setting stats at that path to set these stats only temporarily. [br]
## [b]Note:[/b]: this will clear subpaths as well. Subpath units are separated by "/".
func clear_timed(path : StringName, time : float):
	_timer_conflict = -1
	var new_index := _timed_queue.add(path, time)
	if new_index == -1:
		return

	if _timer_conflict != -1:
		# [method _on_timer_add_conflict] has triggered.
		clear_timer_changed.emit(path, time, new_index)
		return

	clear_timer_added.emit(path, time, new_index)
	if _timed_queue.get_count() == 1:
		_update_process_callback()

## Changes the clear time of a path that was set to be cleared by [method clear_timed], in seconds. [br]
## If set to [code]0[/code], expires immediately.
func clear_time_set(path : StringName, new_time : float):
	clear_timer_changed.emit(path, new_time, _timed_queue.set_time(path, new_time))

## Retrieves the clear time of a path that was set to be cleared by [method clear_timed], in seconds. [br]
## Returns [code]0[/code] if not found.
func clear_time_get(path : StringName) -> float:
	return _timed_queue.get_time(path)

## Get the contribution to a stat's value from each path, as a string. [br]
## A path with 2 base, +30% percentage and x1.2 multiplier witll be shown as [code]"2 + 30% x 1.20"[/code]. [br]
## A path with only a -10% percentage debuff will be shown as just [code]- 10%[/code] [br]
## To retrieve a value as numbers, use [method get_stat_at_path].
func get_contributions(stat : StringName) -> Dictionary:
	var result := {}
	for k in _precalculated_stats_at:
		var cur : Projection = _precalculated_stats_at[k].get(stat, _stat_default)
		result[k] = ("%s%s%s%s%s" % [
			str(cur.x.x) if cur.x.x != 0.0 else "",
			" " if cur.x.z == 1.0 else " (" if cur.x.y != 0.0 else (" (%"),
			(("+ " + str(cur.x.y) if cur.x.y > 0.0 else "- " + str(-cur.x.y)) + "%") if cur.x.y != 0.0 else "",
			(" x %.2f)" % cur.x.z) if cur.x.z != 1.0 else "",
			(" x %.2f" % (cur.x.w)) if cur.x.w != 1.0 else "",
		]).strip_edges()

	return result

## Returns a path that, when applied, will not overwrite any stat modifications in this sheet.
func get_non_repeating_path(from_path : StringName) -> StringName:
	if !_children_of.has(from_path):
		return StringName("%s/0" % [from_path])

	return StringName("%s/%s" % [from_path, _children_of[from_path].size()])

## [b]Deprecated.[/b] No effect.
func lock():
	_locks += 1

## [b]Deprecated.[/b] No effect.
func unlock():
	_locks -= 1
	if _locks == 0:
		_recalculate_upwards(&".")


func _physics_process(delta : float):
	_timed_queue.process(delta)


func _process(delta : float):
	_timed_queue.process(delta)


func _get_toplevel_precalculated(stat : StringName) -> Projection:
	if parent_sheet == null:
		return _precalculated_stats_at[&"."].get(stat, _stat_default)

	# ATTENTION: if a Stack Overflow got you here you probably made a cyclic reference in your parent_sheet.
	return _combine_precalculated(parent_sheet._get_toplevel_precalculated(stat), _precalculated_stats_at[&"."].get(stat, _stat_default))


func _create_path(path : StringName):
	if _children_of.has(path):
		return

	var parent := StringName(path.get_base_dir())
	if parent == "": parent = &"."
	_children_of[path] = []
	_path_stats[path] = {}
	_precalculated_stats_at[path] = {}
	_parents_of[path] = parent
	if path != &"" && !_children_of.has(parent):
		_create_path(parent)

	if path != &"" && path != &".":
		_children_of[parent].append(path)


func _recalculate_upwards_one(path : StringName, stat_to_precalc : StringName):
	if path == &"": path = &"."
	var result : Projection = _stat_default
	while true:
		result = _path_stats[path].get(stat_to_precalc, _stat_default)
		for k in _children_of[path]:
			result = _combine_precalculated(result, _precalculated_stats_at[k].get(stat_to_precalc, _stat_default))

		_precalculated_stats_at[path][stat_to_precalc] = result
		if path == ".": break
		path = _parents_of[path]

	var old_stat : float = _toplevel_stats.get(stat_to_precalc, 0.0)
	var new_stat_raw : float = _precalculated_to_value(result)
	_toplevel_stats[stat_to_precalc] = new_stat_raw
	var new_stat : float = get_stat(stat_to_precalc)
	stat_changed.emit(stat_to_precalc, new_stat, old_stat)
	stat_changed_raw.emit(stat_to_precalc, new_stat_raw, old_stat)


func _recalculate_upwards(path : StringName):
	if path == &"": path = &"."
	var result : Dictionary
	while true:
		result = _precalculated_stats_at[path]
		result.clear()
		var paths_own_stats : Dictionary = _path_stats[path]
		for stat_k in paths_own_stats:
			result[stat_k] = paths_own_stats[stat_k]

		for child_k in _children_of[path]:
			var pre : Dictionary = _precalculated_stats_at[child_k]
			for stat_k in pre:
				result[stat_k] = _combine_precalculated(result.get(stat_k, _stat_default), pre[stat_k])

		if path == ".": break
		path = _parents_of[path]

	if _locks != 0: return
	var toplevel_stats_old := _toplevel_stats
	for k in toplevel_stats_old:
		if !result.has(k):
			stat_changed.emit(k, 0, toplevel_stats_old[k])

	_toplevel_stats = {}
	for final_stat_k in result:
		var v : Projection = result[final_stat_k]
		var old_stat : float = toplevel_stats_old.get(final_stat_k, 0.0)
		var new_stat_raw : float = _precalculated_to_value(v)
		_toplevel_stats[final_stat_k] = new_stat_raw
		var new_stat : float = get_stat(final_stat_k)
		stat_changed.emit(final_stat_k, new_stat, old_stat)
		stat_changed_raw.emit(final_stat_k, new_stat_raw, old_stat)


func _combine_precalculated(to_combine : Projection, with : Projection) -> Projection:
	return Projection(
		Vector4(
			to_combine.x.x + with.x.x,
			to_combine.x.y + with.x.y,
			to_combine.x.z * with.x.z,
			to_combine.x.w * with.x.w,
		),
		Vector4(
			to_combine.y.x + with.y.x,
			to_combine.y.y + with.y.y,
			maxf(to_combine.y.z, with.y.z),
			minf(to_combine.y.w, with.y.w),
		),
		Vector4.ZERO,
		Vector4.ZERO,
	)


func _precalculated_to_value(v : Projection) -> float:
	return clampf(v.x.x * (v.x.y * 0.01 * v.x.z + 1.0) * (v.x.w) + v.y.x, v.y.z, v.y.w)


func _update_process_callback():
	if _timed_queue.get_count() == 0:
		set_physics_process(false)
		set_process(false)
		return

	set_physics_process(process_callback == 0)
	set_process(process_callback == 1)


func _on_timer_expired(key : StringName):
	if _timed_queue.get_count() == 0:
		_update_process_callback()

	clear(key)
	clear_timer_expired.emit(key)


func _on_timer_add_conflict(removed_key : StringName, removed_index : int):
	_timer_conflict = removed_index


func _on_parent_stat_changed(stat : StringName, new_value : float, old_value : float):
	stat_changed.emit(stat, get_stat(stat), old_value)
