class_name ZoneDirector
extends Node
## Runs one zone from start to finish:
##   1. bakes navigation, applies the run's buffs, hands enemies their target;
##   2. when every enemy is dead, opens the capture point;
##   3. on capture, offers a buff and loads the next zone, or wins the run;
##   4. on the player's death, shows the end screen and restarts from zone 1.
## Only this node and RunState change run state (see ARCHITECTURE.md).

signal objective_changed(text: String)
signal enemies_changed(alive: int, total: int)
signal supply_changed(text: String)

const BUFF_SELECT := preload("res://ui/buff_select.tscn")
const RUN_END := preload("res://ui/run_end.tscn")
const BUFF_CHOICES := 3
const BREAKABLE := preload("res://components/breakable.gd")
const SUPPLY_AMMO := 30
const RESERVE_LIMIT := 180
const ZONE_TITLES := ["废城路口", "中央广场"]

@export var navigation_region: NavigationRegion3D
@export var capture_point: CapturePoint

var objective := ""
var enemies_total := 0
## Zone number and buff count when this zone started, for the end screen;
## RunState is already reset by the time player_died reaches us.
var zone_index := 0
var _alive: Array[Enemy] = []
var _ended := false
var _player: Player
var _beacon: Label3D
var _supply_root: Node3D
var _supply_poll := 0.0
var _navigation_rebaking := false
var _navigation_dirty := false


func _enter_tree() -> void:
	add_to_group("zone_director")


func _ready() -> void:
	zone_index = RunState.zone_index

	var player := get_tree().get_first_node_in_group("player") as Player
	_player = player
	for buff: Buff in RunState.buffs:
		player.stats.apply_buff(buff)
	_spawn_breakables()
	_mark_capture_point()

	var cover_points: Array[CoverPoint] = []
	for node in get_tree().get_nodes_in_group("cover_point"):
		cover_points.append(node as CoverPoint)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.setup(player, cover_points)
		# Wait for the first bake/map sync before NavigationAgent queries begin.
		enemy.set_physics_process(false)
		_alive.append(enemy)
	enemies_total = _alive.size()
	_rebake_navigation.call_deferred()

	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_died.connect(_on_player_died)
	capture_point.captured.connect(_on_point_captured)
	_set_objective("消灭所有敌人")


func _on_enemy_killed(enemy: Node) -> void:
	if not enemy in _alive:
		return
	_alive.erase(enemy)
	enemies_changed.emit(_alive.size(), enemies_total)
	if _alive.is_empty():
		Events.zone_cleared.emit(zone_index)
		capture_point.open()
		_beacon.text = "%s\n据点已开放" % ZONE_TITLES[zone_index]
		_beacon.modulate = Color(0.35, 0.8, 1.0)
		_set_objective("前往据点并占领")


func _on_point_captured() -> void:
	Events.point_captured.emit(zone_index)
	if RunState.is_last_zone():
		Events.run_won.emit()
		_show_end("胜利", "攻下全部 %d 个战区" % RunState.ZONE_SCENES.size())
		return
	_set_objective("选择一个增益")
	var select := BUFF_SELECT.instantiate()
	add_child(select)
	select.setup(BuffPool.pick(BUFF_CHOICES))
	select.chosen.connect(_on_buff_chosen)


func _on_buff_chosen(buff: Buff) -> void:
	Events.buff_chosen.emit(buff)
	RunState.advance_zone()
	get_tree().change_scene_to_file.call_deferred(RunState.zone_scene())


func _on_player_died() -> void:
	_show_end("阵亡", "倒在第 %d 个战区，本局增益已清空" % (zone_index + 1))


func _show_end(title: String, subtitle: String) -> void:
	if _ended:
		return
	_ended = true
	var screen := RUN_END.instantiate()
	add_child(screen)
	screen.setup(title, subtitle)
	screen.restart_pressed.connect(_restart)


func _restart() -> void:
	RunState.start_new_run()
	get_tree().change_scene_to_file.call_deferred(RunState.zone_scene())


func _set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


func _mark_capture_point() -> void:
	_beacon = Label3D.new()
	_beacon.name = "ObjectiveBeacon"
	_beacon.text = "%s\n清敌后开放" % ZONE_TITLES[zone_index]
	_beacon.position.y = 4.0
	_beacon.font_size = 48
	_beacon.pixel_size = 0.012
	_beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_beacon.modulate = Color(1.0, 0.82, 0.45)
	capture_point.add_child(_beacon)


func _spawn_breakables() -> void:
	var props := Node3D.new()
	props.name = "BreakableProps"
	props.add_to_group("navigation_geometry")
	get_parent().add_child.call_deferred(props)
	# All props sit on optional flanks; the original AI approach remains open.
	var crate_at := Vector3(-17, 0.05, 12) if zone_index == 0 else Vector3(-20, 0.05, 15)
	var wall_at := Vector3(16, 0.05, -5) if zone_index == 0 else Vector3(19, 0.05, -3)
	for item in [[&"crate", crate_at], [&"wall", wall_at]]:
		var prop := BREAKABLE.new()
		prop.prop_kind = item[0]
		prop.fragment_container = get_parent() as Node3D
		prop.name = "SupplyCrate" if item[0] == &"crate" else "BreachableWall"
		prop.position = item[1]
		prop.broken.connect(_on_prop_broken)
		props.add_child(prop)
	_supply_root = Node3D.new()
	_supply_root.name = "SupplyPickups"
	get_parent().add_child.call_deferred(_supply_root)


func _on_prop_broken(kind: StringName, at: Vector3) -> void:
	Events.prop_destroyed.emit(kind, at)
	_rebake_navigation.call_deferred()
	if kind == &"crate":
		_spawn_supply.call_deferred(at)


func _spawn_supply(at: Vector3) -> void:
	if _ended or not is_instance_valid(_player) or _player.health.is_dead():
		return
	var pickup := Area3D.new()
	pickup.name = "AmmoAndGrenade"
	pickup.collision_layer = 0
	pickup.collision_mask = CollisionLayers.ACTORS
	pickup.set_meta("collected", false)
	_supply_root.add_child(pickup)
	pickup.global_position = at + Vector3.UP * 0.5
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	shape.shape = sphere
	pickup.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.4, 0.45)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.48, 0.28)
	material.emission_enabled = true
	material.emission = Color(0.1, 0.4, 0.22)
	box.material = material
	mesh.mesh = box
	pickup.add_child(mesh)
	var label := Label3D.new()
	label.text = "+30 弹药 / +1 手雷\n靠近拾取"
	label.position.y = 0.6
	label.font_size = 40
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pickup.add_child(label)
	pickup.body_entered.connect(_on_supply_entered.bind(pickup))
	supply_changed.emit("补给箱已打开，靠近绿色补给包拾取")


func _on_supply_entered(body: Node3D, pickup: Area3D) -> void:
	if body != _player or _ended or _player.health.is_dead() or pickup.get_meta("collected"):
		return
	var ammo_added := _player.weapon.add_reserve(SUPPLY_AMMO, RESERVE_LIMIT)
	var grenades_added := _player.add_grenades(1)
	if ammo_added == 0 and grenades_added == 0:
		supply_changed.emit("弹药和手雷已满，补给包为你保留")
		return
	pickup.set_meta("collected", true)
	_player.weapon.ammo_changed.emit(_player.weapon.ammo, _player.weapon.reserve)
	supply_changed.emit("补给：后备弹 +%d / 手雷 +%d" % [ammo_added, grenades_added])
	pickup.queue_free()


func _process(delta: float) -> void:
	# A full pickup stays usable when ammo is spent while standing inside it.
	_supply_poll -= delta
	if _supply_poll > 0.0:
		return
	_supply_poll = 0.25
	if _ended or not is_instance_valid(_player) or _player.health.is_dead():
		return
	if _player.weapon.reserve >= RESERVE_LIMIT and _player.grenades_remaining >= 3:
		return
	for pickup in _supply_root.get_children():
		if pickup is Area3D and not pickup.is_queued_for_deletion() and _player in pickup.get_overlapping_bodies():
			_on_supply_entered(_player, pickup)


func _rebake_navigation() -> void:
	_navigation_dirty = true
	if _navigation_rebaking:
		return
	_navigation_rebaking = true
	while _navigation_dirty and is_instance_valid(navigation_region):
		# Let queued prop removal/addition finish, so navigation sees the same
		# intact obstacles as physics. Repeated same-frame breaks coalesce.
		await get_tree().process_frame
		_navigation_dirty = false
		navigation_region.bake_navigation_mesh(false)
		await get_tree().physics_frame
	for enemy in _alive:
		if is_instance_valid(enemy) and not enemy.health.is_dead():
			enemy.set_physics_process(true)
	_navigation_rebaking = false
