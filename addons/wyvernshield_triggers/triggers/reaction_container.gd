@tool
class_name TriggerReactionContainer
extends Node

## The actor this Trigger Holder is attached to.
@export var actor : Node

## Reactions to add on ready.
@export var initial_reactions : Array[TriggerReaction]:
	set(v):
		initial_reactions = v
		for i in v.size():
			if v[i] == null:
				v[i] = TriggerReaction.new()

## Click to view the database. Set automatically.
@export var database : Resource

@export_group("References (Optional)")
@export var actor_visual : Node
@export var actor_data : Resource
@export var attributes : Node
@export var inventory : Node
@export var camera : Node
@export var animation : AnimationTree
@export var ui : Node
@export var hitbox : Node
@export var hurtbox : Node
@export var shape : Node
@export var nodes : Array[Node]
@export var resources : Array[Resource]

var _trigger_reactions : Array[Array] = []


func _ready():
	database = load("res://addons/wyvernshield_triggers/trigger_database.tres")
	_trigger_reactions.resize(TriggerReaction.TriggerType.MAX)
	for i in _trigger_reactions.size():
		_trigger_reactions[i] = []

	add_reactions(initial_reactions)


## Adds a reaction.
## [b]Note:[/b] Reactions with both the same [member TriggerReaction.reaction_id] and [member TriggerReaction.trigger_id] cannot be on the same trigger holder.
func add_reaction(reaction : TriggerReaction):
	for x in _trigger_reactions[reaction.trigger_id]:
		if x.reaction_id == reaction.reaction_id:
			return

	reaction._attached(self)
	_trigger_reactions[reaction.trigger_id].append(reaction)
	_trigger_reactions.sort_custom(func(a, b): return a.priority > b.priority)

## Adds several reactions.
## [b]Note:[/b] Reactions with both the same [member TriggerReaction.reaction_id] and [member TriggerReaction.trigger_id] cannot be on the same trigger holder.
func add_reactions(reactions : Array):
	var affected := {}
	for x in reactions:
		if find_reaction(x.reaction_id, x.trigger_id) == null:
			affected[x.trigger_id] = true
			x._attached(self)
			_trigger_reactions[x.trigger_id].append(x)

	for k in affected:
		_trigger_reactions[k].sort_custom(func(a, b): return a.priority > b.priority)

## Detaches the reaction with the specified one's IDs.
## Returns the removed reaction, or [code]null[/code] if not found.
func remove_reaction(like_reaction : TriggerReaction) -> TriggerReaction:
	var arr := _trigger_reactions[like_reaction.trigger_id]
	var id := like_reaction.reaction_id
	for i in arr.size():
		if arr[i].reaction_id == id:
			arr.remove_at(i)
			arr[i]._detached(self)
			return arr[i]

	return null

## Returns a reaction with the specified IDs, or [code]null[/code] if not found.
func find_reaction(reaction_id : StringName, trigger_id : TriggerReaction.TriggerType) -> TriggerReaction:
	var arr := _trigger_reactions[trigger_id]
	for i in arr.size():
		if arr[i].reaction_id == reaction_id:
			return arr[i]

	return null


# Auto-generated

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
	for x in _trigger_reactions[0]:
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
	for x in _trigger_reactions[1]:
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
	for x in _trigger_reactions[2]:
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
	for x in _trigger_reactions[3]:
		x._applied(self, result)
	
	return result


class MoveStateChangedResult extends Resource:
	var old_state
	var new_state
	pass


func move_state_changed(old_state, new_state) -> MoveStateChangedResult:
	var result := MoveStateChangedResult.new()
	result.old_state = old_state
	result.new_state = new_state
	for x in _trigger_reactions[4]:
		x._applied(self, result)
	
	return result

# Auto-generated end
