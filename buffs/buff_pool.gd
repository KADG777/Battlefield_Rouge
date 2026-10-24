class_name BuffPool
## Every buff that can be offered after a capture.

const ALL: Array[Buff] = [
	preload("res://buffs/rapid_fire.tres"),
	preload("res://buffs/hollow_point.tres"),
	preload("res://buffs/field_armor.tres"),
	preload("res://buffs/light_boots.tres"),
	preload("res://buffs/extended_mag.tres"),
	preload("res://buffs/quick_hands.tres"),
]


## `count` different buffs, in random order. The same buff may be offered
## again in a later zone, and picking it twice stacks.
static func pick(count: int) -> Array[Buff]:
	var choices := ALL.duplicate()
	choices.shuffle()
	return choices.slice(0, count)
