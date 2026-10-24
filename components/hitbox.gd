class_name Hitbox
extends StaticBody3D
## Body-part hitbox: rays hit this body and the damage goes to the nearest
## Health above it, or the one at health_path. Lives on CollisionLayers.HITBOXES.
## Ported from origin/sheji/systems/hitbox.gd.

enum BodyPart { HEAD, BODY, LIMB }

const LAYER := CollisionLayers.HITBOXES

@export var body_part := BodyPart.BODY
@export var health_path: NodePath

var health: Health


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	health = _resolve_health()


func apply_hit(amount: float, source: Node = null) -> float:
	if health == null:
		return 0.0
	return health.apply_damage(amount, body_part, source)


func _resolve_health() -> Health:
	if not health_path.is_empty():
		return get_node_or_null(health_path) as Health
	var current := get_parent()
	while current != null:
		for child in current.get_children():
			if child is Health:
				return child
		current = current.get_parent()
	return null
