extends RefCounted


func damage_calculation(container : TriggerReactionContainer, result : RefCounted, _reaction : TriggerReaction):
	# You can read from the StatSheet of the container that triggered the reaction.
	var chance : float = container.stats.get_stat(&"dodge_chance", 0.0) * 0.01
	if randf() < chance:

		# Make sure to adjust priority based on which reactions go first
		# You might want to read this damage value elsewhere.
		result.damage = 0

	else:
		# If not dodged, makes sense to apply defense stat.
		result.damage *= (
			100.0 / (100.0 + container.stats.get_stat(&"defense", 1.0))
		)

## Params: Chance, Spread Angle
func double_projectile_chance(_container : TriggerReactionContainer, result : RefCounted, reaction : TriggerReaction):
	# You can use the reaction's params property to affect the outcome.
	var chance : float = reaction.params[0]
	if randf() < chance:
		var rotate_rad : float = deg_to_rad(reaction.params[1])
		var new_spawned : Array[Node] = []
		for x in result.spawned_nodes:
			var clone : Node = x.duplicate()
			x.add_sibling(clone)
			x.velocity = x.velocity.rotated(Vector3.UP, rotate_rad)
			clone.velocity = clone.velocity.rotated(Vector3.UP, -rotate_rad)
			new_spawned.append(clone)

		# Results can be both read from and written to.
		result.spawned_nodes.append_array(new_spawned)

## Params: Damage Multiplier, Max Distance
func chain_hits_on_self(container : TriggerReactionContainer, result : RefCounted, reaction : TriggerReaction):
	if result.from == null:
		# Reaction can only be triggered by direct damage.
		return

	# trigger_input_values references INITIAL damage, before reactions such as damage reduction.
	_chain_hit(container.get_parent(), result.trigger_input_values.damage * reaction.params[0], reaction.params[1])

## Params: Damage Multiplier, Max Distance
func chain_hits_on_target(_container : TriggerReactionContainer, result : RefCounted, reaction : TriggerReaction):
	_chain_hit(result.target, result.unmitigated_damage * reaction.params[0], reaction.params[1])


func _chain_hit(parent : Node3D, damage : float, max_distance : float):
	var parent_pos : Vector3 = parent.global_position
	var parent_siblings := parent.get_parent().get_children()

	# NOTE: this is a slow implementation for this example. Please, use an optimization algorithm.
	var valid_targets := []
	for x in parent_siblings:
		if x != parent && x is CombatActor && parent_pos.distance_squared_to(x.global_position) < max_distance * max_distance:
			valid_targets.append(x)

	# NOTE: Changing the reaction's priority modifies the damage dealt by this reaction!
	# Defense/evasion calculations have a priority of 1000.
	# Putting the priority higher than this will apply the attack's original damage,
	#   and lower will apply the damage dealt after calculations.
	# If you set it lower than Damage Numbers (in example: -1000), the numbers will show incorrect damage :/
	var selected_target : Node3D = valid_targets.pick_random()
	if selected_target == null:
		return

	var new_node : Node3D = load("res://example/scenes/vfx/vfx_lightning.tscn").instantiate()
	selected_target.add_child(new_node)
	selected_target.damage(null, null, damage)

## Params: Damage Multiplier, Radius
func explode_on_target(_container : TriggerReactionContainer, result : RefCounted, reaction : TriggerReaction):
	_explosive_hit(result.target, result.unmitigated_damage * reaction.params[0], reaction.params[1])


func _explosive_hit(parent : Node3D, damage : float, max_distance : float):
	var parent_pos : Vector3 = parent.global_position
	var parent_siblings := parent.get_parent().get_children()

	# NOTE: this is a slow implementation for this example. Please, use an optimization algorithm.
	# NOTE: Changing the reaction's priority modifies the damage dealt by this reaction!
	# Defense/evasion calculations have a priority of 1000.
	# Putting the priority higher than this will apply the attack's original damage,
	#   and lower will apply the damage dealt after calculations.
	# If you set it lower than Damage Numbers (in example: -1000), the numbers will show incorrect damage :/
	for x in parent_siblings:
		if x != parent && x is CombatActor && parent_pos.distance_squared_to(x.global_position) <= max_distance * max_distance:
			var new_node : Node3D = load("res://example/scenes/vfx/vfx_fire.tscn").instantiate()
			x.add_child(new_node)
			x.damage(null, null, damage)

## Params: Label Scene
func spawn_damage_numbers(container : TriggerReactionContainer, result : RefCounted, reaction : TriggerReaction):
	var nums : Label3D = reaction.params[0].instantiate()
	container.get_parent().add_sibling(nums)
	nums.position = container.get_parent().global_position + Vector3(randf() - 0.5, 0, randf() - 0.5)
	nums.top_level = true
	if result.damage == 0:
		nums.text = "Evaded!"

	else:
		nums.text = str(floor(result.damage))
