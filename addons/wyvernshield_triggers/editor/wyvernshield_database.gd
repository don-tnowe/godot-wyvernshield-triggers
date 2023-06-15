@tool
extends Resource

const TriggerInfo := preload("res://addons/wyvernshield_triggers/editor/trigger_info.gd")

## List of triggers that activate [TriggerReaction]s. [br]
## Call the trigger's [code]trigger_name[/code] like it's a function to trigger all reactions.
@export var triggers : Array[TriggerInfo]:
	set(v):
		triggers = v
		for i in v.size():
			if v[i] == null:
				v[i] = TriggerInfo.new()
				pass

			if !v[i].changed.is_connected(_on_trigger_changed):
				v[i].changed.connect(_on_trigger_changed)

@export var trigger_holder_script : Script
@export var trigger_reaction_script : Script
@export var manual_update : bool:
	set(v): update_scripts()


func update_scripts():
	# Enum
	inject_lines_into_script(trigger_reaction_script,
		"enum TriggerType\n{\n\t"
		+ ",\n\t".join(range(triggers.size()).map(func(i): return triggers[i].trigger_name.to_upper()))
		+ ",\n\tMAX\n}"
	)
	# Classes and methods
	inject_lines_into_script(trigger_holder_script,
		"\n"
		+ "\n\n\n".join(range(triggers.size()).map(func(i): return triggers[i].to_code(i)))
		+ "\n"
	)


func inject_lines_into_script(scr : Script, lines : String, first_line : String = "# Auto-generated", last_line : String = "# Auto-generated end"):
	var source := scr.source_code
	var char_start := 0
	var char_end := source.length()
	var cur_line_start := 0
	for x in source.split("\n"):
		if x == first_line:
			char_start = cur_line_start

		if x == last_line:
			char_end = cur_line_start + x.length()
			break

		cur_line_start += x.length() + 1

	scr.source_code = (
		source.left(char_start)
		+ first_line + "\n"
		+ lines
		+ "\n" + last_line
		+ source.substr(char_end)
	)
	scr.reload.call_deferred()
	ResourceSaver.save(scr)


func _on_trigger_changed():
	# update_scripts.call_deferred()  # Stalls the editor. Must find a way to do it with a delay
	pass
