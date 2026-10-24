class_name Stats
extends Node
## Base values plus buff modifiers. Every number a buff can change is read
## through get_value(), so adding a buff never touches player or weapon code.
##
## A value is (base + sum of adds) * product of muls. Multiplier-style stats
## (move_speed, damage, ...) have base 1.0, so a buff with mul 1.25 means +25%.

signal changed

const MAX_HEALTH := &"max_health"
const MOVE_SPEED := &"move_speed"
const DAMAGE := &"damage"
const FIRE_RATE := &"fire_rate"
const RELOAD_SPEED := &"reload_speed"
const MAGAZINE_SIZE := &"magazine_size"

@export var base := {
	MAX_HEALTH: 100.0,
	MOVE_SPEED: 1.0,
	DAMAGE: 1.0,
	FIRE_RATE: 1.0,
	RELOAD_SPEED: 1.0,
	MAGAZINE_SIZE: 1.0,
}

var _adds := {}
var _muls := {}


func get_value(stat: StringName) -> float:
	return (float(base.get(stat, 0.0)) + float(_adds.get(stat, 0.0))) * float(_muls.get(stat, 1.0))


func apply_buff(buff: Buff) -> void:
	_adds[buff.stat] = float(_adds.get(buff.stat, 0.0)) + buff.add
	_muls[buff.stat] = float(_muls.get(buff.stat, 1.0)) * buff.mul
	changed.emit()


func clear_buffs() -> void:
	_adds.clear()
	_muls.clear()
	changed.emit()
