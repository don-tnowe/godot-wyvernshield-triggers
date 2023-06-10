extends EditorProperty


var prop_arrays : Array[Array] = []
var trigger_info : Resource
var trigger_db : Resource
var changing := false


func _init(trigger_info : Resource, trigger_db : Resource):
	self.trigger_info = trigger_info
	self.trigger_db = trigger_db


func _update_property():
	if changing: return
	for x in get_children(): x.queue_free()

	# var line_edit := LineEdit.new()
	# add_child(line_edit)
	# add_focusable(line_edit)
	# line_edit.text = trigger_info.trigger_name
	# line_edit.text_changed.connect(_on_main_name_changed.bind(line_edit))

	var c := VBoxContainer.new()
	add_child(c)
	set_bottom_editor(c)
	var prop_infos : Array = trigger_info.property_infos
	for x in prop_infos:
		prop_arrays.append(get_prop_info_parts(x))
		c.add_child(create_prop_info_view(prop_arrays[-1]))

	var add_button := Button.new()
	add_button.icon = get_theme_icon("Add", "EditorIcons")
	add_button.pressed.connect(_on_add_pressed)
	add_button.text = "Add Element"
	add_button.size_flags_horizontal = SIZE_EXPAND | SIZE_SHRINK_CENTER
	c.add_child(add_button)


func _exit_tree():
	trigger_db.update_scripts.call_deferred()


func create_prop_info_view(info_obj : Array) -> Control:
	var result := HBoxContainer.new()

	var name_edit := LineEdit.new()
	name_edit.text = info_obj[0]
	name_edit.text_changed.connect(_on_trigger_name_changed.bind(info_obj, name_edit))
	name_edit.focus_exited.connect(_on_focus_exited)
	name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	name_edit.tooltip_text = "Property Name"
	result.add_child(name_edit)

	var type_edit := LineEdit.new()
	type_edit.text = info_obj[1]
	type_edit.text_changed.connect(_on_trigger_type_changed.bind(info_obj, type_edit))
	type_edit.focus_exited.connect(_on_focus_exited)
	type_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	type_edit.tooltip_text = "Property Type"
	result.add_child(type_edit)

	var default_edit := LineEdit.new()
	default_edit.text = info_obj[2]
	default_edit.text_changed.connect(_on_trigger_default_changed.bind(info_obj, default_edit))
	default_edit.focus_exited.connect(_on_focus_exited)
	default_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	default_edit.tooltip_text = "Property Default (optional)"
	result.add_child(default_edit)

	var delete_button := Button.new()
	delete_button.icon = get_theme_icon("Remove", "EditorIcons")
	delete_button.pressed.connect(_on_remove_pressed.bind(info_obj))
	result.add_child(delete_button)

	return result


func _on_add_pressed():
	var arr = get_edited_object()[get_edited_property()].duplicate()
	arr.append(get_prop_info_from_parts(["new_property", "int", ""]))

	changing = false
	emit_changed(get_edited_property(), arr)


func _on_remove_pressed(array_to_erase):
	var arr = get_edited_object()[get_edited_property()].duplicate()
	arr.erase(get_prop_info_from_parts(array_to_erase))
	changing = false
	emit_changed(get_edited_property(), arr)


func get_prop_info_parts(from : String) -> Array:
	var found_colon := from.find(":")
	var found_equals := from.find("=")

	var result := ["", "", ""]

	if found_colon == -1:
		result[0] = from.strip_edges()
		return result  # Nothing else to see here.

	if found_equals == -1:
		found_equals = from.length()

	result[0] = from.left(found_colon).strip_edges()

	if found_equals != -1:
		result[1] = from.substr(found_colon + 1, found_equals - found_colon - 1).strip_edges()

	result[2] = from.substr(found_equals + 1).strip_edges()

	return result


func get_prop_info_from_parts(from : Array):
	return from[0] + ((" : " + from[1] + (" = " + from[2] if from[2] != "" else "")) if from[1] != "" else "")


func object_update_prop_infos():
	var result : Array[String] = []
	result.resize(prop_arrays.size())
	for i in prop_arrays.size():
		result[i] = get_prop_info_from_parts(prop_arrays[i])

	get_edited_object().property_infos = result
	changing = true
	emit_changed(get_edited_property(), result)


func _on_main_name_changed(to_name : String, by_control : Control):
	to_name = (to_name
		.to_lower()
		.replace(" ", "_")
		.replace(".", "_")
		.replace(":", "_")
		.replace(",", "_")
		.replace(";", "_")
		.replace("=", "_")
		.replace("-", "_")
		.replace("+", "_")
	)
	get_edited_object().trigger_name = to_name
	changing = true
	emit_changed(get_edited_property(), get_edited_object()[get_edited_property()], &"", true)


func _on_trigger_name_changed(to_name : String, of_info_obj : Array, by_control : Control):
	to_name = (to_name
		.to_lower()
		.replace(" ", "_")
		.replace(".", "_")
		.replace(":", "_")
		.replace(",", "_")
		.replace(";", "_")
		.replace("=", "_")
		.replace("-", "_")
		.replace("+", "_")
	)
	of_info_obj[0] = to_name
	object_update_prop_infos()


func _on_trigger_type_changed(to_type : String, of_info_obj : Array, by_control : Control):
	# Verification. I thought of also adding typed arrays but there may be more edge cases
	# It's gonna make a compile error later anyway.

	# if !to_type in [
	# 	&"int", &"float", &"bool", &"String",
	# 	&"Vector2", &"Vector3", &"Vector4", &"Rect2",
	# 	&"Vector2i", &"Vector3i", &"Vector4i", &"Rect2i",
	# 	&"AABB", &"Color", &"Plane", &"Quaternion",
	# 	&"Transform2D", &"Transform3D", &"Projection", &"Basis",
	# 	&"StringName", &"NodePath", &"RID", &"Dictionary", "Array",
	# ]:
	# 	return

	# if !ClassDB.class_exists(to_type):
	# 	return

	of_info_obj[1] = to_type
	object_update_prop_infos()


func _on_trigger_default_changed(to_value : String, of_info_obj : Array, by_control : Control):
	of_info_obj[2] = to_value
	object_update_prop_infos()


func _on_focus_exited():
	# trigger_info.emit_changed()
	# trigger_db.update_scripts.call_deferred()
	pass
