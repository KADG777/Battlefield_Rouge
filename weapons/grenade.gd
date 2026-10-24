class_name Grenade
extends RigidBody3D
## A local, bounded blast. Actors receive one BODY hit per Health component.
## WORLD blocks the blast. Same-team damage and player self-damage are disabled.

signal detonated(point: Vector3)

@export var fuse_time := 1.4
@export var blast_radius := 5.0
@export var blast_damage := 100.0
@export var edge_damage_scale := 0.3

var team := 0
var effects: Node3D
var _source_ref: WeakRef
var _damage_multiplier := 1.0
var _fuse_left := 1.4
var _detonated := false


func _ready() -> void:
	collision_layer = CollisionLayers.PROJECTILES
	collision_mask = CollisionLayers.WORLD
	mass = 0.35
	continuous_cd = true
	var surface := PhysicsMaterial.new()
	surface.bounce = 0.3
	surface.friction = 0.75
	physics_material_override = surface
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.11
	shape.shape = sphere
	add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.22
	mesh.radial_segments = 12
	mesh.rings = 6
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.25, 0.12)
	material.metallic = 0.55
	material.roughness = 0.7
	visual.material_override = material
	add_child(visual)
	_fuse_left = fuse_time


func launch(source: Node, initial_velocity: Vector3, effect_node: Node3D = null, damage_multiplier := 1.0) -> void:
	if source != null:
		_source_ref = weakref(source)
		if "team" in source:
			team = source.team
	effects = effect_node
	_damage_multiplier = maxf(damage_multiplier, 0.0)
	linear_velocity = initial_velocity
	angular_velocity = Vector3(5.0, 2.0, 3.0)


func _physics_process(delta: float) -> void:
	if _detonated:
		return
	_fuse_left -= delta
	if _fuse_left <= 0.0:
		detonate()


func detonate() -> void:
	if _detonated or not is_inside_tree():
		return
	_detonated = true
	var point := global_position
	# Gather visibility before changing any cover, so one blast cannot damage
	# actors or props through a wall that the same blast has just destroyed.
	var actor_hits := _actor_hits(point)
	var prop_hits := _prop_hits(point)
	var source := _damage_source()
	for entry: Dictionary in actor_hits:
		var target = entry.health
		if is_instance_valid(target):
			target.apply_damage(entry.amount, Hitbox.BodyPart.BODY, source)
	for entry: Dictionary in prop_hits:
		var target = entry.target
		if not is_instance_valid(target):
			continue
		if target.has_method("apply_damage"):
			target.apply_damage(entry.amount, source)
		elif target.has_method("take_damage"):
			target.take_damage(entry.amount, point)
	if is_instance_valid(effects) and effects.has_method("explosion"):
		effects.explosion(point)
	Events.gunshot.emit(point)
	detonated.emit(point)
	queue_free()


func _actor_hits(point: Vector3) -> Array[Dictionary]:
	var candidates := {}
	for result: Dictionary in _overlap(point, CollisionLayers.HITBOXES):
		var hitbox = result.collider
		if not hitbox is Hitbox:
			continue
		var target: Health = hitbox.health
		if target == null or target.is_dead() or target.team == team:
			continue
		var sample := _sample_point(hitbox)
		var distance := point.distance_to(sample)
		if distance > blast_radius or not _visible_from(point, sample, hitbox.get_rid()):
			continue
		var key := target.get_instance_id()
		if not candidates.has(key) or distance < float(candidates[key].distance):
			candidates[key] = {"health": target, "distance": distance, "amount": _damage_at(distance)}
	var hits: Array[Dictionary] = []
	for entry: Dictionary in candidates.values():
		hits.append(entry)
	return hits


func _prop_hits(point: Vector3) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var seen := {}
	for result: Dictionary in _overlap(point, CollisionLayers.WORLD):
		var target = result.collider
		if not is_instance_valid(target) or not (target.has_method("apply_damage") or target.has_method("take_damage")):
			continue
		var key: int = target.get_instance_id()
		if seen.has(key):
			continue
		seen[key] = true
		var sample := _sample_point(target)
		var distance := point.distance_to(sample)
		if distance <= blast_radius and _visible_from(point, sample, target.get_rid()):
			hits.append({"target": target, "amount": _damage_at(distance)})
	return hits


func _overlap(point: Vector3, mask: int) -> Array[Dictionary]:
	var sphere := SphereShape3D.new()
	sphere.radius = blast_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, point)
	query.collision_mask = mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 128)


func _sample_point(target: Node3D) -> Vector3:
	for child in target.get_children():
		if child is CollisionShape3D and not child.disabled:
			return child.global_position
	return target.global_position


func _visible_from(origin: Vector3, target: Vector3, target_rid: RID) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, target, CollisionLayers.WORLD)
	query.exclude = [get_rid(), target_rid]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _damage_at(distance: float) -> float:
	return blast_damage * _damage_multiplier * lerpf(1.0, edge_damage_scale, clampf(distance / blast_radius, 0.0, 1.0))


func _damage_source() -> Node:
	if _source_ref != null:
		var source = _source_ref.get_ref()
		if is_instance_valid(source):
			return source
	# The grenade retains its team even if its original thrower no longer exists.
	return self
