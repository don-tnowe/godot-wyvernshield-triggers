extends EditorInspectorPlugin

const PropertyInfosProperty := preload("res://addons/wyvernshield_triggers/editor/inspector_property.gd")
const TriggerInfo := preload("res://addons/wyvernshield_triggers/editor/trigger_info.gd")

var last_viewed_object
var plugin : EditorPlugin


func _can_handle(object):
	if &"trigger_holder_script" in object && &"manual_update" in object:
		return true

	if &"trigger_name" in object && &"property_infos" in object:
		return true

	if object is TriggerReaction:
		return true

	return false


func _parse_begin(object):
	if &"trigger_holder_script" in object && &"manual_update" in object:
		last_viewed_object = object
		return true


func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	if name == &"property_infos":
		add_property_editor(name, PropertyInfosProperty.new(object, last_viewed_object))
		return true

	if name == &"inherit_from" && object is TriggerReaction:
		var button = Button.new()
		var container = PanelContainer.new()
		container.add_child(button)
		add_custom_control(container)
		container.ready.connect(func(): _stylize_db_button(button, container), CONNECT_ONE_SHOT)
		return false

	return false


func _stylize_db_button(button, container):
	button.text = "View&Edit Database"
	button.tooltip_text = "Click to edit database containing the list of triggers and their parameters."
	button.icon = load("res://addons/wyvernshield_triggers/icons/trigger_reaction.svg")
	button.pressed.connect(_edit_db)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size.x = button.get_minimum_size().x + 32
	container.add_theme_stylebox_override("panel", button.get_theme_stylebox("sub_inspector_property_bg0", "Editor"))


func _edit_db():
	plugin.get_editor_interface().edit_resource.call_deferred(load("res://addons/wyvernshield_triggers/database.tres"))
