@tool
extends EditorPlugin

var inspector_plugins := [
	preload("res://addons/wyvernshield_triggers/editor/inspector_plugin.gd").new(),
]


func _enter_tree():
	add_custom_type("TriggerReactionContainer", "Node", load("res://addons/wyvernshield_triggers/triggers/reaction_container.gd"), null)
	add_custom_type("TriggerInfo", "Resource", load("res://addons/wyvernshield_triggers/editor/trigger_info.gd"), null)
	add_custom_type("TriggerReaction", "Resource", load("res://addons/wyvernshield_triggers/triggers/trigger_reaction.gd"), null)
	add_custom_type("StatSheet", "Node", load("res://addons/wyvernshield_triggers/stats/stat_sheet.gd"), null)
	add_custom_type("StatModification", "Resource", load("res://addons/wyvernshield_triggers/stats/stat_modification.gd"), null)
	for x in inspector_plugins:
		add_inspector_plugin(x)
		x.plugin = self


func _exit_tree():
	remove_custom_type("TriggerReactionContainer")
	remove_custom_type("TriggerInfo")
	remove_custom_type("TriggerReaction")
	remove_custom_type("StatSheet")
	remove_custom_type("StatModification")
	for x in inspector_plugins:
		remove_inspector_plugin(x)
