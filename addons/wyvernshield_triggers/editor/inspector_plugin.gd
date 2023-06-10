extends EditorInspectorPlugin

const PropertyInfosProperty := preload("res://addons/wyvernshield_triggers/editor/inspector_property.gd")
const TriggerInfo := preload("res://addons/wyvernshield_triggers/editor/trigger_info.gd")

var last_viewed_database


func _can_handle(object):
	if &"trigger_holder_script" in object && &"manual_update" in object:
		return true

	if &"trigger_name" in object && &"property_infos" in object:
		return true

	return false


func _parse_begin(object):
	if &"trigger_holder_script" in object && &"manual_update" in object:
		last_viewed_database = object
		return true


func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide):
	if name == &"property_infos":
		add_property_editor(name, PropertyInfosProperty.new(object, last_viewed_database))
		return true

	return false
