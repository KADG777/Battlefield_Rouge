class_name Projectile
extends Node3D
## Slow glowing bullet for enemies, so the player can see it coming and step
## aside. Moves in a straight line and sweeps a ray each physics frame from its
## last position, so it cannot tunnel through thin geometry.

const MASK := CollisionLayers.WORLD | CollisionLayers.HITBOXES

var speed := 18.0
var damage := 10.0
var max_distance := 45.0
## The shooter, passed to Health as the damage source (for the team check).
var source: Node
var exclude: Array[RID] = []

var _travelled := 0.0


static func spawn(parent: Node, from: Vector3, direction: Vector3, p_source: Node, p_damage: float,
		p_speed: float, p_exclude: Array[RID]) -> Projectile:
	var projectile := Projectile.new()
	projectile.source = p_source
	projectile.damage = p_damage
	projectile.speed = p_speed
	projectile.exclude = p_exclude
	parent.add_child(projectile)
	projectile.global_position = from
	projectile.look_at(from + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD)
	return projectile


func _ready() -> void:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.045
	capsule.height = 0.7
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.55, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 3.0
	capsule.material = mat
	mesh.mesh = capsule
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Capsules stand along Y; lay it along -Z, the flight direction.
	mesh.rotation.x = PI * 0.5
	add_child(mesh)

	# A camera-facing glow, so the bullet reads clearly even when it flies
	# straight at the player and the tracer is seen end-on.
	var glow := Sprite3D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.7, 1.0))
	gradient.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	glow.texture = texture
	glow.pixel_size = 0.6 / 64.0
	glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glow.shaded = false
	glow.transparent = true
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 0.8
	light.omni_range = 2.0
	add_child(light)


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from - global_basis.z * speed * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		# Sparks on walls only: a puff on the player's own hitbox would sit
		# right in front of the camera. The HUD damage flash covers that case.
		if not hit.collider is Hitbox:
			Impact.spawn(get_parent(), hit.position, hit.normal, false)
		else:
			(hit.collider as Hitbox).apply_hit(damage, source)
		queue_free()
		return
	global_position = to
	_travelled += speed * delta
	if _travelled >= max_distance:
		queue_free()
