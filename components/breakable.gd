class_name BreakableProp
extends StaticBody3D

## Portable demonstration prop. Its origin sits on the floor at the bottom center.
## `blast()` receives an already range-checked explosion: power 1 deals full health.

signal broken(kind: StringName, at: Vector3)

const DESTRUCTION_SCRIPT = preload("res://addons/destruction/destruction.gd")
const CRATE_SIZE := Vector3(1.5, 1.25, 1.2)
const WALL_SIZE := Vector3(3.0, 2.4, 0.32)
const SHARD_LIFETIME := 3.0

@export_enum("crate", "wall") var prop_kind: String = "crate"
@export var max_health: float = 40.0
## Zone-owned persistent fragment parent; defaults to this prop's parent.
@export var fragment_container: Node3D

var health: float
var _broken := false
var _destruction: Node
var _intact_collision: CollisionShape3D
var _scatter_power := 4.0
static var _fragment_scenes: Dictionary = {}


func _ready() -> void:
	if prop_kind != "wall":
		prop_kind = "crate"
	if prop_kind == "wall" and is_equal_approx(max_health, 40.0):
		max_health = 100.0
	max_health = maxf(max_health, 1.0)
	health = max_health
	collision_layer = CollisionLayers.WORLD
	collision_mask = CollisionLayers.WORLD
	add_to_group("breakable")
	_build_intact()
	_destruction = DESTRUCTION_SCRIPT.new()
	_destruction.name = "Destruction"
	_destruction.fragmented = _get_fragment_scene(prop_kind)
	_destruction.shard_container = fragment_container if is_instance_valid(fragment_container) else get_parent()
	_destruction.collision_layer = CollisionLayers.DEBRIS
	_destruction.collision_mask = CollisionLayers.WORLD
	_destruction.fade_delay = 2.35
	_destruction.shrink_delay = 2.6
	_destruction.animation_length = SHARD_LIFETIME
	add_child(_destruction)


func take_damage(amount: float, _hit_position: Vector3 = Vector3.ZERO) -> void:
	if _broken or amount <= 0.0 or not is_finite(amount):
		return
	health = maxf(health - amount, 0.0)
	if health <= 0.0:
		_break_once()


## A shared damage interface for world colliders, without any run-state dependency.
func apply_damage(amount: float, _source: Node = null) -> float:
	var before := health
	take_damage(amount)
	return before - health


func is_broken() -> bool:
	return _broken


func blast(origin: Vector3, power: float = 1.0) -> void:
	if _broken or power <= 0.0 or not is_finite(power):
		return
	_scatter_power = clampf(5.5 * power, 1.0, 18.0)
	take_damage(max_health * power, origin)


func _break_once() -> void:
	if _broken:
		return
	_broken = true
	# Remove the intact obstruction immediately; queued deletion finishes this frame.
	collision_layer = 0
	collision_mask = 0
	_intact_collision.set_deferred("disabled", true)
	broken.emit(StringName(prop_kind), global_position)
	_destruction.destroy(_scatter_power)


func _build_intact() -> void:
	var size := WALL_SIZE if prop_kind == "wall" else CRATE_SIZE
	_intact_collision = CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	_intact_collision.shape = box_shape
	_intact_collision.position.y = size.y * 0.5
	add_child(_intact_collision)
	var visual := _get_fragment_scene(prop_kind).instantiate() as Node3D
	visual.name = "IntactVisual"
	add_child(visual)
	if prop_kind == "crate":
		var strap := _material(Color("364653"), 0.65)
		for x in [-0.46, 0.46]:
			_add_box(visual, "MetalBand", Vector3(0.08, 1.28, 1.22),
				Vector3(x, CRATE_SIZE.y * 0.5, 0.0), strap)
	else:
		var warning := _material(Color("d0a046"), 0.0)
		_add_box(visual, "BreachMarker", Vector3(0.52, 0.13, 0.012),
			Vector3(0.0, 1.35, WALL_SIZE.z * 0.5 + 0.012), warning)


static func _get_fragment_scene(kind: String) -> PackedScene:
	if _fragment_scenes.has(kind):
		return _fragment_scenes[kind]
	var root := Node3D.new()
	root.name = "CrateFragments" if kind == "crate" else "WallFragments"
	if kind == "wall":
		var concrete := _material(Color("7c878b"), 0.0)
		for row in range(3):
			for column in range(4):
				_add_box(root, "Concrete_%d_%d" % [row, column],
					Vector3(0.742, 0.792, WALL_SIZE.z),
					Vector3(-1.125 + column * 0.75, 0.4 + row * 0.8, 0.0), concrete)
	else:
		var wood := _material(Color("8f704c"), 0.0)
		var end_wood := _material(Color("a08256"), 0.0)
		_add_box(root, "Bottom", Vector3(1.5, 0.12, 1.2), Vector3(0, 0.06, 0), wood)
		_add_box(root, "Lid", Vector3(1.5, 0.12, 1.2), Vector3(0, 1.19, 0), wood)
		for side in [-1, 1]:
			_add_box(root, "Side_%d" % side, Vector3(0.12, 1.01, 1.2),
				Vector3(side * 0.69, 0.625, 0), end_wood)
			for half in [-1, 1]:
				_add_box(root, "Panel_%d_%d" % [side, half], Vector3(0.628, 1.01, 0.12),
					Vector3(half * 0.315, 0.625, side * 0.54), wood)
	var scene := PackedScene.new()
	var result := scene.pack(root)
	assert(result == OK, "Could not pack prop fragments")
	root.free()
	_fragment_scenes[kind] = scene
	return scene


static func _add_box(parent: Node3D, part_name: String, size: Vector3,
		at: Vector3, material: StandardMaterial3D) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	part.mesh = mesh
	part.position = at
	parent.add_child(part)
	part.owner = parent


static func _material(color: Color, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.85
	return material
