# Wyvernshield Triggers

Attach a bunch of trigger reactions, then do `hit_received(who, how, damage)` and all the reactions will contribute to the received hit.

#

Like, let's say you've got a huge damage calculation. Defense, elemental resistance, percent damage reduction, buffs that reduce damage, dodge chance, block chance, health barrier... Did I forget something? Anyway, just make a `TriggerReaction` for each of them - and attach to the character. They will modify the damage - and do some extra things if a certain defense type activates, or under other conditions.

Whenever you want: start of game, item equipped, status effects applied...

Any order. Priority system is in place.

# Usage

- `TriggerReactionContainer` - add it to a character and connect all references (*if you want to*)
- `TriggerDatabase` - configure triggers and their parameters with types and defaults, which coincide with properties of the triggers' results. There's a `trigger_database.tres` inside `addons/wyvernshield_triggers`, which you can also access from `TriggerReactionContainer`s.
- `TriggerReaction` - can be added to a `TriggerReactionContainer` through the Inspector or

To trigger a trigger, just call the function with its name on the `TriggerReactionContainer` supplying all required parameters. This should return the trigger's result object - its properties are the same as the trigger function's parameters.

To script a trigger reaction, give it a script with the configured functions - function must accept the trigger's result object which can be modified. 

**Example**:
- you have a `healing_received` trigger
- its parameters are `healer : Node, ability : Ability, amount : float, healing_type : int = 0`
- this is the generated interface:

```
func healing_received(healer : Node, ability : Ability, amount : float, healing_type : int = 0) -> HealingReceivedResult:
    var result := HitReceivedResult.new()
    result.healer = healer
    result.ability = ability
    result.amount = amount
    result.healing_type = healing_type
    for x in _trigger_reactions[18]:
        x._applied(self, result)
    
    return result

class HealingReceivedResult extends Resource:
    @export var healer : Node
    @export var ability : Ability
    @export var amount : float
    @export var healing_type : int = 0
    pass
```

- so you can do `var result = reaction_container.healing_received(self, holy_light_ability, 26)` and heal yourself by `result.amount`. If no reactions changed it, it'll be the same as at the input.
- or you could add a reaction that has:

```
func heal_more_at_low_health(container : TriggerReactionContainer, result : RefCounted, reaction : TriggerReaction):
    var current_percentage := float(container.actor.health) / container.attributes.max_health
    if current_percentage < 0.5:
      result.amount *= 1.5
```

- and increases amount of healing applied by 1.5x when under 50% health. `container` is the container that passed the trigger, and has readable references to `actor` and `attributes`.`reaction` can also be read for properties of the reaction resource - and don't forget to configure that resource!
- you could add this trigger reaction to the Container on the scene, or call `add_reaction` or `add_reactions`.

#

Made by Don Tnowe in 2023.

[My Website](https://redbladegames.netlify.app)

[Itch](https://don-tnowe.itch.io)

[Twitter](https://twitter.com/don_tnowe)

Copying and Modification is allowed in accordance to the MIT license, unless otherwise specified. License text is included.
