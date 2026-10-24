class_name Enemy
extends CharacterBody3D
## Soldier AI, simplified from origin/sheji/characters/bots/bot.gd.
## Idles until it sees or hears the player or is shot, then chases, fights in
## short bursts and falls back to cover when hurt. The zone director calls
## setup() with the target and cover points; the enemy never looks them up.

enum State { IDLE, CHASE, ENGAGE, COVER, DEAD }

const EYE_HEIGHT := 1.55
const AIM_HEIGHT := 1.3

@export_category("Perception")
@export var sight_range := 45.0
@export var sight_fov_deg := 120.0
@export var hearing_range := 35.0

@export_category("Combat")
@export var engage_range := 25.0
@export var reaction_time := 0.5
@export var burst_size := 3
@export var burst_interval := 0.14
@export var burst_pause := 1.0
## Cone half-angle of each shot. At 20 m, 2.2 deg lands about 40% on a still player.
@export var accuracy_deg := 2.2
## Enemy bullets are slow, visible projectiles so the player can dodge them.
## Shots aim at where the player is now, with no lead.
@export var projectile_speed := 18.0
## Spread multiplier when the target moves faster than 3 m/s.
@export var moving_target_penalty := 1.6
@export var damage_min := 8.0
@export var damage_max := 12.0

@export_category("Movement")
@export var run_speed := 4.6
@export var strafe_speed := 1.8
@export var turn_speed := 8.0
@export var gravity := 18.0

@export_category("Cover")
@export var cover_search_radius := 18.0
## Cover closer than this to the player is ignored.
@export var cover_min_player_distance := 6.0
@export var cover_time := 2.4
@export var cover_cooldown := 6.0
@export_range(0.0, 1.0) var cover_chance := 0.6

@export_category("Model")
## Which of the model's hand-held meshes to show.
@export var held_weapon := "AK"

## Read by Health to ignore friendly fire.
var team := 1
var state := State.IDLE
var target: CharacterBody3D
var cover_points: Array[CoverPoint] = []

var _last_known := Vector3.ZERO
var _sees_target := false
var _sight_timer := 0.0
var _react_left := 0.0
var _shots_left := 0
var _shot_timer := 0.0
var _cover: CoverPoint
var _cover_left := 0.0
var _cover_ready_at := 0.0
var _strafe_dir := 1.0
var _strafe_left := 0.0
var _hitbox_rids: Array[RID] = []
var _gunshot: AudioStreamWAV

@onready var health: Health = $Health
@onready var _agent: NavigationAgent3D = $Agent
@onready var _anim: AnimationPlayer = $Model/AnimationPlayer
@onready var _audio: AudioStreamPlayer3D = $GunAudio


func _ready() -> void:
	for anim in ["Idle", "Run_Gun", "Walk_Shoot", "Idle_Shoot", "Duck"]:
		_anim.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	for mesh in $Model/CharacterArmature/Skeleton3D/Index1_R.get_children():
		mesh.visible = mesh.name == held_weapon
	_hitbox_rids.append(get_rid())
	for hitbox in find_children("*", "Hitbox", true, false):
		_hitbox_rids.append((hitbox as Hitbox).get_rid())
	_gunshot = ProceduralAudio.generate("gunshot_ak47")
	_audio.stream = _gunshot
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	Events.gunshot.connect(_on_gunshot)
	_anim.play("Idle")


func setup(p_target: CharacterBody3D, p_cover_points: Array[CoverPoint]) -> void:
	target = p_target
	cover_points = p_cover_points


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	if target == null:
		move_and_slide()
		return

	_sight_timer -= delta
	if _sight_timer <= 0.0:
		_sight_timer = 0.1
		_update_sight()

	match state:
		State.IDLE:
			_stop()
			if _sees_target:
				_alert(_target_point())
		State.CHASE:
			_move_to(_last_known, run_speed)
			if _sees_target and _distance_to_target() <= engage_range:
				_enter_engage()
			elif _agent.is_navigation_finished() and not _sees_target:
				state = State.IDLE
			_face(_agent.get_next_path_position() - global_position, delta)
		State.ENGAGE:
			_process_engage(delta)
		State.COVER:
			_process_cover(delta)

	move_and_slide()
	_update_animation()


func _process_engage(delta: float) -> void:
	if not _sees_target or _distance_to_target() > engage_range * 1.2:
		state = State.CHASE
		return
	_face(target.global_position - global_position, delta)

	# Short sidesteps between pauses, so the enemy is not a fixed target.
	_strafe_left -= delta
	if _strafe_left <= 0.0:
		_strafe_dir = [-1.0, 0.0, 1.0].pick_random()
		_strafe_left = randf_range(0.8, 1.6)
	var side := global_basis.x * _strafe_dir * strafe_speed
	velocity.x = side.x
	velocity.z = side.z

	_react_left -= delta
	if _react_left > 0.0:
		return
	_shot_timer -= delta
	if _shot_timer > 0.0:
		return
	if _shots_left <= 0:
		_shots_left = burst_size
	_fire_shot()
	_shots_left -= 1
	_shot_timer = burst_interval if _shots_left > 0 else burst_pause * randf_range(0.8, 1.3)


func _process_cover(delta: float) -> void:
	if global_position.distance_to(_cover.global_position) > 0.6:
		_move_to(_cover.global_position, run_speed)
		_face(_agent.get_next_path_position() - global_position, delta)
		return
	_stop()
	_face(target.global_position - global_position, delta)
	_cover_left -= delta
	if _cover_left <= 0.0:
		_leave_cover()
		if _sees_target:
			_enter_engage()
		else:
			_alert(_last_known)


func _update_sight() -> void:
	var to_target := _target_point() - _eye()
	_sees_target = false
	if to_target.length() > sight_range:
		return
	# Before the first alert the enemy only sees inside its view cone.
	if state == State.IDLE:
		var forward := -global_basis.z
		if forward.angle_to(Vector3(to_target.x, 0.0, to_target.z)) > deg_to_rad(sight_fov_deg * 0.5):
			return
	var query := PhysicsRayQueryParameters3D.create(_eye(), _target_point(), CollisionLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_sees_target = hit.is_empty()
	if _sees_target:
		_last_known = target.global_position


func _alert(position: Vector3) -> void:
	_last_known = position
	_react_left = reaction_time
	state = State.CHASE


func _enter_engage() -> void:
	state = State.ENGAGE
	_react_left = maxf(_react_left, reaction_time * 0.5)


func _fire_shot() -> void:
	var origin := _eye()
	var direction := (_target_point() - origin).normalized()
	var spread := accuracy_deg
	if Vector2(target.velocity.x, target.velocity.z).length() > 3.0:
		spread *= moving_target_penalty
	direction = _random_in_cone(direction, deg_to_rad(spread))

	_audio.pitch_scale = randf_range(0.95, 1.05)
	_audio.play()
	Events.gunshot.emit(global_position)

	var projectile := Projectile.spawn(get_parent(), origin + direction * 0.6, direction, self,
		randf_range(damage_min, damage_max), projectile_speed, _hitbox_rids)
	projectile.max_distance = sight_range


func _try_take_cover() -> bool:
	var best: CoverPoint
	var best_distance := cover_search_radius
	for point in cover_points:
		if point.occupant != null and point.occupant != self:
			continue
		var distance := global_position.distance_to(point.global_position)
		if distance >= best_distance:
			continue
		if point.global_position.distance_to(target.global_position) < cover_min_player_distance:
			continue
		if not _is_hidden_at(point.global_position):
			continue
		best = point
		best_distance = distance
	if best == null:
		return false
	_cover = best
	_cover.occupant = self
	_cover_left = cover_time
	state = State.COVER
	return true


## Whether a crouching enemy at `point` is out of the target's sight.
func _is_hidden_at(point: Vector3) -> bool:
	var from := point + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(from, _target_point(), CollisionLayers.WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _leave_cover() -> void:
	if _cover != null and _cover.occupant == self:
		_cover.occupant = null
	_cover = null
	_cover_ready_at = Time.get_ticks_msec() / 1000.0 + cover_cooldown


func _on_damaged(_amount: float, _part: Hitbox.BodyPart, source: Node) -> void:
	if state == State.DEAD:
		return
	if state == State.IDLE:
		_alert(source.global_position if source is Node3D else _target_point())
		return
	var cover_ready := Time.get_ticks_msec() / 1000.0 >= _cover_ready_at
	if state != State.COVER and cover_ready and randf() < cover_chance:
		_try_take_cover()


func _on_gunshot(position: Vector3) -> void:
	if state == State.IDLE and global_position.distance_to(position) <= hearing_range:
		_alert(position)


func _on_died(_source: Node) -> void:
	_leave_cover()
	state = State.DEAD
	velocity = Vector3.ZERO
	collision_layer = 0
	for hitbox in find_children("*", "Hitbox", true, false):
		(hitbox as Hitbox).collision_layer = 0
	_anim.play("Death")
	Events.enemy_killed.emit(self)


func _move_to(position: Vector3, speed: float) -> void:
	if _agent.target_position.distance_to(position) > 0.5:
		_agent.target_position = position
	if _agent.is_navigation_finished():
		_stop()
		return
	var direction := _agent.get_next_path_position() - global_position
	direction.y = 0.0
	direction = direction.normalized() * speed
	velocity.x = direction.x
	velocity.z = direction.z


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, yaw, minf(turn_speed * delta, 1.0))


func _update_animation() -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.3
	var anim := "Idle"
	match state:
		State.CHASE:
			anim = "Run_Gun" if moving else "Idle"
		State.ENGAGE:
			anim = "Walk_Shoot" if moving else "Idle_Shoot"
		State.COVER:
			anim = "Run_Gun" if moving else "Duck"
	if _anim.current_animation != anim:
		_anim.play(anim, 0.15)


func _eye() -> Vector3:
	return global_position + Vector3.UP * EYE_HEIGHT


func _target_point() -> Vector3:
	return target.global_position + Vector3.UP * AIM_HEIGHT


func _distance_to_target() -> float:
	return global_position.distance_to(target.global_position)


static func _random_in_cone(direction: Vector3, half_angle: float) -> Vector3:
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = direction.cross(Vector3.RIGHT)
	side = side.normalized()
	var tilted := direction.rotated(side, randf() * half_angle)
	return tilted.rotated(direction, randf() * TAU).normalized()
