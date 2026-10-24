class_name BattleVFX
extends Node3D
## Optional local PYROLUX integration. The licensed raw addon is not published.
## A clean checkout without it still runs using project-authored basic effects.

const PYROLUX_PATH := "res://addons/pyrolux_fx/core/pyrolux.gd"
const PRESET_PATH := "res://addons/pyrolux_fx/presets/3d/explosion_grenade.tscn"
const MAX_ACTIVE := 4
const COOLDOWN := 0.16

var _pyrolux: Script
var _preset: PackedScene
var _active: Array[Node] = []
var _last_spawn_ms := -1000
var _explosion_sound: AudioStreamWAV


func _ready() -> void:
	_explosion_sound = ProceduralAudio.generate("explosion_grenade")
	if ResourceLoader.exists(PYROLUX_PATH) and ResourceLoader.exists(PRESET_PATH):
		_pyrolux = load(PYROLUX_PATH) as Script
		var original := load(PRESET_PATH) as PackedScene
		if _pyrolux != null and original != null:
			# Set budgets before the node enters the tree and builds any geometry.
			var prototype := original.instantiate()
			prototype.set("quality", 1) # PyroluxEffect3D.QualitySetting.LOW.
			prototype.set("fireball", 18)
			prototype.set("smoke", 14)
			prototype.set("sparks", 26)
			prototype.set("debris", 8)
			prototype.set("radius", 2.2)
			prototype.set("smoke_time", 2.4)
			prototype.set("scorch_time", 6.0)
			prototype.set("burn_time", 1.2)
			prototype.set("light_shadows", false)
			_preset = PackedScene.new()
			if _preset.pack(prototype) != OK:
				_preset = null
			prototype.free()
	if _preset == null:
		print("PYROLUX is optional and not installed; using basic effects. See docs/ASSETS.md for its original free download and license.")


func uses_pyrolux() -> bool:
	return _pyrolux != null and _preset != null


func explosion(point: Vector3) -> void:
	var kept: Array[Node] = []
	for previous in _active:
		if is_instance_valid(previous):
			kept.append(previous)
	_active = kept
	var now := Time.get_ticks_msec()
	if now - _last_spawn_ms < int(COOLDOWN * 1000.0):
		return
	_last_spawn_ms = now
	if _active.size() >= MAX_ACTIVE:
		var oldest := _active.pop_front() as Node
		if is_instance_valid(oldest):
			oldest.queue_free()
	var effect: Node3D
	if uses_pyrolux():
		# Dynamic call keeps an absent, non-redistributable addon from becoming
		# a hard dependency of the player's script or the game's main scene.
		effect = _pyrolux.call("spawn", self, _preset, point) as Node3D
	else:
		effect = _basic_explosion(point)
	if effect == null:
		return
	effect.set_as_top_level(true)
	_active.append(effect)
	var sound := AudioStreamPlayer3D.new()
	sound.stream = _explosion_sound
	sound.volume_db = -8.0
	sound.unit_size = 12.0
	sound.max_distance = 42.0
	add_child(sound)
	sound.global_position = point
	sound.set_as_top_level(true)
	sound.finished.connect(sound.queue_free)
	sound.play()


func burst(point: Vector3) -> void:
	explosion(point)


func _basic_explosion(point: Vector3) -> Node3D:
	var effect := Node3D.new()
	effect.name = "BasicExplosion"
	add_child(effect)
	effect.global_position = point
	var fire := _sphere(effect, Color(1.0, 0.42, 0.06, 0.85), 0.5)
	var smoke := _sphere(effect, Color(0.2, 0.22, 0.23, 0.55), 0.7)
	smoke.position.y = 0.4
	var fire_material := fire.material_override as StandardMaterial3D
	var smoke_material := smoke.material_override as StandardMaterial3D
	var tween := effect.create_tween().set_parallel(true)
	tween.tween_property(fire, "scale", Vector3.ONE * 3.0, 0.25)
	tween.tween_property(fire_material, "albedo_color:a", 0.0, 0.4)
	tween.tween_property(smoke, "position:y", 1.5, 1.3)
	tween.tween_property(smoke, "scale", Vector3.ONE * 2.5, 1.3)
	tween.tween_property(smoke_material, "albedo_color:a", 0.0, 1.3)
	tween.chain().tween_callback(effect.queue_free)
	return effect


func _sphere(parent: Node3D, color: Color, radius: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh.mesh = sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh
