class_name Health
extends Node
## Hit points with body-part multipliers. Hitboxes forward hits here.
## Adapted from origin/sheji/systems/damageable.gd with GameState, money,
## respawn and HUD lookups removed: owners react to the signals instead.

signal damaged(amount: float, body_part: Hitbox.BodyPart, source: Node)
signal died(source: Node)

@export var max_health := 100.0
@export var headshot_multiplier := 2.5
@export var limb_multiplier := 0.6
## 0 = player, 1 = enemy. Damage from the same team is ignored.
@export var team := 1
## Optional. When set, max_health follows Stats.MAX_HEALTH.
@export var stats: Stats

var health := 0.0


func _ready() -> void:
	if stats != null:
		max_health = stats.get_value(Stats.MAX_HEALTH)
		stats.changed.connect(_on_stats_changed)
	health = max_health


func is_dead() -> bool:
	return health <= 0.0


## Returns the damage actually dealt. `source` is the attacker's Health owner
## or any node with a `team` property; null means environmental damage.
func apply_damage(amount: float, body_part: Hitbox.BodyPart, source: Node = null) -> float:
	if is_dead():
		return 0.0
	if source != null and "team" in source and source.team == team:
		return 0.0

	var dealt := amount
	if body_part == Hitbox.BodyPart.HEAD:
		dealt *= headshot_multiplier
	elif body_part == Hitbox.BodyPart.LIMB:
		dealt *= limb_multiplier

	health = maxf(health - dealt, 0.0)
	damaged.emit(dealt, body_part, source)
	if is_dead():
		died.emit(source)
	return dealt


func _on_stats_changed() -> void:
	# Raising max health heals by the same amount, so a health buff is felt at once.
	var new_max := stats.get_value(Stats.MAX_HEALTH)
	health = clampf(health + new_max - max_health, 0.0, new_max)
	max_health = new_max
