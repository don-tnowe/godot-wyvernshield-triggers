extends CharacterBody3D

@export var move_max_speed := 4.0
@export var reactions : TriggerReactionContainer


func _physics_process(_delta):
	set_velocity(Vector3(0, -8.0, 0))
	set_up_direction(Vector3.UP)
	set_floor_stop_on_slope_enabled(true)
	move_and_slide()
	

func damage(by : CharacterBody3D, by_ability : Node, amount : float):
	var result := reactions.hit_received(by, by_ability, amount)
	return result
