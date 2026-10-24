extends SceneTree
## Controlled acceptance tests of the actual two-zone game, using Forward+ and Jolt.
## AI is held during measurements; real Health, weapon rays, capture areas and UI
## signals drive the original run state and scene transitions.

var _checks: Array[Dictionary] = []
var _measurements: Dictionary = {}
var _screenshots: Array[String] = []
var _chosen: Array[Buff] = []
var _broken_events: Array = []
var _finished = false
var _zone_clears: Array[int] = []
var _wins = 0
var _events_node: Node
var _run_state: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_events_node = root.get_node("Events")
	_run_state = root.get_node("RunState")
	create_timer(180.0).timeout.connect(_watchdog)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verification"))
	_events_node.buff_chosen.connect(func(buff: Buff): _chosen.append(buff))
	_events_node.prop_destroyed.connect(func(kind: StringName, at: Vector3): _broken_events.append([str(kind), str(at)]))
	_events_node.zone_cleared.connect(func(index: int): _zone_clears.append(index))
	_events_node.run_won.connect(func(): _wins += 1)
	_run_state.start_new_run()
	var scene = await _load_zone(_run_state.zone_scene())
	var player: Node3D = get_first_node_in_group("player")
	var director: Node = get_first_node_in_group("zone_director")
	_check(RenderingServer.get_current_rendering_method() == "forward_plus",
		"original_forward_plus_renderer_preserved")
	_check(ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics",
		"original_jolt_physics_preserved")
	_check(scene.scene_file_path == "res://maps/zone_1.tscn" and _run_state.zone_index == 0,
		"actual_original_zone_one_is_loaded")
	_verify_scene_assets(scene, player)
	_check(director.enemies_total == 4 and director.capture_point.locked,
		"zone_one_starts_with_four_enemies_and_locked_capture")
	_check(is_equal_approx(director.capture_point.capture_time, 6.0),
		"original_six_second_capture_duration_preserved")
	_check(player.grenades_remaining == 3, "zone_starts_with_three_grenades")
	_check(player.weapon.data.damage == 42.0, "original_rifle_damage_42_preserved")
	await _capture("integration-zone1.png")
	await _capture_ads(player)
	_verify_magazine_stats(player)
	await _verify_breakables(scene, player, director)
	await _verify_grenades(scene, player)
	await _verify_combat(scene, player)
	await _verify_effects(player)
	await _settle_navigation(director)
	_clear_enemies(player)
	await _frames(3)
	_check(not director.capture_point.locked and director.get("_alive").is_empty(),
		"actual_enemy_deaths_unlock_capture_and_update_director")
	await _capture_point(player, director.capture_point)
	var selector = _selector(director)
	_check(paused and selector != null, "zone_one_capture_opens_real_paused_buff_ui")
	if selector == null:
		await _finish()
		return
	var choices: HBoxContainer = selector.get_node("Center/Box/Choices")
	_check(choices.get_child_count() == 3, "buff_ui_offers_three_real_choices")
	await _capture("integration-buff.png")
	var previous_id = scene.get_instance_id()
	_stop_audio(scene)
	choices.get_child(0).pressed.emit()
	scene = await _wait_new_scene(previous_id)
	player = get_first_node_in_group("player")
	director = get_first_node_in_group("zone_director")
	_check(_run_state.zone_index == 1 and scene.scene_file_path == "res://maps/zone_2.tscn",
		"chosen_buff_advances_into_actual_zone_two")
	_check(_run_state.buffs.size() == 1 and not _chosen.is_empty(), "chosen_buff_is_saved_for_this_run")
	if not _chosen.is_empty():
		var buff: Buff = _chosen.back()
		var expected = (float(player.stats.base.get(buff.stat, 0.0)) + buff.add) * buff.mul
		_check(is_equal_approx(player.stats.get_value(buff.stat), expected),
			"zone_two_applies_chosen_buff_through_stats",
			{"stat": str(buff.stat), "expected": expected, "actual": player.stats.get_value(buff.stat)})
	_check(director.enemies_total == 6 and director.capture_point.locked,
		"zone_two_starts_with_six_enemies_and_locked_capture")
	_check(player.grenades_remaining == 3, "grenade_inventory_resets_for_new_zone")
	await _capture("integration-zone2.png")

	# Die while the first run still owns a buff, then use the real restart button.
	director.call("_spawn_supply", Vector3(20, 0.5, 20))
	var death_pickup = scene.get_node("SupplyPickups").get_child(0)
	var reserve_before_death = player.weapon.reserve
	var grenades_before_death = player.grenades_remaining
	var attacker: Node = get_nodes_in_group("enemy")[0]
	player.health.apply_damage(10000.0, Hitbox.BodyPart.BODY, attacker)
	await _frames(2)
	director.call("_on_supply_entered", player, death_pickup)
	_check(player.weapon.reserve == reserve_before_death and player.grenades_remaining == grenades_before_death,
		"dead_player_cannot_collect_supply")
	_check(player.health.is_dead() and _run_state.buffs.is_empty() and _run_state.zone_index == 0,
		"player_death_clears_buffs_and_resets_zone_index")
	var death = _end_screen(director)
	_check(paused and death != null and death.get_node("Center/Box/Title").text == "阵亡",
		"actual_death_ui_pauses_game")
	if death == null:
		await _finish()
		return
	previous_id = scene.get_instance_id()
	_stop_audio(scene)
	death.get_node("Center/Box/Restart").pressed.emit()
	scene = await _wait_new_scene(previous_id)
	player = get_first_node_in_group("player")
	director = get_first_node_in_group("zone_director")
	_check(not paused and _run_state.zone_index == 0 and _run_state.buffs.is_empty(),
		"real_restart_button_returns_to_clean_zone_one")
	_check(player.health.health == player.health.max_health and player.grenades_remaining == 3,
		"restart_restores_full_player_health_and_three_grenades")

	# Complete a fresh two-zone run, without replacing the original controller.
	_clear_enemies(player)
	await _frames(2)
	await _capture_point(player, director.capture_point)
	selector = _selector(director)
	if selector == null:
		_check(false, "fresh_run_buff_selector_exists")
		await _finish()
		return
	previous_id = scene.get_instance_id()
	_stop_audio(scene)
	selector.get_node("Center/Box/Choices").get_child(0).pressed.emit()
	scene = await _wait_new_scene(previous_id)
	player = get_first_node_in_group("player")
	director = get_first_node_in_group("zone_director")
	_clear_enemies(player)
	await _frames(2)
	await _capture_point(player, director.capture_point)
	var victory = _end_screen(director)
	_check(victory != null and victory.get_node("Center/Box/Title").text == "胜利" and _wins == 1,
		"fresh_run_clears_both_original_zones_and_reaches_real_victory")
	_check(_zone_clears.has(0) and _zone_clears.has(1),
		"original_zone_cleared_events_emitted_for_both_zones")
	await _finish()


func _verify_scene_assets(scene: Node3D, player: Node3D) -> void:
	var sources = {}
	for node in scene.find_children("*", "Node3D", true, false):
		var path = (node as Node3D).scene_file_path
		if path.begins_with("res://assets/"):
			sources[path] = true
	var city_count = 0
	var ruin_count = 0
	for path: String in sources:
		if "/city/" in path:
			city_count += 1
		if "/ruins/" in path:
			ruin_count += 1
	_measurements["loaded_model_sources"] = sources.keys()
	_check(city_count > 0 and ruin_count > 0, "actual_original_map_contains_imported_city_and_ruins",
		{"city_sources": city_count, "ruin_sources": ruin_count})
	var faces = 0
	for node in player.weapon.find_children("*", "MeshInstance3D", true, false):
		var mesh_node = node as MeshInstance3D
		if mesh_node.mesh:
			faces += mesh_node.mesh.get_faces().size() / 3
	_measurements["first_person_weapon_triangles"] = faces
	_check(faces >= 16578, "actual_original_player_uses_real_stein_ak47_mesh", {"triangles": faces})
	var effect: Node = player.get("_grenade_effects")
	var plugin_available = ResourceLoader.exists("res://addons/pyrolux_fx/core/pyrolux.gd") and ResourceLoader.exists("res://addons/pyrolux_fx/presets/3d/explosion_grenade.tscn")
	_measurements["vfx_backend"] = "pyrolux" if effect != null and effect.call("uses_pyrolux") else "project_fallback"
	_check(effect != null and effect.has_method("explosion") and effect.call("uses_pyrolux") == plugin_available,
		"optional_vfx_backend_matches_actual_local_plugin_availability",
		{"backend": _measurements["vfx_backend"], "plugin_available": plugin_available})
	_check(scene.has_node("BreakableProps/SupplyCrate") and scene.has_node("BreakableProps/BreachableWall"),
		"zone_director_injects_real_crate_and_optional_wall")


func _verify_breakables(scene: Node3D, player: Node3D, director: Node) -> void:
	var crate: BreakableProp = scene.get_node("BreakableProps/SupplyCrate")
	var wall: BreakableProp = scene.get_node("BreakableProps/BreachableWall")
	_check(crate.max_health == 40 and wall.max_health == 100, "crate_and_wall_keep_40_and_100_health")
	var wall_at = wall.global_position
	var navigation_map = director.navigation_region.get_navigation_map()
	var before_path = _path_length(navigation_map, wall_at + Vector3(0, 0, 2.5), wall_at - Vector3(0, 0, 2.5))
	_measurements["wall_navigation_before_metres"] = before_path
	_check(before_path > 5.1, "initial_ai_navigation_routes_around_intact_optional_wall",
		{"path_length": before_path})
	var pad = _obstacle(scene, Vector3(0, -0.1, 45), Vector3(42, 0.2, 30))
	pad.name = "VerificationFloor"
	crate.global_position = Vector3(0, 0.05, 40)
	_aim(player, Vector3(0, 1.65, 44), crate.global_position + Vector3.UP * 0.65)
	await _frames(2)
	var events_before = _broken_events.size()
	var ammo_before = player.weapon.ammo
	_check(player.weapon.try_fire(), "actual_player_rifle_fires_at_crate")
	_check(crate.health == 0.0 and crate.is_broken(), "single_real_shot_alone_destroys_40_health_crate")
	crate.take_damage(999.0)
	crate.blast(Vector3.ZERO, 5.0)
	_check(not player.weapon.try_fire(), "original_weapon_fire_rate_blocks_duplicate_input")
	_check(player.weapon.ammo == ammo_before - 1, "real_shot_consumes_one_round")
	_check(_broken_events.size() == events_before + 1, "crate_reports_one_global_prop_event_despite_repeated_damage")
	_check(_shards().size() == 8, "real_rifle_shot_replaces_crate_with_eight_jummit_rigid_fragments")
	var valid_layers = true
	var real_shapes = true
	var outside_navigation = true
	for shard in _shards():
		valid_layers = valid_layers and shard.collision_layer == CollisionLayers.DEBRIS and shard.collision_mask == CollisionLayers.WORLD
		real_shapes = real_shapes and shard is RigidBody3D and shard.get_child(1).shape is ConvexPolygonShape3D
		outside_navigation = outside_navigation and not _under_navigation_group(shard)
	_check(valid_layers and CollisionLayers.DEBRIS == 16, "fragments_use_debris_16_and_world_only_collision")
	_check(real_shapes, "jummit_fragments_have_actual_convex_rigid_body_shapes")
	_check(outside_navigation, "cosmetic_fragments_are_outside_navigation_geometry_group")
	await _frames(3)
	_check(not is_instance_valid(crate), "intact_crate_collision_is_actually_removed")
	var supply_root: Node3D = scene.get_node("SupplyPickups")
	_check(supply_root.get_child_count() == 1, "one_destroyed_crate_creates_one_real_supply_pickup")
	player.weapon.reserve = 100
	player.grenades_remaining = 2
	player.global_position = Vector3(0, 0.05, 40)
	await _frames(4)
	_check(player.weapon.reserve == 130 and player.grenades_remaining == 3 and supply_root.get_child_count() == 0,
		"real_proximity_pickup_grants_30_reserve_and_one_grenade_once")
	player.weapon.reserve = 180
	director.call("_spawn_supply", Vector3(5, 0.05, 40))
	await _frames(2)
	player.global_position = Vector3(5, 0.05, 40)
	await _frames(4)
	_check(supply_root.get_child_count() == 1, "full_inventory_preserves_supply_for_later")
	player.weapon.reserve = 179
	await create_timer(0.4).timeout
	_check(player.weapon.reserve == 180 and supply_root.get_child_count() == 0,
		"remaining_inside_supply_collects_after_spending_ammo")
	await _settle_navigation(director)

	player.global_position = wall_at + Vector3(0, 0.1, 2.5)
	_check(player.test_move(player.global_transform, Vector3(0, 0, -5)),
		"real_player_capsule_is_blocked_by_intact_wall")
	var expected_shots = ceili(wall.max_health / player.weapon.data.damage)
	var before_count = _shards().size()
	var health_after: Array[float] = []
	for shot in range(expected_shots):
		_aim(player, wall_at + Vector3(0, 1.7, 2.5), wall_at + Vector3.UP * 1.2)
		player.weapon.set("_cooldown", 0.0)
		player.weapon.set("_spread", 0.0)
		player.weapon.try_fire()
		health_after.append(wall.health)
	_check(wall.health == 0.0 and expected_shots == 3,
		"three_real_42_damage_shots_destroy_wall", {"health_after_shots": health_after})
	_check(_shards().size() - before_count == 12, "wall_creates_twelve_jummit_rigid_fragments")
	await _settle_navigation(director)
	var after_path = _path_length(navigation_map, wall_at + Vector3(0, 0, 2.5), wall_at - Vector3(0, 0, 2.5))
	_measurements["wall_navigation_after_metres"] = after_path
	_check(after_path > 0 and after_path < before_path - 0.1,
		"wall_destruction_rebakes_ai_navigation_to_shorter_open_route",
		{"before": before_path, "after": after_path})
	_check(not player.test_move(player.global_transform, Vector3(0, 0, -5)),
		"player_can_physically_traverse_new_breach_without_debris_blocking")
	var highest: RigidBody3D = null
	for fragment in _shards():
		if highest == null or fragment.global_position.y > highest.global_position.y:
			highest = fragment
	if highest != null:
		var start = highest.global_position
		await _frames(8)
		_check(highest.global_position.distance_to(start) > 0.005, "jolt_physically_moves_generated_debris")
	await create_timer(3.2).timeout
	_check(_shards().is_empty(), "real_game_reclaims_debris_after_three_seconds")


func _verify_grenades(scene: Node3D, player: Node3D) -> void:
	player.global_position = Vector3(0, 0.05, 20)
	_aim(player, Vector3(0, 1.65, 20), Vector3(0, 1.65, 10))
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.grenades_remaining = 3
	player.set("_grenade_cooldown", 0.0)
	var has_g = false
	for event in InputMap.action_get_events("grenade"):
		has_g = has_g or (event is InputEventKey and event.physical_keycode == KEY_G)
	_check(has_g, "original_input_map_connects_G_to_grenade")
	_check(player.throw_grenade() and player.grenades_remaining == 2, "real_player_throw_consumes_one_grenade")
	var grenade: RigidBody3D = _latest_grenade(scene)
	_check(grenade != null and grenade.collision_layer == CollisionLayers.PROJECTILES and
		grenade.collision_mask == CollisionLayers.WORLD, "real_grenade_is_world_colliding_projectile_32")
	_check(not player.throw_grenade() and player.grenades_remaining == 2,
		"grenade_half_second_cooldown_prevents_spam")
	if grenade != null:
		var initial = grenade.global_position
		await create_timer(1.15).timeout
		_check(is_instance_valid(grenade) and is_equal_approx(grenade.fuse_time, 1.4),
			"actual_grenade_remains_live_before_1_point_4_second_fuse")
		if is_instance_valid(grenade):
			_check(grenade.global_position.distance_to(initial) > 2.0,
				"actual_grenade_travels_under_jolt_rigid_body_physics")
			var target = BreakableProp.new()
			target.fragment_container = scene
			scene.add_child(target)
			target.global_position = grenade.global_position + Vector3(1.5, 0, 0)
			target.position.y = 0.05
			var camera: Camera3D = player.get("_camera")
			player.set_physics_process(false)
			camera.global_position = grenade.global_position + Vector3(0, 2.2, 7.0)
			camera.look_at(grenade.global_position)
			await _frames(2)
			for index in range(60):
				if not is_instance_valid(grenade):
					break
				await process_frame
			_check(not is_instance_valid(grenade), "grenade_fuse_detonates_and_frees_actual_projectile")
			_check(not is_instance_valid(target), "actual_timed_grenade_breaks_nearby_real_crate")
			await create_timer(0.10).timeout
			await _capture("integration-explosion.png")
			if is_instance_valid(target):
				target.queue_free()
	player.set_physics_process(true)
	for remaining in [1, 0]:
		await create_timer(0.55).timeout
		_check(player.throw_grenade() and player.grenades_remaining == remaining,
			"grenade_inventory_consumption_to_" + str(remaining))
	await create_timer(0.55).timeout
	_check(not player.throw_grenade() and player.grenades_remaining == 0,
		"fourth_grenade_is_rejected_when_three_are_used")
	_check(player.add_grenades(99) == 3 and player.grenades_remaining == 3 and player.add_grenades(1) == 0,
		"grenade_replenishment_is_capped_at_three")
	player.set_physics_process(false)
	await create_timer(1.5).timeout

	# Blast visibility is sampled before any wall is destroyed.
	var victim = BreakableProp.new()
	victim.fragment_container = scene
	scene.add_child(victim)
	victim.global_position = Vector3(14, 0.05, 46)
	var distant = BreakableProp.new()
	distant.fragment_container = scene
	scene.add_child(distant)
	distant.global_position = Vector3(18, 0.05, 46)
	var blocker = _obstacle(scene, Vector3(12, 1.5, 46), Vector3(0.3, 3, 3))
	await _frames(3)
	var blast = _blast(scene, player, Vector3(10, 0.7, 46))
	blast.detonate()
	await _frames(2)
	_check(victim.health == 40.0, "solid_world_wall_occludes_real_grenade_blast")
	_check(distant.health == 40.0, "real_grenade_does_not_damage_beyond_five_metres")
	blocker.queue_free()
	await _frames(2)
	var repeated = _blast(scene, player, Vector3(10, 0.7, 46))
	var detonation_events: Array[int] = []
	repeated.detonated.connect(func(_at: Vector3): detonation_events.append(1))
	repeated.detonate()
	repeated.detonate()
	await _frames(2)
	_check(not is_instance_valid(victim), "removing_occluder_allows_real_grenade_damage")
	_check(detonation_events.size() == 1, "detonate_is_guarded_against_duplicate_same_frame_calls")
	distant.queue_free()
	await _frames(2)


func _verify_combat(scene: Node3D, player: Node3D) -> void:
	var enemies = get_nodes_in_group("enemy")
	if enemies.size() < 2:
		_check(false, "two_real_enemies_available_for_damage_tests")
		return
	var enemy: CharacterBody3D = enemies[0]
	var friend: CharacterBody3D = enemies[1]
	enemy.global_position = Vector3(0, 0.05, 44)
	await _frames(3)
	var torso: Hitbox = null
	for hitbox in enemy.find_children("*", "Hitbox", true, false):
		if hitbox.body_part == Hitbox.BodyPart.BODY:
			torso = hitbox
	if torso == null:
		_check(false, "enemy_has_real_body_hitbox")
		return
	var before = enemy.health.health
	var sample = torso.global_position
	for shape in torso.get_children():
		if shape is CollisionShape3D:
			sample = shape.global_position
	_aim(player, sample + Vector3(0, 0, 4.0), sample)
	await _frames(2)
	var camera: Camera3D = player.get("_camera")
	var query = PhysicsRayQueryParameters3D.create(camera.global_position, sample,
		CollisionLayers.WORLD | CollisionLayers.HITBOXES, [player.get_rid()])
	var measured_hit = scene.get_world_3d().direct_space_state.intersect_ray(query)
	_check(not measured_hit.is_empty() and measured_hit.get("collider") == torso,
		"controlled_combat_ray_reaches_actual_enemy_torso_collider")
	player.weapon.set("_cooldown", 0.0)
	player.weapon.set("_spread", 0.0)
	player.weapon.try_fire()
	_check(is_equal_approx(before - enemy.health.health, 42.0),
		"real_weapon_ray_damages_enemy_body_through_original_hitbox",
		{"health_before": before, "health_after": enemy.health.health})
	var friendly_before = enemy.health.health
	var dealt = torso.apply_hit(10.0, friend)
	_check(dealt == 0.0 and enemy.health.health == friendly_before,
		"original_enemy_friendly_fire_filter_is_preserved")
	var own_health = player.health.health
	player.health.apply_damage(10.0, Hitbox.BodyPart.BODY, player)
	_check(player.health.health == own_health, "player_same_team_self_damage_is_filtered")
	# One Health with multiple hitboxes must receive only one grenade BODY hit.
	enemy.health.health = 100.0
	var damage_calls: Array[int] = []
	enemy.health.damaged.connect(func(_amount: float, _part: Hitbox.BodyPart, _source: Node): damage_calls.append(1))
	var origin = torso.global_position + Vector3(2.0, 0.0, 0.0)
	var blast = _blast(scene, player, origin)
	await _frames(2)
	blast.detonate()
	await _frames(2)
	_check(damage_calls.size() == 1, "grenade_deduplicates_multiple_enemy_hitboxes_to_one_health_hit")


func _verify_magazine_stats(player: Node3D) -> void:
	var saved_ammo = player.weapon.ammo
	var saved_reserve = player.weapon.reserve
	var base_capacity = player.weapon.magazine_capacity()
	var buff = load("res://buffs/extended_mag.tres")
	player.weapon.ammo = base_capacity
	player.stats.apply_buff(buff)
	var enlarged = player.weapon.magazine_capacity()
	_check(enlarged == ceili(base_capacity * 1.5) and player.weapon.ammo == enlarged,
		"extended_mag_buff_grows_a_full_magazine_and_its_ammo_together")
	var reserve_before_shrink = player.weapon.reserve
	player.stats.clear_buffs()
	_check(player.weapon.magazine_capacity() == base_capacity and player.weapon.ammo == base_capacity and
		player.weapon.reserve == reserve_before_shrink + enlarged - base_capacity,
		"clearing_magazine_buff_restores_capacity_and_returns_overflow_to_reserve")
	player.weapon.ammo = base_capacity - 5
	player.stats.apply_buff(buff)
	_check(player.weapon.magazine_capacity() == enlarged and player.weapon.ammo == base_capacity - 5,
		"extended_mag_buff_does_not_refill_a_partly_fired_magazine")
	player.stats.clear_buffs()
	_check(player.weapon.magazine_capacity() == base_capacity and player.weapon.ammo == base_capacity - 5,
		"clearing_magazine_buff_keeps_nonoverflow_partial_ammo")
	player.weapon.ammo = saved_ammo
	player.weapon.reserve = saved_reserve
	player.weapon.ammo_changed.emit(saved_ammo, saved_reserve)


func _verify_effects(player: Node3D) -> void:
	var effect_node: Node3D = player.get("_grenade_effects")
	var uses_pyrolux = bool(effect_node.call("uses_pyrolux"))
	await create_timer(0.18).timeout
	effect_node.call("explosion", Vector3(0, 0.2, 12))
	await _frames(2)
	var effects = _effects(effect_node)
	_check(not effects.is_empty(), "real_game_optional_vfx_spawns_actual_effect_geometry")
	var before = _effects(effect_node).size()
	effect_node.call("explosion", Vector3(0, 0.2, 12))
	await _frames(1)
	_check(_effects(effect_node).size() == before, "real_game_vfx_cooldown_blocks_immediate_duplicate")
	if not effects.is_empty() and uses_pyrolux:
		var effect: Node = effects.back()
		var quads = {
			"fire": _effect_quads(effect, effect.get("_fire_mat")),
			"smoke": _effect_quads(effect, effect.get("_smoke_mat")),
			"sparks": _effect_quads(effect, effect.get("_spark_mat")),
			"debris": _effect_quads(effect, effect.get("_debris_mat")),
		}
		_check(quads == {"fire": 7, "smoke": 6, "sparks": 10, "debris": 3},
			"real_game_pyrolux_respects_actual_low_quality_geometry_budget", quads)
	elif not effects.is_empty():
		var fallback: Node3D = effects.back()
		var parts = _fallback_parts(fallback)
		var valid_geometry = parts.size() == 2
		var triangles = 0
		for part: MeshInstance3D in parts:
			var material = part.material_override as StandardMaterial3D
			valid_geometry = valid_geometry and part.mesh is SphereMesh and material != null
			if material != null:
				valid_geometry = valid_geometry and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
			if part.mesh != null:
				triangles += part.mesh.get_faces().size() / 3
		_measurements["fallback_effect_geometry"] = {"sphere_layers": parts.size(), "triangles": triangles}
		_check(valid_geometry and triangles > 0, "project_fallback_builds_real_transparent_fire_and_smoke_geometry",
			_measurements["fallback_effect_geometry"])
		if valid_geometry and parts.size() == 2:
			var fire: MeshInstance3D = parts[0]
			var smoke: MeshInstance3D = parts[1]
			var fire_material = fire.material_override as StandardMaterial3D
			var fire_scale = fire.scale.length()
			var smoke_height = smoke.position.y
			var fire_alpha = fire_material.albedo_color.a
			await create_timer(0.15).timeout
			_check(is_instance_valid(fallback) and fire.scale.length() > fire_scale and smoke.position.y > smoke_height and fire_material.albedo_color.a < fire_alpha,
				"project_fallback_geometry_expands_rises_and_fades_over_time")
	var peak = before
	var new_effects = 0
	for index in range(6):
		await create_timer(0.18).timeout
		var previous_ids: Array[int] = []
		for effect in _effects(effect_node):
			previous_ids.append(effect.get_instance_id())
		effect_node.call("explosion", Vector3(index * 0.5, 0.2, 12))
		await _frames(1)
		for effect in _effects(effect_node):
			if not effect.get_instance_id() in previous_ids:
				new_effects += 1
		peak = maxi(peak, _effects(effect_node).size())
	_check(peak <= 4 and new_effects == 6, "real_game_vfx_limits_four_and_survives_repeated_eviction",
		{"peak": peak, "new_effects": new_effects})
	var cleanup_wait = 6.3 if uses_pyrolux else 1.65
	_measurements["vfx_cleanup_observation_seconds"] = cleanup_wait
	await create_timer(cleanup_wait).timeout
	_check(_effects(effect_node).is_empty(), "real_game_optional_effects_naturally_cleanup")
	effect_node.call("explosion", Vector3(0, 0.2, 12))
	await _frames(2)
	_check(_effects(effect_node).size() == 1, "real_game_vfx_respawns_after_all_old_references_expire")
	for effect in _effects(effect_node):
		effect.queue_free()


func _effects(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		if child.has_method("get_duration") or _fallback_parts(child).size() == 2:
			result.append(child)
	return result


func _fallback_parts(effect: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if not effect is Node3D or effect is AudioStreamPlayer3D:
		return result
	for child in effect.get_children():
		if child is MeshInstance3D and child.mesh is SphereMesh:
			result.append(child)
	return result


func _effect_quads(effect: Node, material: Material) -> int:
	for child in effect.get_children(true):
		if child is MeshInstance3D and child.material_override == material and child.mesh:
			return child.mesh.get_faces().size() / 6
	return 0


func _blast(scene: Node3D, player: Node3D, at: Vector3) -> RigidBody3D:
	var grenade = load("res://weapons/grenade.gd").new()
	scene.add_child(grenade)
	grenade.global_position = at
	grenade.freeze = true
	grenade.launch(player, Vector3.ZERO, player.get("_grenade_effects"))
	return grenade


func _clear_enemies(player: Node3D) -> void:
	for enemy in get_nodes_in_group("enemy"):
		if not enemy.health.is_dead():
			enemy.health.apply_damage(10000.0, Hitbox.BodyPart.BODY, player)


func _capture_point(player: Node3D, point: CapturePoint) -> void:
	player.set_physics_process(false)
	player.set_process(false)
	player.weapon.set_process(false)
	player.global_position = point.global_position + Vector3(0, 0.1, 0)
	var camera: Camera3D = player.get("_camera")
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	player.get("_head").rotation = Vector3.ZERO
	player.rotation = Vector3.ZERO
	await _frames(3)
	_check(point.get("_player_inside"), "real_capture_area_detects_player_overlap")
	await create_timer(point.capture_time + 0.2).timeout
	_check(point.is_captured(), "real_capture_process_reaches_full_progress_after_six_seconds")


func _load_zone(path: String) -> Node3D:
	_stop_audio(root)
	change_scene_to_file(path)
	return await _wait_new_scene(0)


func _wait_new_scene(previous_id: int) -> Node3D:
	for frame in range(600):
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != previous_id:
			await _frames(5)
			var scene = current_scene as Node3D
			var director: Node = get_first_node_in_group("zone_director")
			await _settle_navigation(director)
			for enemy in get_nodes_in_group("enemy"):
				enemy.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
				for collider in enemy.find_children("*", "CollisionObject3D", true, false):
					collider.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
				enemy.process_mode = Node.PROCESS_MODE_DISABLED
			var player: Node3D = get_first_node_in_group("player")
			player.set_process(false)
			player.set_physics_process(false)
			player.weapon.set_process(false)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			return scene
	_check(false, "scene_transition_completed_before_timeout")
	return current_scene as Node3D


func _settle_navigation(director: Node) -> void:
	await process_frame
	for frame in range(60):
		await physics_frame
		if not director.get("_navigation_rebaking"):
			break
	await _frames(2)


func _path_length(map: RID, from: Vector3, to: Vector3) -> float:
	var a = NavigationServer3D.map_get_closest_point(map, from)
	var b = NavigationServer3D.map_get_closest_point(map, to)
	var path = NavigationServer3D.map_get_path(map, a, b, true)
	var length = 0.0
	for index in range(1, path.size()):
		length += path[index - 1].distance_to(path[index])
	return length


func _under_navigation_group(node: Node) -> bool:
	var current = node.get_parent()
	while current != null:
		if current.is_in_group("navigation_geometry"):
			return true
		current = current.get_parent()
	return false


func _obstacle(scene: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var body = StaticBody3D.new()
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	scene.add_child(body)
	body.global_position = at
	return body


func _latest_grenade(scene: Node3D) -> RigidBody3D:
	var latest: RigidBody3D = null
	for child in scene.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://weapons/grenade.gd":
			latest = child
	return latest


func _aim(player: Node3D, origin: Vector3, target: Vector3) -> void:
	player.rotation = Vector3.ZERO
	player.global_position = origin - Vector3.UP * 1.6
	player.get("_head").rotation = Vector3.ZERO
	var camera: Camera3D = player.get("_camera")
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.look_at(target)
	player.weapon.aiming = true
	player.weapon.moving = false
	player.weapon.airborne = false


func _selector(director: Node) -> Node:
	for child in director.get_children():
		if child.has_node("Center/Box/Choices"):
			return child
	return null


func _end_screen(director: Node) -> Node:
	for child in director.get_children():
		if child.has_node("Center/Box/Restart"):
			return child
	return null


func _capture_ads(player: Node3D) -> void:
	player.set_process(true)
	player.set_physics_process(true)
	player.weapon.set_process(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("aim")
	await create_timer(0.30).timeout
	await _capture("integration-ads.png")
	Input.action_release("aim")
	await create_timer(0.25).timeout
	player.set_process(false)
	player.set_physics_process(false)
	player.weapon.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var path = "res://verification/" + filename
	var result = image.save_png(path)
	_check(result == OK, "actual_original_game_screenshot_" + filename,
		{"width": image.get_width(), "height": image.get_height()})
	if result == OK:
		_screenshots.append(ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
	await process_frame


func _shards() -> Array[Node]:
	return get_nodes_in_group("destruction_shards")


func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)


func _check(passed: bool, label: String, details: Dictionary = {}) -> void:
	_checks.append({"name": label, "passed": passed, "details": details})
	if passed:
		print("PASS ", label, " ", JSON.stringify(details) if not details.is_empty() else "")
	else:
		push_error("FAIL " + label + " " + JSON.stringify(details))


func _watchdog() -> void:
	if not _finished:
		_check(false, "verification_completed_before_180_second_watchdog")
		await _finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	paused = false
	_stop_audio(root)
	await _frames(3)
	var failures: Array[String] = []
	for entry in _checks:
		if not entry.passed:
			failures.append(entry.name)
	var report = {
		"checked_date": "2026-10-24", "engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"physics_engine": ProjectSettings.get_setting("physics/3d/physics_engine"),
		"scope": "Public clean copy: actual Battlefield-Rouge maps, actors, weapons, controller and UI; optional VFX backend measured locally.",
		"project_root": ProjectSettings.globalize_path("res://"),
		"check_count": _checks.size(), "passed_count": _checks.size() - failures.size(),
		"failed_count": failures.size(), "passed": failures.is_empty(),
		"failures": failures, "checks": _checks, "measurements": _measurements,
		"screenshots": _screenshots
	}
	var output = FileAccess.open("res://verification/integration-results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("INTEGRATION_RESULT ", JSON.stringify({
		"checks": _checks.size(), "failures": failures, "screenshots": _screenshots}))
	quit(0 if failures.is_empty() else 1)
