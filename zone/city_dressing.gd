extends Node3D
## Visual dressing around the existing 60 m navigation arena.
## Generated arena geometry and zone-owned breakables own navigation obstacles.

@export_enum("City intersection", "Central plaza") var district: int = 0

const CITY := "res://assets/city/"
const RUINS := "res://assets/ruins/"
const LAYERS := preload("res://components/collision_layers.gd")

var _scenes: Dictionary = {}
var _materials: Dictionary = {}


func _ready() -> void:
	_build_apron()
	_build_skyline()
	_build_streets()
	_build_rubble()
	set_meta("layout", "city_intersection" if district == 0 else "central_plaza")
	set_meta("free_assets", "Quaternius Standard, Majadroid, Poly Haven")
	set_meta("original_cover_routes_preserved", true)


func _build_apron() -> void:
	# Connect every external building base to visible ground. This surface
	# is deliberately absent from navigation_geometry and has no collision;
	# the generated 60 m arena remains the only playable area.
	var ground := MeshInstance3D.new()
	ground.name = "ExternalCityGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 240)
	ground.mesh = plane
	ground.position.y = -0.12
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(CITY + "T_Concrete_Asphalt_BaseColor.png")
	material.albedo_color = Color(0.83, 0.85, 0.84)
	material.roughness = 0.98
	material.uv1_scale = Vector3(48, 48, 48)
	ground.material_override = material
	add_child(ground)


func _build_skyline() -> void:
	# Nearest facade is beyond x=30 / z=-30; all original enemy spawns,
	# cover points and the capture circle remain inside an unobstructed arena.
	var near_specs := [
		["Building_Small_1.gltf", Vector3(-39, 0, 14), 18.0, PI * 0.5],
		["Building_Medium_2_001.gltf", Vector3(40, 0, 13), 24.0, -PI * 0.5],
		["Building_Large_2.gltf", Vector3(-43, 0, -15), 25.0, PI * 0.5],
		["Building_Small_1.gltf", Vector3(40, 0, -16), 21.0, -PI * 0.5],
		["Building_Medium_2_001.gltf", Vector3(-13, 0, -42), 24.0, 0.0],
		["Building_Large_2.gltf", Vector3(15, 0, -44), 26.0, 0.0],
	]
	for spec: Array in near_specs:
		var model := _asset(CITY + spec[0], spec[1], Vector3(0, spec[2], 0), spec[3])
		if model != null:
			var bounds := _bounds(model)
			var body := StaticBody3D.new()
			body.name = "OutsideFacadeCollision"
			body.collision_layer = LAYERS.WORLD
			body.collision_mask = LAYERS.ACTORS
			body.position = spec[1] + Vector3(0, bounds.size.y * 0.5, 0)
			body.rotation.y = spec[3]
			add_child(body)
			var collider := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = bounds.size * Vector3(0.96, 1, 0.96)
			collider.shape = shape
			body.add_child(collider)
	var far_specs := [
		["building-01.fbx", Vector3(-58, 0, -10), 42.0, 0.1],
		["building-03.fbx", Vector3(59, 0, -20), 47.0, -0.2],
		["building-05.fbx", Vector3(-30, 0, -72), 44.0, 0.3],
		["building-07.fbx", Vector3(26, 0, -76), 39.0, -0.15],
	]
	for spec: Array in far_specs:
		_asset(RUINS + spec[0], spec[1], Vector3(0, spec[2], 0), spec[3])


func _build_streets() -> void:
	# Street_2Lane travels along its local X axis: the asphalt is X +/-3,
	# Z +/-3, while the curb extends to Z +/-6. Its min Y is the asphalt.
	# Raise that actual surface above Floor, rather than exposing only curbs.
	var road_centers: Array = [19.0, 7.0, -23.0] if district == 0 else [24.0, 12.0, 1.5]
	for road_z: float in road_centers:
		var length := 9.0 if district == 1 and is_equal_approx(road_z, 1.5) else 12.0
		_asset(CITY + "Street_2Lane.gltf", Vector3(0, 0.012, road_z), Vector3(length, 0.04, 12), PI * 0.5)
	if district == 0:
		_asset(CITY + "Street_4WayIntersection.gltf", Vector3(0, 0.012, -8), Vector3(24.6, 0.04, 24.6))
		# A broad east/west crossing frames the first objective.
		for side_x: float in [-18.0, 18.0]:
			_asset(CITY + "Street_2Lane.gltf", Vector3(side_x, 0.012, -8), Vector3(18, 0.04, 12))
	else:
		var plaza := MeshInstance3D.new()
		plaza.name = "CentralPlazaPaving"
		var plane := PlaneMesh.new()
		plane.size = Vector2(28, 24)
		plaza.mesh = plane
		plaza.position = Vector3(0, 0.018, -15)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(CITY + "T_Concrete_BaseColor.png")
		mat.normal_enabled = true
		mat.normal_texture = load(CITY + "T_Concrete_Normal.png")
		mat.roughness = 0.92
		mat.uv1_scale = Vector3(10, 10, 10)
		plaza.material_override = mat
		add_child(plaza)
	# Edge details stay near arena walls, away from the original four/six
	# enemies and pre-existing cover points. Their individual simple bodies
	# participate in navigation; the external city and visual ground do not.
	for side: float in [-1.0, 1.0]:
		for detail_z: float in [-18.0, 2.0, 20.0]:
			var bollard := _asset(CITY + "Prop_Bollard.gltf", Vector3(side * 26.0, 0.02, detail_z), Vector3(0, 0.95, 0))
			_prop_collision(bollard, "BollardCollision")
		for planter_z: float in [-12.0, 12.0]:
			var planter := _asset(CITY + "Prop_Planter_Single.gltf", Vector3(side * 26.3, 0.02, planter_z), Vector3(0, 0.8, 0))
			_prop_collision(planter, "PlanterCollision")
	for detail_z: float in [-20.0, 7.0]:
		_asset(CITY + "Prop_ManholeCover.gltf", Vector3(3, 0.025, detail_z), Vector3(0.9, 0.025, 0.9))


func _prop_collision(visual: Node3D, label: String) -> void:
	if visual == null:
		return
	var bounds := _bounds(visual)
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = LAYERS.WORLD
	body.collision_mask = LAYERS.ACTORS
	body.position = visual.position + bounds.position + bounds.size * 0.5
	body.rotation.y = visual.rotation.y
	add_child(body)
	body.add_to_group("navigation_geometry")
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bounds.size
	collider.shape = shape
	body.add_child(collider)


func _build_rubble() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/rubble/rubble_diff_1k.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/rubble/rubble_nor_gl_1k.png")
	mat.roughness_texture = load("res://assets/rubble/rubble_rough_1k.jpg")
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.uv1_scale = Vector3(2, 2, 2)
	for side: float in [-1.0, 1.0]:
		for patch_z: float in [-23.0, -5.0, 16.0]:
			var mesh := MeshInstance3D.new()
			mesh.name = "RubbleGroundDetail"
			var plane := PlaneMesh.new()
			plane.size = Vector2(6, 8)
			mesh.mesh = plane
			mesh.material_override = mat
			mesh.position = Vector3(side * 24.5, 0.026, patch_z)
			add_child(mesh)


func _asset(path: String, at: Vector3, target: Vector3, turn: float = 0.0) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("Missing licensed city asset: " + path)
		return null
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var scene: PackedScene = _scenes[path]
	var instance := scene.instantiate() as Node3D
	var holder := Node3D.new()
	holder.name = "CityAsset"
	add_child(holder)
	holder.add_child(instance)
	if path.begins_with(CITY):
		_fix_vertex_masks(instance)
	var bounds := _bounds(holder)
	var factor := target.y / bounds.size.y if target.y > 0 and bounds.size.y > 0.001 else 1.0
	var fit := Vector3(factor, factor, factor)
	if target.x > 0 and bounds.size.x > 0.001:
		fit.x = target.x / bounds.size.x
	if target.z > 0 and bounds.size.z > 0.001:
		fit.z = target.z / bounds.size.z
	instance.scale *= fit
	instance.position = Vector3(-(bounds.position.x + bounds.size.x * 0.5) * fit.x, -bounds.position.y * fit.y, -(bounds.position.z + bounds.size.z * 0.5) * fit.z)
	holder.position = at
	holder.rotation.y = turn
	return holder


func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var visual := child as MeshInstance3D
		var transform_to_root: Transform3D = node.global_transform.affine_inverse() * visual.global_transform
		var box: AABB = transform_to_root * visual.get_aabb()
		result = result.merge(box) if initialized else box
		initialized = true
	return result


func _fix_vertex_masks(node: Node3D) -> void:
	# Red/white COLOR_0 data in Standard is a mask, not road paint.
	# Keep authored PBR textures; no paid Source wear shader is bundled.
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for child in meshes:
		var visual := child as MeshInstance3D
		for surface in range(visual.get_surface_override_material_count()):
			var original := visual.get_active_material(surface)
			if original is BaseMaterial3D:
				var key := original.get_instance_id()
				if not _materials.has(key):
					var clean := original.duplicate() as BaseMaterial3D
					clean.vertex_color_use_as_albedo = false
					_materials[key] = clean
				visual.set_surface_override_material(surface, _materials[key])
