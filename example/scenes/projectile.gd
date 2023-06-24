extends Area3D

signal target_hit(target, damage_result)

@export var velocity := Vector3.ZERO
@export var sender : Node
@export var sent_by_move : CombatMove
@export var lifetime := 8.0
@export var damage := 8.0


func _ready():
	area_entered.connect(_on_area_entered)


func launch(base_damage : float, by_move : CombatMove, with_velocity : Vector3, from_sender : Node):
	damage = base_damage * by_move.damage_multiplier
	sent_by_move = by_move
	velocity = with_velocity
	sender = from_sender


func _physics_process(delta : float):
	position += velocity * delta
	lifetime -= delta
	if lifetime < 0: queue_free()


func _on_area_entered(area : Area3D):
	var target_parent := area.get_parent()
	if area.is_in_group("hurtbox") && target_parent != sender:
		target_hit.emit(area, target_parent.damage(sender, sent_by_move, damage))
		target_parent.reactions.add_reactions(sent_by_move.attack_status_reactions)
		if sent_by_move.attack_status_stats != null:
			sent_by_move.attack_status_stats.apply(target_parent.stats)
