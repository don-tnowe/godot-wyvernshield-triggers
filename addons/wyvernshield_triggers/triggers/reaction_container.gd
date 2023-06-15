@tool
class_name TriggerReactionContainer
extends Node

## Emitted when [method remove_reaction_timed] adds a timer.
signal remove_timer_added(path : StringName, time_seconds : float, index_in_queue : int)
## Emitted when [method remove_reaction_time_set] changes a timer's expire time.
signal remove_timer_changed(path : StringName, time_seconds : float, new_index_in_queue : int)
## Emitted when a timer set by [method remove_reaction_timed] expires.
signal remove_timer_expired(path : StringName)

const TimedQueue := preload("res://addons/wyvernshield_triggers/triggers/timed_queue.gd")

## The actor this Trigger Holder is attached to.
@export var actor : Node

## Reactions to add on ready.
## To add more at runtime, call [method add_reaction].
@export var initial_reactions : Array[TriggerReaction]:
	set(v):
		initial_reactions = v
		for i in v.size():
			if v[i] == null:
				v[i] = TriggerReaction.new()

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


func _init():
	_trigger_reactions.resize(TriggerReaction.TriggerType.MAX)
	for i in _trigger_reactions.size():
		_trigger_reactions[i] = []

	_timed_queue = TimedQueue.new()
	_timed_queue.expired.connect(_on_timer_expired)
	_update_process_callback()

## Adds a reaction.
## [b]Note:[/b] Multiple reactions with the same [member TriggerReaction.reaction_id] cannot be on the same reaction container.
func add_reaction(reaction : TriggerReaction):
	if _reaction_locations.has(reaction): return
	var inserted_at := -1
	var reaction_array := _trigger_reactions[reaction.trigger_id]
	for i in reaction_array.size():
		if inserted_at == -1 && reaction_array[i].priority >= reaction.priority:
			inserted_at = i

	if inserted_at == -1:
		inserted_at = reaction_array.size()

	reaction_array.insert(inserted_at, reaction)
	_reaction_locations[reaction.reaction_id] = reaction.trigger_id
	reaction._attached(self)
	if reaction.expires_in != 0.0:
		remove_reaction_timed(reaction.reaction_id, reaction.expires_in)

## Adds several reactions.
## [b]Note:[/b] Multiple reactions with the same [member TriggerReaction.reaction_id] cannot be on the same reaction container.
func add_reactions(reactions : Array):
	for x in reactions:
		# Change back if `add_reaction` gets heavy logic at its end.
		add_reaction(x)

## Detaches the reaction with the specified reaction ID.
## Returns the removed reaction, or [code]null[/code] if not found.
func remove_reaction(reaction_id : StringName, trigger_id : TriggerReaction.TriggerType = -1) -> TriggerReaction:
	if !_reaction_locations.has(reaction_id):
		return null

	if trigger_id == -1:
		trigger_id = _reaction_locations[reaction_id]

	var arr := _trigger_reactions[trigger_id]
	for i in arr.size():
		if arr[i].reaction_id == reaction_id:
			arr.remove_at(i)
			arr[i]._detached(self)
			_reaction_locations.erase(reaction_id)
			return arr[i]

	return null

## Detaches a reaction after a timer passes. Time is set in seconds.
## Use this just before or after adding a reaction at that path to make it active only temporarily.
## [b]Note:[/b]: this will clear subpaths as well. Subpath units are separated by "/".
func remove_reaction_timed(reaction_id : StringName, time : float):
	if _timed_queue.get_count() == 0:
		_update_process_callback()

	remove_timer_added.emit(reaction_id, time, _timed_queue.add(reaction_id, time))

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

class MoveStateChangedResult extends Resource:
	var old_state
	var new_state
	pass


func move_state_changed(old_state, new_state) -> MoveStateChangedResult:
	var result := MoveStateChangedResult.new()
	result.old_state = old_state
	result.new_state = new_state
	for x in _trigger_reactions[0]:
		x._applied(self, result)
	
	return result


class AbilityUsedResult extends Resource:
	var ability
	var target
	@export var spawned_nodes : Array[Node] = []
	pass


func ability_used(ability, target, spawned_nodes : Array[Node] = []) -> AbilityUsedResult:
	var result := AbilityUsedResult.new()
	result.ability = ability
	result.target = target
	result.spawned_nodes = spawned_nodes
	for x in _trigger_reactions[1]:
		x._applied(self, result)
	
	return result


class AbilityGetCostResult extends Resource:
	var ability
	var target
	@export var cost : float
	pass


func ability_get_cost(ability, target, cost : float) -> AbilityGetCostResult:
	var result := AbilityGetCostResult.new()
	result.ability = ability
	result.target = target
	result.cost = cost
	for x in _trigger_reactions[2]:
		x._applied(self, result)
	
	return result


class HitLandedResult extends Resource:
	var target
	var with_ability
	@export var damage : float
	pass


func hit_landed(target, with_ability, damage : float) -> HitLandedResult:
	var result := HitLandedResult.new()
	result.target = target
	result.with_ability = with_ability
	result.damage = damage
	for x in _trigger_reactions[3]:
		x._applied(self, result)
	
	return result


class HitReceivedResult extends Resource:
	var from
	var ability
	@export var damage : float
	pass


func hit_received(from, ability, damage : float) -> HitReceivedResult:
	var result := HitReceivedResult.new()
	result.from = from
	result.ability = ability
	result.damage = damage
	for x in _trigger_reactions[4]:
		x._applied(self, result)
	
	return result


class ApplyStatDerivativesResult extends Resource:
	@export var stat_sheet : StatSheet
	pass


func apply_stat_derivatives(stat_sheet : StatSheet) -> ApplyStatDerivativesResult:
	var result := ApplyStatDerivativesResult.new()
	result.stat_sheet = stat_sheet
	for x in _trigger_reactions[5]:
		x._applied(self, result)
	
	return result

# Auto-generated end

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

	remove_reaction(key)
	remove_timer_expired.emit(key)
