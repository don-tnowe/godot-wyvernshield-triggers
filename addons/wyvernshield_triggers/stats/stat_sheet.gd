class_name StatSheet
extends Node

## Emitted when stat gets changed through any means.
signal stat_changed(stat : StringName, new_value : float, old_value : float)

## Emitted when [method clear_timed] adds a timer.
signal clear_timer_added(path : StringName, time_seconds : float, index_in_queue : int)
## Emitted when [method clear_time_set] changes a timer's expire time.
signal clear_timer_changed(path : StringName, time_seconds : float, new_index_in_queue : int)
## Emitted when a timer set by [method clear_timed] expires.
signal clear_timer_expired(path : StringName)

const _stat_default := Projection(
	Vector4(0, 0, 1, 1),
	Vector4.ZERO,
	Vector4.ZERO,
	Vector4.ZERO,
)

## [StatModification]s to apply at start. [br]
## To add more at runtime, call [method StatModification.apply]. [br]
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

var _children_of := {}
var _parents_of := {}
var _path_stats := {}
var _precalculated_stats_of := {}
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

## Retrieves a stat's value from all paths.
func get_stat(stat : StringName, default_value : float = 0.0) -> float:
	return _toplevel_stats.get(stat, default_value)

## Retrieves all stats from all paths.
func get_stats() -> Dictionary:
	return _toplevel_stats.duplicate()

## Changes a stat according to the set [enum StatChangeType].
func set_stat(stat : StringName, value : float, path : StringName = &".", modification_type : StatModification.Type = StatModification.Type.BASE):
	match modification_type:
		StatModification.Type.BASE:
			set_base(stat, value, path)
		StatModification.Type.PERCENT_CHANGE:
			set_percentage(stat, value, path)
		StatModification.Type.PERCENT_MAGNITUDE:
			set_percentage_magnitude(stat, value, path)
		StatModification.Type.MULTIPLIER:
			set_multiplier(stat, value, path)

## Applies a [StatModification].
func set_from_modification(mod : StatModification, magnitude : float = 1.0):
	mod.apply(self, magnitude)

## Sets the base value of a stat.
## Base values are added together.
func set_base(stat : StringName, value : float, path : StringName = &"."):
	_create_path(path)
	var stat_matrix : Projection = _path_stats[path].get(stat, _stat_default)
	stat_matrix.x.x = value
	_path_stats[path][stat] = stat_matrix
	_recalculate_upwards(path)

## Sets the percentage increase of a stat.
## Percentage increases are added together: if two paths have a +50%, it would result in a 2x (= 100% + 50% + 50%) of the base stat value.
func set_percentage(stat : StringName, value : float, path : StringName = &"."):
	_create_path(path)
	var stat_matrix : Projection = _path_stats[path].get(stat, _stat_default)
	stat_matrix.x.y = value
	_path_stats[path][stat] = stat_matrix
	_recalculate_upwards(path)

## Sets the magnitude of percentage increases to a stat.
## The magnitude is a muliplier of the total percentage boosts: a +1205% boost multiplied by a 0.5x magnitude will become +602.5%, multiplying the base stat by 7.025x (= 100% + 602.5%).
## Magnitudes are MULTIPLIED together: if two paths have a x1.5, it would result in a x2.25 (= 1.5 x 1.5) multiplier of percentages.
func set_percentage_magnitude(stat : StringName, value : float, path : StringName = &"."):
	_create_path(path)
	var stat_matrix : Projection = _path_stats[path].get(stat, _stat_default)
	stat_matrix.x.z = value
	_path_stats[path][stat] = stat_matrix
	_recalculate_upwards(path)

## Sets the multiplier increase of a stat.
## Multipliers are MULTIPLIED together: if two paths have a x1.5, it would result in a x2.25 (= 1.5 x 1.5) of the base stat value.
func set_multiplier(stat : StringName, value : float, path : StringName = &"."):
	_create_path(path)
	var stat_matrix : Projection = _path_stats[path].get(stat, _stat_default)
	stat_matrix.x.w = value
	_path_stats[path][stat] = stat_matrix
	_recalculate_upwards(path)

## Reset all stats to zero.
## Provide a path to only clear that path - if recursive, with all subpath as well. Subpath units are separated by "/".
func clear(path : StringName = &".", recursive : bool = true, _current_recursion : int = 0):
	if !_path_stats.has(path):
		return

	_path_stats[path].clear()
	if recursive:
		for x in _children_of[path]:
			clear(x, true, _current_recursion + 1)

		if _children_of[path].size() == 0:
			_recalculate_upwards(path)

## Reset stats by path to zero after a timer passes. Time is set in seconds.
## Use this just before or after setting stats at that path to set these stats only temporarily.
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

## Changes the clear time of a path that was set to be cleared by [method clear_timed], in seconds.
## If set to [code]0[/code], expires immediately.
func clear_time_set(path : StringName, new_time : float):
	clear_timer_changed.emit(path, new_time, _timed_queue.set_time(path, new_time))

## Retrieves the clear time of a path that was set to be cleared by [method clear_timed], in seconds.
## Returns [code]0[/code] if not found.
func clear_time_get(path : StringName) -> float:
	return _timed_queue.get_time(path)

## Get the contribution to a stat's value from each path, as a string.
## A path with 2 base, +30% percentage and x1.2 multiplier witll be shown as [code]"2 + 30% x 1.20"[/code].
## A path with only a -10% percentage debuff will be shown as just [code]- 10%[/code]
func get_contributions(stat : StringName) -> Dictionary:
	var result := {}
	for k in _path_stats:
		var cur : Projection = _path_stats[k].get(stat, _stat_default)
		result[k] = ("%s%s%s%s%s" % [
			str(cur.x.x) if cur.x.x != 0.0 else "",
			" " if cur.x.z == 1.0 else " (" if cur.x.y != 0.0 else (" (%"),
			(("+ " + str(cur.x.y) if cur.x.y > 0.0 else "- " + str(-cur.x.y)) + "%") if cur.x.y != 0.0 else "",
			(" x %.2f)" % cur.x.z) if cur.x.z != 1.0 else "",
			(" x %.2f" % (cur.x.w)) if cur.x.w != 1.0 else "",
		]).strip_edges()

	return result

## Before changing lots of stats, lock to reduce recalculations.
func lock():
	_locks += 1

## After a [method lock], don't forget to call this.
func unlock():
	_locks -= 1
	if _locks == 0:
		_recalculate_upwards(&".")


func _physics_process(delta : float):
	_timed_queue.process(delta)


func _process(delta : float):
	_timed_queue.process(delta)


func _create_path(path : StringName):
	if _children_of.has(path):
		return

	var parent := StringName(path.get_base_dir())
	if parent == "": parent = &"."
	_children_of[path] = []
	_path_stats[path] = {}
	_precalculated_stats_of[path] = {}
	_parents_of[path] = parent
	if path != &"" && !_children_of.has(parent):
		_create_path(parent)

	if path != &"":
		_children_of[parent].append(path)


func _recalculate_upwards(path : StringName):
	if path == &"": path = &"."
	var result : Dictionary = _precalculated_stats_of[path]
	result.clear()
	for k in _children_of[path]:
		var pre : Dictionary = _precalculated_stats_of[k]
		for stat_k in pre:
			result[stat_k] = _combine_precalculated(result, stat_k, pre[stat_k])

	var pstats : Dictionary = _path_stats[path]
	for k in pstats:
		result[k] = _combine_precalculated(result, k, pstats[k])

	if path == &".":
		if _locks != 0: return
		var toplevel_stats_old := _toplevel_stats
		for k in toplevel_stats_old:
			if !result.has(k):
				stat_changed.emit(k, 0, toplevel_stats_old[k])

		_toplevel_stats = {}
		for k in result:
			var v : Projection = result[k]
			var old_stat : float = toplevel_stats_old.get(k, 0.0)
			var new_stat : float = v.x.x * (v.x.y * 0.01 * v.x.z + 1.0) * (v.x.w)
			_toplevel_stats[k] = new_stat
			if old_stat != new_stat:
				stat_changed.emit(k, new_stat, old_stat)

	else:
		_recalculate_upwards(_parents_of[path])


func _combine_precalculated(to_combine : Dictionary, stat : StringName, with : Projection):
	var result : Projection = to_combine.get(stat, _stat_default)
	return Projection(
		Vector4(
			result.x.x + with.x.x,
			result.x.y + with.x.y,
			result.x.z * with.x.z,
			result.x.w * with.x.w,
		),
		result.y + with.y,
		result.z + with.z,
		result.w + with.w
	)


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
