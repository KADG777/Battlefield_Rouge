extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://maps/zone_1.tscn")
	for index in range(20):
		await physics_frame
		await process_frame
	var player: Node3D = get_first_node_in_group("player")
	player.set_physics_process(false)
	player.set_process(false)
	player.get("weapon").set_process(false)
	for enemy in get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
		enemy.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://verification"))
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://verification/integration-initial.png")
	var camera: Camera3D = player.get("_camera")
	player.get("weapon").visible = false
	camera.global_position = Vector3(23, 17, 28)
	camera.look_at(Vector3(0, 2, -8))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://verification/integration-city.png")
	print("INITIAL_SCREENSHOTS_SAVED")
	_stop_audio(root)
	for index in range(3):
		await process_frame
	quit()

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)
