extends CharacterBody3D

@export var projectile_scene : PackedScene
@export var reactions : TriggerReactionContainer
@export var anim : AnimationPlayer

@export_group("Parameters")
@export var move_maxspeed := 8.0
@export var move_accel := 32.0
@export var move_brake := 64.0
@export var projectile_speed := 24.0

var last_input_direction := Vector3.FORWARD


func _process(_delta):
	if Input.is_action_just_pressed("ui_accept"):
		use_attack()


func _physics_process(delta):
	var input_vec := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	var velocity_h := Vector2(velocity.x, velocity.z)
	var speed_delta := move_brake
	if input_vec != Vector2.ZERO:
		# Changes speed at `move_brake` if pushing against velocity vec, `move_accel` if forwards or sideways
		speed_delta = lerp(move_brake, move_accel, min(input_vec.dot(velocity_h.normalized()) + 1, 1))
		last_input_direction = Vector3(input_vec.x, 0, input_vec.y).normalized()
		anim.play("run")

	else:
		anim.play("idle")

	velocity_h = velocity_h.move_toward(input_vec * move_maxspeed, delta * speed_delta)
	velocity = Vector3(velocity_h.x, 0, velocity_h.y)
	if input_vec.x != 0:
		$"Visual/Flip".scale.x = sign(input_vec.x)

	move_and_slide()


func use_attack():
	var original_projectile := projectile_scene.instantiate()
	original_projectile.position = position
	add_sibling(original_projectile)
	original_projectile.launch(last_input_direction * projectile_speed, self)
	var result := reactions.ability_used(null, null, [original_projectile])
	for x in result.spawned_nodes:
		x.target_hit.connect(_on_target_hit)


func damage(by : CharacterBody3D, by_ability : Node, amount : float):
	var result := reactions.hit_received(by, by_ability, amount)
	return result


func _on_target_hit(target, damage_result):
	var _result := reactions.hit_landed(target, damage_result.ability, damage_result.damage)
	# Do whatever with result
