extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var packed: PackedScene = load("res://main.tscn")
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	var start: Vector3 = scene.player.position
	var press := InputEventKey.new()
	press.physical_keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	for i in range(35):
		await physics_frame
	press.pressed = false
	Input.parse_input_event(press)
	assert(scene.player.position.z < start.z - 0.5, "Персонаж должен двигаться")
	assert(scene.player.position.y >= -0.05, "Персонаж не должен проваливаться")
	var light := InputEventKey.new()
	light.keycode = KEY_L
	light.pressed = true
	scene._unhandled_key_input(light)
	assert(scene.evening)
	scene.reload_assets(true)
	assert(scene.imported.has("tree"))
	if DisplayServer.get_name() != "headless":
		for i in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		var output := OS.get_cmdline_user_args()
		if not output.is_empty():
			root.get_texture().get_image().save_png(output[0])
	print("PASS: playable 2.5D scene, floor collision, lighting, imported tree and reload")
	quit(0)
