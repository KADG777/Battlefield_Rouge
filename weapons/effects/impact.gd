class_name Impact
extends GPUParticles3D
## One-shot burst where a bullet lands, facing along the surface normal.
## Sparks on world geometry, a dark red puff on hitboxes. Frees itself.

const SPARK := preload("res://assets/vfx/spark.png")
const PUFF := preload("res://assets/vfx/puff.png")


static func spawn(parent: Node, point: Vector3, normal: Vector3, flesh: bool) -> void:
	var impact := Impact.new()
	impact._setup(flesh)
	parent.add_child(impact)
	impact.global_position = point + normal * 0.02
	if absf(normal.dot(Vector3.UP)) < 0.99:
		impact.look_at(point + normal, Vector3.UP)
	else:
		impact.look_at(point + normal, Vector3.FORWARD)
	impact.emitting = true
	impact.finished.connect(impact.queue_free)


func _setup(flesh: bool) -> void:
	one_shot = true
	explosiveness = 1.0
	amount = 6 if flesh else 10
	lifetime = 0.35 if flesh else 0.25

	var process := ParticleProcessMaterial.new()
	# Particles fly out along -Z, which look_at() pointed along the normal.
	process.direction = Vector3(0, 0, -1)
	process.spread = 35.0 if flesh else 60.0
	process.initial_velocity_min = 0.6 if flesh else 2.0
	process.initial_velocity_max = 1.4 if flesh else 5.0
	process.gravity = Vector3(0, -6.0, 0)
	process.scale_min = 0.6
	process.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	process_material = process

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.12 if flesh else 0.08)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if flesh else BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = PUFF if flesh else SPARK
	mat.albedo_color = Color(0.55, 0.08, 0.06) if flesh else Color(1.0, 0.8, 0.45)
	quad.material = mat
	draw_pass_1 = quad
