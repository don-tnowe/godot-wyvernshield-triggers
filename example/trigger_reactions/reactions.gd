extends RefCounted


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


func evade_chance(container : TriggerReactionContainer, result : RefCounted, _reaction : TriggerReaction):

  # Or you can read from the StatSheet of the container that triggered the reaction.
  var chance : float = container.stats.get_stat(&"dodge_chance", 0.0) * 0.01
  if randf() < chance:

    # Make sure to adjust priority based on which reactions go first
    # You might want to read this damage value elsewhere.
    result.damage = 0


func spawn_damage_numbers(container : TriggerReactionContainer, result : RefCounted, reaction : TriggerReaction):
  var nums : Label3D = reaction.params[0].instantiate()
  container.get_parent().add_sibling(nums)
  nums.position = container.get_parent().global_position + Vector3(randf() - 0.5, 0, randf() - 0.5)
  nums.top_level = true
  if result.damage == 0:
    nums.text = "Evaded!"

  else:
    nums.text = str(floor(result.damage))
