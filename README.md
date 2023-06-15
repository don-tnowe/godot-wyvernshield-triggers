# Wyvernshield Triggers

Attach a bunch of trigger reactions to `reaction_container`, then do `reaction_container.hit_received(who, how, damage)` and all the reactions will contribute to the received hit.

- Reactions that change the outcome of an action based on conditions - can be 
- Stat modifications that support grouping changes to then remove together - when an item gets unequipped, for example
- Temporary stat changes and reactions
- Custom inspector view for reactions and stat modifications

# Setup

- Give your actors a `TriggerReactionContainer` and/or a `StatSheet`
- The Resources inside these two objects can be defined locally or saved as files.
- To edit trigger parameters and their result object's properties, click the View Database button inside a `TriggerReaction`.

# Trigger Reactions

Like, let's say you've got a huge damage calculation. Defense, elemental resistance, buffs that reduce damage, dodge chance, block chance (*but only with a shield*), health barrier, effects on hit, damage based on monster class... Did I forget something? Anyway, just make a `TriggerReaction` for each of them - and attach to the character. They will modify the damage - and do some extra things if a certain defense type activates, or under other conditions.

Whenever you want: start of game, item equipped, status effects applied...

Any order. Priority system is in place.

## Usage

- `TriggerReactionContainer` - add it to a character and connect all references (*if you want to*)
- `TriggerDatabase` - configure triggers and their parameters with types and defaults, which coincide with properties of the triggers' results. There's a `trigger_database.tres` inside `addons/wyvernshield_triggers`, which you can also access from `TriggerReactionContainer`s.
- `TriggerReaction` - can be added to a `TriggerReactionContainer` through the Inspector or

To trigger a trigger, just call the function with its name on the `TriggerReactionContainer` supplying all required parameters. This should return the trigger's result object - its properties are the same as the trigger function's parameters.

To script a trigger reaction, give it a script with the configured functions - function must accept the trigger's result object which can be modified. 

**Example**:

You have a `healing_received` trigger

Its parameters are `healer : Node, ability : Ability, amount : float, healing_type : int = 0`

If you configure it like that in the database, then on any reaction container you can:

    var result = reaction_container.healing_received(self, holy_light_ability, 26)
    health += result.amount

If no reactions changed `amount`, it'll be the same as at the input.

Or you could add a reaction that has:

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
