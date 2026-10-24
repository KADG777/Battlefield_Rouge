extends Node
## State of the current run: which zone the player is in and which buffs they
## have picked. Everything here is lost on death; nothing persists between runs.
## Only RunState and the zone director may change it. See ARCHITECTURE.md.

signal changed

## One scene per zone, in play order. Clearing the last one wins the run.
const ZONE_SCENES: Array[String] = [
	"res://maps/zone_1.tscn",
	"res://maps/zone_2.tscn",
]

var zone_index := 0
var buffs: Array[Resource] = []


func _ready() -> void:
	Events.player_died.connect(start_new_run)
	Events.buff_chosen.connect(add_buff)


func start_new_run() -> void:
	zone_index = 0
	buffs.clear()
	changed.emit()


func add_buff(buff: Resource) -> void:
	buffs.append(buff)
	changed.emit()


## Moves to the next zone. Returns false once the last zone is done.
func advance_zone() -> bool:
	if zone_index + 1 >= ZONE_SCENES.size():
		return false
	zone_index += 1
	changed.emit()
	return true


func is_last_zone() -> bool:
	return zone_index == ZONE_SCENES.size() - 1


func zone_scene() -> String:
	return ZONE_SCENES[zone_index]
