# SPDX-FileCopyrightText: 2023 Jummit
# SPDX-License-Identifier: MIT
# Local compatibility changes are listed in LOCAL_CHANGES.md.

@tool
@icon("destruction_icon.svg")
class_name Destruction
extends Node

## Jummit's v7.2 pre-fractured mesh destruction, adapted for Godot 4.7.
## The intact parent is removed and each mesh fragment becomes a convex rigid body.

@export var fragmented: PackedScene: set = set_fragmented
@export var shard_container: Node

@export_group("Animation")
@export var fade_delay := 2.0
@export var shrink_delay := 2.0
## Total fragment lifetime, including both delays.
@export var animation_length := 3.0

@export_group("Collision")
@export_flags_3d_physics var collision_layer := 1
@export_flags_3d_physics var collision_mask := 1

# Resource-only caches do not retain orphaned instantiated scene nodes.
static var _cached_scenes: Dictionary = {}
static var _cached_shapes: Dictionary = {}
var _modified_materials: Dictionary = {}
var _destroyed := false


func destroy(explosion_power := 1.0) -> void:
	if _destroyed:
		return
	if not get_parent() is Node3D or not fragmented:
		push_error("Destruction needs a Node3D parent and a fragmented scene.")
		return
	if not is_instance_valid(shard_container):
		shard_container = get_parent().get_parent()
	if not is_instance_valid(shard_container) or shard_container == get_parent():
		push_error("Destruction needs a persistent shard container outside its parent.")
		return
	_destroyed = true
	for shard: Dictionary in _get_shards():
		_add_shard(shard, explosion_power)
	get_parent().queue_free()


func _get_shards() -> Array:
	if not _cached_scenes.has(fragmented):
		var root := fragmented.instantiate()
		var shards: Array = []
		for child in root.get_children():
			if not child is MeshInstance3D:
				continue
			var shard_mesh := child as MeshInstance3D
			if not shard_mesh.mesh:
				continue
			if not _cached_shapes.has(shard_mesh.mesh):
				_cached_shapes[shard_mesh.mesh] = shard_mesh.mesh.create_convex_shape()
			shards.append({
				"mesh": shard_mesh.mesh,
				"transform": shard_mesh.transform,
				"material_override": shard_mesh.material_override,
			})
		root.free()
		_cached_scenes[fragmented] = shards
	return _cached_scenes[fragmented]


func set_fragmented(to: PackedScene) -> void:
	fragmented = to
	if is_inside_tree() and Engine.is_editor_hint():
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	return ["No fragmented version set"] if not fragmented else []


func _add_shard(original: Dictionary, explosion_power: float) -> void:
	var intact := get_parent() as Node3D
	var source_mesh: Mesh = original["mesh"]
	var source_transform: Transform3D = original["transform"]
	var body := RigidBody3D.new()
	body.name = "DestructionShard"
	body.collision_layer = collision_layer
	body.collision_mask = collision_mask
	var mesh := MeshInstance3D.new()
	var shape := CollisionShape3D.new()
	mesh.mesh = source_mesh
	mesh.scale = source_transform.basis.get_scale() * intact.global_basis.get_scale()
	shape.scale = mesh.scale
	shape.shape = _cached_shapes[source_mesh]
	body.add_child(mesh)
	body.add_child(shape)
	shard_container.add_child(body, true)
	body.add_to_group("destruction_shards")
	body.global_transform = Transform3D(
		intact.global_basis.orthonormalized() * source_transform.basis.orthonormalized(),
		intact.to_global(source_transform.origin)
	)
	var source_material: Material = original["material_override"]
	if not source_material and source_mesh.get_surface_count() > 0:
		source_material = source_mesh.surface_get_material(0)
	mesh.material_override = source_material
	var lifetime := maxf(animation_length, 0.05)
	var tween := get_tree().create_tween().bind_node(body)
	tween.set_parallel(true)
	if fade_delay >= 0.0 and source_material is StandardMaterial3D:
		if not _modified_materials.has(source_material):
			var modified := source_material.duplicate() as StandardMaterial3D
			modified.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var transparent := modified.albedo_color
			transparent.a = 0.0
			tween.tween_property(modified, "albedo_color", transparent,
				maxf(lifetime - fade_delay, 0.01)).set_delay(minf(fade_delay, lifetime))
			_modified_materials[source_material] = modified
		mesh.material_override = _modified_materials[source_material]
	body.apply_impulse(_random_direction() * explosion_power,
		-source_transform.origin.normalized())
	if shrink_delay >= 0.0:
		tween.tween_property(mesh, "scale", Vector3.ZERO,
			maxf(lifetime - shrink_delay, 0.01)).set_delay(minf(shrink_delay, lifetime))
	tween.tween_callback(body.queue_free).set_delay(lifetime)


static func _random_direction() -> Vector3:
	return (Vector3(randf(), randf(), randf()) - Vector3.ONE / 2.0).normalized() * 2.0
