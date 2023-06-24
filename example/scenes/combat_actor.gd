class_name CombatActor
extends CharacterBody3D

@export var move_max_speed := 4.0
@export var reactions : TriggerReactionContainer
@export var stats : StatSheet


func damage(by : CharacterBody3D, by_ability : CombatMove, amount : float) -> TriggerReactionContainer.HitReceivedResult:
	var result := reactions.hit_received(by, by_ability, amount)
	return result
