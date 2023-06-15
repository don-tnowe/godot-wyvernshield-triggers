extends Label3D

@export var reactions : TriggerReactionContainer
@export var stats : StatSheet

var status_effects := []


func _ready():
	if reactions != null:
		reactions.remove_timer_added.connect(_on_status_added)
		reactions.remove_timer_changed.connect(_on_status_changed)
		reactions.remove_timer_expired.connect(_on_status_expired)

	if stats != null:
		stats.clear_timer_added.connect(_on_status_added)
		stats.clear_timer_changed.connect(_on_status_changed)
		stats.clear_timer_expired.connect(_on_status_expired)


func _update_view():
	text = "\n".join(status_effects)


func _on_status_added(key : StringName, _time_seconds : float, index_in_queue : int):
	status_effects.insert(index_in_queue, key)
	_update_view()


func _on_status_changed(key : StringName, _time_seconds : float, index_in_queue : int):
	status_effects.erase(key)
	status_effects.insert(index_in_queue, key)
	_update_view()


func _on_status_expired(key : StringName):
	status_effects.erase(key)
	_update_view()
