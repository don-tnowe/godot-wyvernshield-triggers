@icon("res://addons/wyvernshield_triggers/icons/reaction_container.svg")
class_name TriggerReactionContainer
extends Node

## Holds trigger reactions. 
##
## Edit all triggers' function names and parameter in the [code]res://addons/wyvernshield_triggers/database.tres[/code] file.

## Emitted when any of the trigger finish going through reactions. [br]
## The result is of type <TriggerName>Result, access their properties through the parameters' names.[br]
## The input parameter values are stored in the result's [code]trigger_input_values[/code] properties.
signal trigger_fired(trigger : TriggerReaction.TriggerType, result : RefCounted)

## Emitted when [method remove_reaction_timed] adds a timer.
signal remove_timer_added(path : StringName, time_seconds : float, index_in_queue : int)
## Emitted when [method remove_reaction_time_set] changes a timer's expire time.
signal remove_timer_changed(path : StringName, time_seconds : float, new_index_in_queue : int)
## Emitted when a timer set by [method remove_reaction_timed] expires.
signal remove_timer_expired(path : StringName)

const TimedQueue := preload("res://addons/wyvernshield_triggers/triggers/timed_queue.gd")

## The actor this Reaction Container is attached to. [br]
## You can reference objects on this Reaction Container from trigger reaction scripts.
@export var actor : Node

## When reactions are processed, this container's reactions are processed with the parent's, respecting priority. [br]
## Useful for defining special reactions that apply to one ability - the parent holds reactions that apply to ALL abilities.
@export var parent_reactions : TriggerReactionContainer

## Reactions to add on ready.
## To add more at runtime, call [method add_reaction].
@export var initial_reactions : Array[TriggerReaction]:
	set(v):
		initial_reactions = v
		if Engine.is_editor_hint(): return
		add_reactions(v)

## The process function that updates the timer for [method remove_reaction_timed].
@export_enum("Physics", "Idle", "Off") var process_callback : int = 0:
	set(v):
		process_callback = v
		if Engine.is_editor_hint(): return
		_update_process_callback()

@export_group("References (Optional)")
@export var actor_visual : Node
@export var actor_data : Resource
@export var stats : StatSheet
@export var inventory : Node
@export var camera : Node
@export var anim : AnimationTree
@export var anim_list : AnimationPlayer
@export var ui : Node
@export var shape : Node
@export var nodes : Array[Node]
@export var resources : Array[Resource]

var _trigger_reactions : Array[Array] = []
var _timed_queue : TimedQueue
var _reaction_locations : Dictionary
var _reaction_repeats : Dictionary
var _timer_conflict := -1


func _init():
	clear()
	_timed_queue = TimedQueue.new()
	_timed_queue.expired.connect(_on_timer_expired)
	_timed_queue.add_conflict.connect(_on_timer_add_conflict)
	_update_process_callback()

## Removes all reactions.
func clear():
	_trigger_reactions.resize(TriggerReaction.TriggerType.MAX)
	for i in _trigger_reactions.size():
		_trigger_reactions[i] = []

## Adds a reaction. [br]
## [b]Note:[/b] Adding multiple reactions on the same [member TriggerReaction.reaction_id] does not apply the effects multiple times - for stackable numbers, use [StatSheet] and [StatModification].
func add_reaction(reaction : TriggerReaction):
	if _reaction_locations.has(reaction):
		_reaction_repeats[reaction.reaction_id] += 1
		return

	var inserted_at := -1
	var reaction_array := _trigger_reactions[reaction.trigger_id]
	for i in reaction_array.size():
		if reaction.reaction_id == reaction_array[i].reaction_id:
			return

		if inserted_at == -1 && reaction_array[i].priority <= reaction.priority:
			inserted_at = i

	if inserted_at == -1:
		inserted_at = reaction_array.size()

	reaction_array.insert(inserted_at, reaction)
	_reaction_locations[reaction.reaction_id] = reaction.trigger_id
	_reaction_repeats[reaction.reaction_id] = 1
	reaction._attached(self)
	if reaction.expires_in != 0.0:
		remove_reaction_timed(reaction.reaction_id, reaction.expires_in)

## Adds several reactions. [br]
## [b]Note:[/b] Multiple reactions with the same [member TriggerReaction.reaction_id] cannot be on the same reaction container.
func add_reactions(reactions : Array):
	for x in reactions:
		# Change back if `add_reaction` gets heavy logic at its end.
		add_reaction(x)

## Detaches the reaction with the specified reaction ID. [br]
## Returns the removed reaction, or [code]null[/code] if found none or multiple.
func remove_reaction(reaction_id : StringName, trigger_id : TriggerReaction.TriggerType = -1) -> TriggerReaction:
	if !_reaction_locations.has(reaction_id):
		_reaction_repeats[reaction_id] -= 1
		return null

	if trigger_id == -1:
		trigger_id = _reaction_locations[reaction_id]

	var arr := _trigger_reactions[trigger_id]
	for i in arr.size():
		if arr[i].reaction_id == reaction_id:
			var found : TriggerReaction = arr[i]
			arr.remove_at(i)
			found._detached(self)
			_reaction_locations.erase(reaction_id)
			return found

	return null

## Detaches a reaction after a timer passes. Time is set in seconds. [br]
## Use this just before or after adding a reaction at that path to make it active only temporarily. [br]
func remove_reaction_timed(reaction_id : StringName, time : float, independent_timers : bool = true):
	_timer_conflict = -1
	var new_index := _timed_queue.add(reaction_id, time, independent_timers)
	if new_index == -1:
		return

	if _timer_conflict != -1:
		# [method _on_timer_add_conflict] has triggered.
		remove_timer_changed.emit(reaction_id, time, new_index)
		return

	remove_timer_added.emit(reaction_id, time, new_index)
	if _timed_queue.get_count() == 1:
		_update_process_callback()


## Changes the clear time of a path that was set to be cleared by [method clear_timed], in seconds.
## If set to [code]0[/code], expires immediately.
func remove_reaction_time_set(reaction_id : StringName, new_time : float):
	remove_timer_changed.emit(reaction_id, new_time, _timed_queue.set_time(reaction_id, new_time))

## Retrieves the clear time of a path that was set to be cleared by [method clear_timed], in seconds.
## Returns [code]0[/code] if not found.
func remove_reaction_time_get(reaction_id : StringName) -> float:
	return _timed_queue.get_time(reaction_id)

## Returns a reaction with the specified IDs, or [code]null[/code] if not found.
func find_reaction(reaction_id : StringName) -> TriggerReaction:
	if !_reaction_locations.has(reaction_id): return null
	var arr : Array[TriggerReaction] = _trigger_reactions[_reaction_locations[reaction_id]]
	for i in arr.size():
		if arr[i].reaction_id == reaction_id:
			return arr[i]

	return null


# Auto-generated

class MoveStateChangedResult extends RefCounted:
	var trigger_input_values : MoveStateChangedResult
	var old_state
	var new_state
	pass


func move_state_changed(old_state, new_state) -> MoveStateChangedResult:
	var result := MoveStateChangedResult.new()
	result.trigger_input_values = MoveStateChangedResult.new()
	result.old_state = old_state
	result.trigger_input_values.old_state = old_state
	result.new_state = new_state
	result.trigger_input_values.new_state = new_state
	if _trigger_reactions[0].size() > 0:
		_process_reactions(result, 0, 0, _trigger_reactions[0][-1].priority)
	
	trigger_fired.emit(0, result)
	return result


class AbilityUsedResult extends RefCounted:
	var trigger_input_values : AbilityUsedResult
	var ability
	var target
	var spawned_nodes : Array[Node] = []
	pass


func ability_used(ability, target, spawned_nodes : Array[Node] = []) -> AbilityUsedResult:
	var result := AbilityUsedResult.new()
	result.trigger_input_values = AbilityUsedResult.new()
	result.ability = ability
	result.trigger_input_values.ability = ability
	result.target = target
	result.trigger_input_values.target = target
	result.spawned_nodes = spawned_nodes
	result.trigger_input_values.spawned_nodes = spawned_nodes
	if _trigger_reactions[1].size() > 0:
		_process_reactions(result, 1, 0, _trigger_reactions[1][-1].priority)
	
	trigger_fired.emit(1, result)
	return result


class AbilityGetCostResult extends RefCounted:
	var trigger_input_values : AbilityGetCostResult
	var ability
	var target
	var cost : float
	pass


func ability_get_cost(ability, target, cost : float) -> AbilityGetCostResult:
	var result := AbilityGetCostResult.new()
	result.trigger_input_values = AbilityGetCostResult.new()
	result.ability = ability
	result.trigger_input_values.ability = ability
	result.target = target
	result.trigger_input_values.target = target
	result.cost = cost
	result.trigger_input_values.cost = cost
	if _trigger_reactions[2].size() > 0:
		_process_reactions(result, 2, 0, _trigger_reactions[2][-1].priority)
	
	trigger_fired.emit(2, result)
	return result


class HitLandedResult extends RefCounted:
	var trigger_input_values : HitLandedResult
	var target
	var with_ability
	var damage : float
	pass


func hit_landed(target, with_ability, damage : float) -> HitLandedResult:
	var result := HitLandedResult.new()
	result.trigger_input_values = HitLandedResult.new()
	result.target = target
	result.trigger_input_values.target = target
	result.with_ability = with_ability
	result.trigger_input_values.with_ability = with_ability
	result.damage = damage
	result.trigger_input_values.damage = damage
	if _trigger_reactions[3].size() > 0:
		_process_reactions(result, 3, 0, _trigger_reactions[3][-1].priority)
	
	trigger_fired.emit(3, result)
	return result


class HitReceivedResult extends RefCounted:
	var trigger_input_values : HitReceivedResult
	var from
	var ability
	var damage : float
	pass


func hit_received(from, ability, damage : float) -> HitReceivedResult:
	var result := HitReceivedResult.new()
	result.trigger_input_values = HitReceivedResult.new()
	result.from = from
	result.trigger_input_values.from = from
	result.ability = ability
	result.trigger_input_values.ability = ability
	result.damage = damage
	result.trigger_input_values.damage = damage
	if _trigger_reactions[4].size() > 0:
		_process_reactions(result, 4, 0, _trigger_reactions[4][-1].priority)
	
	trigger_fired.emit(4, result)
	return result


class ApplyStatDerivativesResult extends RefCounted:
	var trigger_input_values : ApplyStatDerivativesResult
	var stat_sheet : StatSheet
	pass


func apply_stat_derivatives(stat_sheet : StatSheet) -> ApplyStatDerivativesResult:
	var result := ApplyStatDerivativesResult.new()
	result.trigger_input_values = ApplyStatDerivativesResult.new()
	result.stat_sheet = stat_sheet
	result.trigger_input_values.stat_sheet = stat_sheet
	if _trigger_reactions[5].size() > 0:
		_process_reactions(result, 5, 0, _trigger_reactions[5][-1].priority)
	
	trigger_fired.emit(5, result)
	return result

# Auto-generated end


func _physics_process(delta : float):
	_timed_queue.process(delta)


func _process(delta : float):
	_timed_queue.process(delta)


func _update_process_callback():
	if _timed_queue.get_count() == 0:
		set_physics_process(false)
		set_process(false)
		return

	set_physics_process(process_callback == 0)
	set_process(process_callback == 1)


func _process_reactions(result : RefCounted, trigger : int, cur_index : int = 0, end_at_priority : int = -2147483647) -> int:
	var processed_reactions := _trigger_reactions[trigger]
	var cur_priority : int = processed_reactions[0].priority
	var parent_priority : int = parent_reactions._trigger_reactions[trigger][0].priority if is_instance_valid(parent_reactions) else end_at_priority
	var parent_index : int = 0
	while true:
		if parent_priority > cur_priority && parent_index != -1:
			# The parent has higher priority, call them.
			parent_index = parent_reactions._process_reactions(result, trigger, parent_index, cur_priority)
			if parent_index != -1:
				parent_priority = parent_reactions._trigger_reactions[trigger][parent_index].priority

		processed_reactions[cur_index]._applied(self, result)
		cur_index += 1
		if cur_index == processed_reactions.size():
			break

		cur_priority = processed_reactions[cur_index].priority
		if cur_priority < end_at_priority:
			# The caller has higher priority, continue.
			return cur_index

	if is_instance_valid(parent_reactions) && parent_index != -1:
		parent_reactions._process_reactions(result, trigger, parent_index)

	return -1


func _on_timer_expired(key : StringName):
	if _timed_queue.get_count() == 0:
		_update_process_callback()

	remove_reaction(key)
	remove_timer_expired.emit(key)


func _on_timer_add_conflict(removed_key : StringName, removed_index : int):
	_timer_conflict = removed_index
