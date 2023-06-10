@tool
class_name TriggerReaction
extends Resource

# Auto-generated
enum TriggerType
{
	ABILITY_USED,
	ABILITY_GET_COST,
	HIT_LANDED,
	HIT_RECEIVED,
	MOVE_STATE_CHANGED,
	MAX
}
# Auto-generated end

## The reaction's identifier, for when you'll want to detach it from a [TriggerReactionContainer].
## Reactions with the same ID can't be attached together.
@export var reaction_id := &"":
	set(v):
		reaction_id = v
		resource_name = v.capitalize()

## When this trigger occurs, this reaction responds.
@export var trigger_id : TriggerType = 0

## The reaction's extra parameters to be read by [member reaction_script].
## [b]Note[/b]: if this resource is referenced in several places, this array should not be written to.
## For storing state, add member variables to the [member reaction_script].
@export var params : Array = []

## Higher priority is activated first
@export var priority := 0

@export_group("Behaviour")

## Script with all the functions of the reaction.
## [b]Note:[/b] should not extend [TriggerReaction], it won't be attached to this resource!
@export var reaction_script : Script:
	set(v):
		reaction_script = v
		reaction_instance = v.new()
		if func_applied == &"": return
		func_applied_callable = Callable(v, func_applied)

## Name of the function called when the reaction is attached to a [TriggerReactionContainer]. [br/]
## Can be empty.
## If set, must have the signature: [code](holder : TriggerReactionContainer)[/code]
@export var func_attached : StringName

## Name of the function called when something calls the triggering function of the [TriggerReactionContainer].
## Must have the signature: [code](holder : TriggerReactionContainer, result_to_modify : TriggerReactionContainer.<ResultType>, reaction_resource : TriggerReaction) -> void[/code]
@export var func_applied : StringName:
	set(v):
		func_applied = v
		if reaction_instance == null: return
		func_applied_callable = Callable(reaction_instance, v)
		# Not feeling like adding others. Not gonna be called much anyway

## Name of the function called when the reaction is detached from a [TriggerReactionContainer]. [br/]
## Can be empty.
## If set, must have the signature: [code](holder : TriggerReactionContainer)[/code]
@export var func_detached : StringName

var reaction_instance : RefCounted
var func_applied_callable : Callable


func _applied(holder : TriggerReactionContainer, result_or_params : RefCounted):
	func_applied_callable.call(holder, result_or_params, self)


func _attached(holder : TriggerReactionContainer):
	if func_attached != "":
		holder.call(func_attached, holder)


func _detached(holder : TriggerReactionContainer):
	if func_detached != "":
		holder.call(func_detached, holder)
