extends Node3D
## A single CC0 high-detail AK47 for the player's first-person view only.

const WEAPON_SCENE = preload("res://assets/weapons/AK47/SKM_AK47.fbx")
const COLOR = preload("res://assets/weapons/AK47/T_AK47_C.png")
const NORMAL = preload("res://assets/weapons/AK47/T_AK47_N.png")
const PACKED = preload("res://assets/weapons/AK47/T_AK47_RMAO.png")


func _ready() -> void:
	var model := WEAPON_SCENE.instantiate() as Node3D
	model.name = "SteinAK47"
	add_child(model)
	model.rotation.y = PI
	var points: Array[Vector3] = []
	_collect_points(model, points)
	if not points.is_empty():
		var box := AABB(points[0], Vector3.ZERO)
		for point in points:
			box = box.expand(point)
		var factor := 0.8 / maxf(box.size.x, maxf(box.size.y, box.size.z))
		model.scale *= factor
		# Keep the butt forward of the near plane at the existing hip/ADS offsets.
		model.position = -box.get_center() * factor + Vector3(0.0, 0.0, -0.25)
	var material := StandardMaterial3D.new()
	material.albedo_texture = COLOR
	material.normal_enabled = true
	material.normal_texture = NORMAL
	material.normal_scale = 0.65
	material.roughness = 0.85
	material.roughness_texture = PACKED
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.metallic = 0.8
	material.metallic_texture = PACKED
	material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.ao_enabled = true
	material.ao_texture = PACKED
	material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	_assign_material(model, material)


func _collect_points(node: Node, points: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var box := mesh.get_aabb()
		var local := global_transform.affine_inverse() * mesh.global_transform
		for index in range(8):
			points.append(local * box.get_endpoint(index))
	for child in node.get_children():
		_collect_points(child, points)


func _assign_material(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_assign_material(child, material)
