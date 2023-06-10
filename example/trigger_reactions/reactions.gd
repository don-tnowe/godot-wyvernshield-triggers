extends RefCounted


func double_projectile_chance(_container : TriggerReactionContainer, result : RefCounted, reaction : TriggerReaction):
  var chance : float = reaction.params[0]
  if randf() < chance:
    var rotate_rad : float = deg_to_rad(reaction.params[1])
    for x in result.spawned_nodes:
      var clone : Node = x.duplicate()
      x.add_sibling(clone)
      x.velocity = x.velocity.rotated(Vector3.UP, rotate_rad)
      clone.velocity = clone.velocity.rotated(Vector3.UP, -rotate_rad)


func evade_chance(_container : TriggerReactionContainer, result : RefCounted, reaction : TriggerReaction):
  var chance : float = reaction.params[0]
  if randf() < chance:
    result.damage = 0


func spawn_damage_numbers(container : TriggerReactionContainer, result : RefCounted, reaction : TriggerReaction):
  var nums : Label3D = reaction.params[0].instantiate()
  container.get_parent().add_sibling(nums)
  nums.position = container.get_parent().global_position + Vector3(randf() - 0.5, 0, randf() - 0.5)
  nums.top_level = true
  if result.damage == 0:
    nums.text = "Evaded!"

  else:
    nums.text = str(result.damage)
