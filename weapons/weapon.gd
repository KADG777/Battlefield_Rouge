class_name Weapon
extends Node3D
## Fires hitscan rays from the camera centre, tracks ammo and reloads.
## Rewritten from origin/sheji/weapons/weapon_system.gd as a single weapon with
## no shop, loadout or GameState. Numbers that buffs change are read from Stats.
##
## The weapon never moves the camera itself: it emits `recoil` and the owner
## applies it, and the owner tells it whether it is aiming / moving / airborne.

signal fired
signal ammo_changed(current: int, reserve: int)
signal reload_started(duration: float)
signal reload_finished
signal hit_landed(headshot: bool, killed: bool)
## Degrees of camera kick for this shot. `manual` is the fraction that stays.
signal recoil(pitch: float, yaw: float, manual: float)

const SHOOT_MASK := CollisionLayers.WORLD | CollisionLayers.HITBOXES

@export var data: WeaponData
@export var stats: Stats
@export var camera: Camera3D
## The shooter's body, excluded from the ray. Its `team` filters friendly fire.
@export var shooter: CollisionObject3D

var ammo := 0
var reserve := 0
var aiming := false
var moving := false
var airborne := false

var _cooldown := 0.0
var _spread := 0.0
var _reload_left := 0.0
var _pattern_index := 0
var _view: Node3D
## Optional `Muzzle/Flash` node in the view scene, shown for one frame per shot.
var _flash: Node3D
var _flash_left := 0.0
var _audio: AudioStreamPlayer
var _gunshot: AudioStreamWAV
var _reload_sound: AudioStreamWAV
var _dry_sound: AudioStreamWAV
var _known_capacity := 0


func _ready() -> void:
	_known_capacity = magazine_capacity()
	ammo = _known_capacity
	reserve = data.reserve_ammo
	_gunshot = ProceduralAudio.generate(data.gunshot_sound)
	_reload_sound = ProceduralAudio.generate("reload")
	_dry_sound = ProceduralAudio.generate("dry")
	_audio = AudioStreamPlayer.new()
	_audio.max_polyphony = 4
	add_child(_audio)
	_view = data.view_scene.instantiate() if data.view_scene != null else _placeholder_view()
	add_child(_view)
	_view.position = data.hip_position
	_flash = _view.get_node_or_null("Muzzle/Flash")
	if stats != null:
		stats.changed.connect(_on_stats_changed)


func _on_stats_changed() -> void:
	var capacity := magazine_capacity()
	# The director applies carried buffs after the weapon has entered the zone.
	# Keep an initially full magazine full; do not refill a partly fired one.
	if ammo == _known_capacity and capacity > _known_capacity:
		ammo = capacity
	elif ammo > capacity:
		reserve += ammo - capacity
		ammo = capacity
	_known_capacity = capacity
	ammo_changed.emit(ammo, reserve)


func add_reserve(amount: int, limit := 180) -> int:
	var added := mini(maxi(amount, 0), maxi(limit - reserve, 0))
	reserve += added
	if added > 0:
		ammo_changed.emit(ammo, reserve)
	return added


func magazine_capacity() -> int:
	return ceili(data.magazine_size * _stat(Stats.MAGAZINE_SIZE))


func is_reloading() -> bool:
	return _reload_left > 0.0


func reload_progress() -> float:
	if not is_reloading():
		return 0.0
	return 1.0 - _reload_left / _reload_duration(ammo == 0)


func spread_degrees() -> float:
	var total := (data.ads_spread if aiming else data.hip_spread) + _spread
	if airborne:
		total *= data.airborne_spread_scale
	elif moving:
		total *= data.move_spread_scale
	return total


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _flash != null and _flash_left > 0.0:
		_flash_left -= delta
		_flash.visible = _flash_left > 0.0
	_spread = move_toward(_spread, 0.0, data.spread_recovery * delta)
	var target := data.ads_position if aiming else data.hip_position
	_view.position = _view.position.lerp(target, minf(14.0 * delta, 1.0))

	if is_reloading():
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
		return

	if Input.is_action_just_released("fire"):
		_pattern_index = 0
	if Input.is_action_just_pressed("reload"):
		try_reload()
		return
	var trigger := Input.is_action_pressed("fire") if data.fire_mode == WeaponData.FireMode.AUTO \
		else Input.is_action_just_pressed("fire")
	if trigger and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		try_fire()


func try_fire() -> bool:
	if _cooldown > 0.0 or is_reloading():
		return false
	if ammo <= 0:
		if reserve > 0:
			try_reload()
		elif Input.is_action_just_pressed("fire"):
			_play(_dry_sound, -4.0)
		return false

	ammo -= 1
	_cooldown = data.fire_interval / _stat(Stats.FIRE_RATE)
	var direction := _spread_direction(-camera.global_basis.z, spread_degrees())
	_spread = minf(_spread + data.spread_per_shot, data.max_spread)
	_shoot_ray(camera.global_position, direction)

	_play(_gunshot)
	if _flash != null:
		_flash.rotation.z = randf() * TAU
		_flash.visible = true
		_flash_left = 0.04
	_view.position.z += 0.04
	recoil.emit(data.camera_kick, data.camera_kick * _next_pattern_value(), data.recoil_manual)
	fired.emit()
	Events.gunshot.emit(global_position)
	ammo_changed.emit(ammo, reserve)
	if ammo == 0 and reserve > 0:
		try_reload()
	return true


func try_reload() -> void:
	if is_reloading() or reserve <= 0 or ammo >= magazine_capacity():
		return
	_reload_left = _reload_duration(ammo == 0)
	_play(_reload_sound, -2.0)
	reload_started.emit(_reload_left)


func _finish_reload() -> void:
	_reload_left = 0.0
	var taken := mini(magazine_capacity() - ammo, reserve)
	ammo += taken
	reserve -= taken
	reload_finished.emit()
	ammo_changed.emit(ammo, reserve)


func _reload_duration(empty: bool) -> float:
	var base_time := data.reload_time_empty if empty else data.reload_time_tactical
	return base_time / _stat(Stats.RELOAD_SPEED)


func _shoot_ray(origin: Vector3, direction: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * data.max_range, SHOOT_MASK)
	if shooter != null:
		query.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.collider
	var effects_parent := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	Impact.spawn(effects_parent, hit.position, hit.normal, collider is Hitbox)
	if collider is Hitbox:
		var hitbox := collider as Hitbox
		var distance := origin.distance_to(hit.position)
		var dealt := hitbox.apply_hit(data.damage * _stat(Stats.DAMAGE) * _falloff(distance), shooter)
		if dealt > 0.0:
			hit_landed.emit(hitbox.body_part == Hitbox.BodyPart.HEAD, hitbox.health.is_dead())
	elif collider.has_method("apply_damage"):
		var distance := origin.distance_to(hit.position)
		collider.apply_damage(data.damage * _stat(Stats.DAMAGE) * _falloff(distance), shooter)
	elif collider.has_method("take_damage"):
		var distance := origin.distance_to(hit.position)
		collider.take_damage(data.damage * _stat(Stats.DAMAGE) * _falloff(distance), hit.position)


func _falloff(distance: float) -> float:
	if distance <= data.falloff_start:
		return 1.0
	if distance >= data.falloff_end:
		return data.min_damage_scale
	var t := (distance - data.falloff_start) / maxf(data.falloff_end - data.falloff_start, 0.001)
	return lerpf(1.0, data.min_damage_scale, t)


func _spread_direction(direction: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return direction
	var rad := deg_to_rad(degrees)
	var basis := camera.global_basis
	return direction.rotated(basis.x, randf_range(-rad, rad)).rotated(basis.y, randf_range(-rad, rad)).normalized()


func _next_pattern_value() -> float:
	var value := 0.35 if _pattern_index % 2 == 0 else -0.35
	if not data.recoil_pattern.is_empty():
		value = data.recoil_pattern[_pattern_index % data.recoil_pattern.size()]
	_pattern_index += 1
	return value


func _stat(stat: StringName) -> float:
	return stats.get_value(stat) if stats != null else 1.0


func _play(stream: AudioStream, volume_db := 0.0) -> void:
	_audio.stream = stream
	_audio.volume_db = volume_db
	_audio.play()


func _placeholder_view() -> Node3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.1, 0.5)
	mesh.mesh = box
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh
