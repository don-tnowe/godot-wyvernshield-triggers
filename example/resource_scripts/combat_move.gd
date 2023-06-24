class_name CombatMove
extends Resource

@export var scenes : Array[PackedScene]
@export var manacost := 0.0

@export_group("Attack")
@export var damage_multiplier := 1.0
@export var attack_status_reactions : Array[TriggerReaction]
@export var attack_status_stats : StatModification

@export_group("On User")
@export var user_reactions : Array[TriggerReaction]
@export var user_stats : StatModification
