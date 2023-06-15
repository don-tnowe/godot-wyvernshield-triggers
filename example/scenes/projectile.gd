extends Area3D

signal target_hit(target, damage_result)

@export var velocity := Vector3.ZERO
@export var damage := 8.0
@export var sender : Node
@export var lifetime := 8.0


func _ready():
	area_entered.connect(_on_area_entered)


func launch(with_damage : float, with_velocity : Vector3, from_sender : Node):
	damage = with_damage
	velocity = with_velocity
	sender = from_sender


func _physics_process(delta):
	position += velocity * delta
	lifetime -= delta
	if lifetime < 0: queue_free()


func _on_area_entered(area):
	if area.is_in_group("hurtbox") && area.get_parent() != sender:
		target_hit.emit(area, area.get_parent().damage(sender, null, damage))
