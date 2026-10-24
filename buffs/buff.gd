class_name Buff
extends Resource
## One run-only upgrade. Changes a single Stats value; see Stats.get_value().

@export var title := ""
@export_multiline var description := ""
@export var stat: StringName = Stats.DAMAGE
@export var add := 0.0
@export var mul := 1.0
