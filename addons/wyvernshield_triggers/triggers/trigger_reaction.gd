@tool
class_name TriggerReaction
extends Resource

# Auto-generated
enum TriggerType
{
	MOVE_STATE_CHANGED,
	ABILITY_USED,
	ABILITY_GET_COST,
	HIT_LANDED,
	HIT_RECEIVED,
	APPLY_STAT_DERIVATIVES,
	MAX
}
# Auto-generated end

## The reaction's identifier, for when you'll want to detach it inherit_from a [TriggerReactionContainer].
## Reactions with the same ID can't be attached together.
@export var reaction_id := &"":
	set(v):
		reaction_id = v
		_update_name()

## The reaction's extra parameters to be read by [member reaction_script].
## [b]Note[/b]: if this resource is referenced in several places, this array should not be written to.
## For storing state, add member variables to the [member reaction_script].
@export var params : Array = []

## Higher priority is activated first.
@export var priority := 0

## If not [code]0[/code], the reaction will be temporary, and stop being triggered after this many seconds.
@export var expires_in := 0.0:
	set(v):
		expires_in = max(v, 0)

## Set another reaction to copy its behaviour and override parameters.
var inherit_from : TriggerReaction:
	set(v):
		inherit_from = v
		if v != null:
			reaction_id = v.reaction_id
			priority = v.priority

			trigger_id = v.trigger_id
			reaction_script = v.reaction_script
			func_attached = v.func_attached
			func_applied = v.func_applied
			func_detached = v.func_detached
			if params == null:
				params = v.params.duplicate()

			params.resize(v.params.size())
			for i in params.size():
				if params[i] == null:
					params[i] = v.params[i]

		notify_property_list_changed()
		_update_name()

## When this trigger occurs, this reaction responds.
var trigger_id : TriggerType = 0

## Script with all the functions of the reaction.
## [b]Note:[/b] should not extend [TriggerReaction], it won't be attached to this resource!
var reaction_script : Script:
	set(v):
		if reaction_script != null:
			reaction_script.changed.disconnect(notify_property_list_changed)


		reaction_script = v
		if v != null:
			reaction_instance = v.new()
			if func_applied != &"":
				func_applied_callable = Callable(v, func_applied)

		notify_property_list_changed()
		v.changed.connect(notify_property_list_changed)

## Name of the function called when the reaction is attached to a [TriggerReactionContainer]. [br/]
## Can be empty.
## If set, must have the signature: [code](holder : TriggerReactionContainer)[/code]
var func_attached : StringName

## Name of the function called when something calls the triggering function of the [TriggerReactionContainer].
## Must have the signature: [code](holder : TriggerReactionContainer, result_to_modify : TriggerReactionContainer.<ResultType>, reaction_resource : TriggerReaction) -> void[/code]
var func_applied : StringName:
	set(v):
		func_applied = v
		if reaction_instance == null: return
		func_applied_callable = Callable(reaction_instance, v)
		# Not feeling like adding others. Not gonna be called much anyway

## Name of the function called when the reaction is detached from a [TriggerReactionContainer]. [br/]
## Can be empty.
## If set, must have the signature: [code](holder : TriggerReactionContainer)[/code]
var func_detached : StringName

var reaction_instance : RefCounted
var func_applied_callable : Callable

## Returns a copy of this reaction, but parameters changed.
func with_params(new_params : Array) -> TriggerReaction:
	var new_instance : TriggerReaction = duplicate()
	new_instance.params = new_params
	return new_instance

## Returns a copy of this reaction that will stop being triggered after a certain amount of time, in seconds.
func with_timer(time : float) -> TriggerReaction:
	var new_instance : TriggerReaction = duplicate()
	new_instance.expires_in = time
	return new_instance


func _applied(holder : TriggerReactionContainer, result_or_params : RefCounted):
	func_applied_callable.call(holder, result_or_params, self)


func _attached(holder : TriggerReactionContainer):
	if func_attached != &"":
		holder.call(func_attached, holder)


func _detached(holder : TriggerReactionContainer):
	if func_detached != &"":
		holder.call(func_detached, holder)


func _get_property_list() -> Array:
	var result := []
	result.append_array([
		{
			&"name": "Behaviour",
			&"type": TYPE_INT,
			&"usage": PROPERTY_USAGE_GROUP,
		},
		{
			&"name": "inherit_from",
			&"type": TYPE_OBJECT,
			&"usage": PROPERTY_USAGE_DEFAULT,
			&"hint": PROPERTY_HINT_RESOURCE_TYPE,
			&"hint_string": "TriggerReaction",
			&"class_name": &"TriggerReaction",
		},
	])
	if inherit_from == null:
		result.append_array([
			{
				&"name": "trigger_id",
				&"type": TYPE_INT,
				&"usage": PROPERTY_USAGE_DEFAULT,
				&"hint": PROPERTY_HINT_ENUM,
				&"hint_string": ",".join(TriggerType.keys()).to_lower(),
			},
			{
				&"name": "reaction_script",
				&"type": TYPE_OBJECT,
				&"usage": PROPERTY_USAGE_DEFAULT,
				&"hint": PROPERTY_HINT_RESOURCE_TYPE,
				&"hint_string": "Script",
				&"class_name": &"Script",
			},
		])
		var script_funcs := ""
		if reaction_script != null:
			script_funcs = ",".join(reaction_script.get_script_method_list().map(func(x): return x[&"name"]))

		result.append_array(
			[&"func_applied", &"func_attached", &"func_detached"].map(
				func (x): return {
					&"name": x,
					&"type": TYPE_STRING_NAME,
					&"usage": PROPERTY_USAGE_DEFAULT,
					&"hint": PROPERTY_HINT_ENUM_SUGGESTION if script_funcs != "" else PROPERTY_HINT_NONE,
					&"hint_string": script_funcs,
				}
			)
		)

	return result


func _property_can_revert(property):
	match property:
		&"reaction_id": return inherit_from != null
		&"inherit_from": return inherit_from != null
		&"params": return inherit_from != null
		&"expires_in": return expires_in != 0.0
		&"priority": return inherit_from != null && priority != inherit_from.priority
		&"reaction_script": return reaction_script != null


func _property_get_revert(property):
	match property:
		&"reaction_id": return inherit_from.reaction_id
		&"inherit_from": return null
		&"params": return inherit_from.params.duplicate()
		&"expires_in": return 0.0
		&"priority": return inherit_from.priority
		&"reaction_script": return null


func _update_name():
	resource_name = reaction_id.capitalize()
	if inherit_from != null:
		resource_name += " (OVERRIDE)"

	if resource_path.contains("::"):
		resource_name += " (SUB)"
