@tool
class_name TriggerInfo
extends Resource

## Trigger name, specified in [code]snake_case[/code].
@export var trigger_name := &"new_trigger":
	set(v):
		trigger_name = v
		emit_changed()
## If [code]true[/code], the result object created by the trigger call will contain a copy of the values provided to the trigger call, inside its [code]trigger_input_values[/code] property.
@export var keep_initial_params := false
## Trigger parameters, specified in format [code]name : datatype = default[/code]. Default is optional.
@export var property_infos : Array[String]


func validate_infos():
	trigger_name = StringName(trigger_name
		.to_snake_case()
		.replace(" ", "_")
		.replace(",", "_")
		.replace(".", "_")
		.replace(":", "")
	)
	resource_name = trigger_name.capitalize()
	for i in property_infos.size():
		var prop_name_end := property_infos[i].find(" :")
		if prop_name_end == -1: prop_name_end = property_infos[i].length() + 1
		var prop_name := property_infos[i].left(prop_name_end).strip_edges()
		property_infos[i] = (prop_name
			.to_lower()
			.replace(" ", "_")
			.replace(",", "_")
			.replace(".", "_")
			.replace(":", "")
		) + property_infos[i].substr(prop_name_end)


func just_name(from : String):
	var found := from.find(" ")
	return from.left(found) if found != -1 else from


func to_code(index : int) -> String:
	validate_infos()

	var lines : Array[String] = []
	var trigger_snake := trigger_name.to_lower().strip_edges()
	var trigger_class := trigger_name.capitalize().replace(" ", "").strip_edges() + "Result"

	# class SkillUsedResult extends RefCounted:
	# > var trigger_input_values : SkillUsedResult
	# > var user : CombatActor
	# > var skill : Skill
	# > var direction : Vector2 = Vector2.ZERO
	lines.append("class " + trigger_class + " extends RefCounted:")
	if keep_initial_params:
		lines.append("\tvar trigger_input_values : " + trigger_class)

	for x in property_infos:
		lines.append("\tvar " + x)

	lines.append("\tpass\n\n")
	# func skill_used(user : CombatActor, skill : Skill, direction : Vector2 = Vector2.ZERO):
	# > var result := SkillUsedResult.new(user, skill, direction)
	# > result.trigger_input_values = SkillUsedResult.new(user, skill, direction)
	# > if _trigger_reactions[7].size() > 0:
	# > > _process_reactions(result, 7, 0, _trigger_reactions[7][-1].priority)
	# > trigger_fired.emit(7, result)
	# > return result
	lines.append("func " + trigger_snake + "(" + ", ".join(property_infos) + ") -> " + trigger_class + ":")
	lines.append("\tvar result := " + trigger_class + ".new()")
	if keep_initial_params:
		lines.append("\tresult.trigger_input_values = " + trigger_class + ".new()")

	for x in property_infos:
		lines.append("\tresult." + just_name(x) + " = " + just_name(x))
		if keep_initial_params:
			lines.append("\tresult.trigger_input_values." + just_name(x) + " = " + just_name(x))

	lines.append("\tif _trigger_reactions[%s].size() > 0:" % index)
	lines.append("\t\t_process_reactions(result, %s, 0, _trigger_reactions[%s][-1].priority)" % [index, index])
	lines.append("\t")
	lines.append("\ttrigger_fired.emit(%s, result)" % index)
	lines.append("\treturn result")

	return "\n".join(lines)
