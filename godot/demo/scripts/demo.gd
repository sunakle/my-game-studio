extends Node3D

const Art = preload("res://scripts/demo_art.gd")
var player: CharacterBody3D
var visual: AnimatedSprite3D
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var status: Label
var scenery: Node3D
var evening := false
var imported: Dictionary = {}
var binding_text := ""
var reload_timer := 0.0

func _ready() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("202b25")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bfceb3")
	environment.ambient_light_energy = 0.7
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("f3e5be")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	camera.position = Vector3(0, 12, 12)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0.8, 0.05, 2)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.16
	capsule.height = 0.9
	shape.shape = capsule
	shape.position.y = 0.45
	player.add_child(shape)
	add_child(player)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(16, 0.2, 12)
	floor_shape.shape = box
	floor_body.position.y = -0.1
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	_build_hud()
	reload_assets(true)

func placeholder(kind: String) -> AnimatedSprite3D:
	var sprite := AnimatedSprite3D.new()
	var frames := SpriteFrames.new()
	frames.add_animation("idle_down")
	frames.add_frame("idle_down", Art.texture(kind))
	sprite.sprite_frames = frames
	sprite.animation = "idle_down"
	sprite.pixel_size = 1.0 / 32.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.offset = Vector2(0, 40 if kind == "tree" else 22 if kind == "character" else 13)
	return sprite

func make_sprite(kind: String) -> AnimatedSprite3D:
	if imported.has(kind):
		var path := "res://generated/" + str(imported[kind]) + "/preview_3d.tscn"
		if ResourceLoader.exists(path):
			var scene = ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			if scene is PackedScene:
				var instance: AnimatedSprite3D = scene.instantiate()
				instance.shaded = true
				return instance
	return placeholder(kind)

func plane(kind: String, position_value: Vector3, plane_size: Vector2) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = plane_size
	var mat := StandardMaterial3D.new()
	var tex: Texture2D = Art.texture(kind)
	if imported.has(kind):
		var frames_path := "res://generated/" + str(imported[kind]) + "/frames.tres"
		if ResourceLoader.exists(frames_path):
			var library: SpriteFrames = ResourceLoader.load(frames_path, "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
			tex = library.get_frame_texture(library.get_animation_names()[0], 0)
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(plane_size.x, plane_size.y, 1)
	mat.roughness = 1
	mesh.material = mat
	node.mesh = mesh
	node.position = position_value
	return node

func reload_assets(force: bool = false) -> void:
	var text := FileAccess.get_file_as_string("res://generated/bindings.json") if FileAccess.file_exists("res://generated/bindings.json") else ""
	if not force and text == binding_text:
		return
	binding_text = text
	var bindings = JSON.parse_string(text) if not text.is_empty() else {}
	imported = bindings if bindings is Dictionary else {}
	if scenery != null:
		remove_child(scenery)
		scenery.queue_free()
	scenery = Node3D.new()
	scenery.name = "Scenery"
	add_child(scenery)
	scenery.add_child(plane("grass", Vector3.ZERO, Vector2(16, 12)))
	scenery.add_child(plane("path", Vector3(0.5, 0.012, 0), Vector2(1.6, 12)))
	scenery.add_child(plane("water", Vector3(5.2, 0.018, 0), Vector2(3.5, 8)))
	for pos in [Vector3(-3.0, 0.02, -2.5), Vector3(-2.5, 0.02, 1.8), Vector3(2.6, 0.02, -1.0), Vector3(-5.1, 0.02, -0.8)]:
		var tree := make_sprite("tree")
		tree.position = pos
		scenery.add_child(tree)
		add_obstacle(pos, Vector3(0.45, 1.0, 0.45))
	for pos in [Vector3(-1.5, 0.02, -0.2), Vector3(2.5, 0.02, 2.2), Vector3(3.0, 0.02, -3.5)]:
		var rock := make_sprite("rock")
		rock.position = pos
		scenery.add_child(rock)
		add_obstacle(pos, Vector3(0.7, 0.4, 0.55))
	# Simple 3D ruins let us verify occlusion against actual geometry.
	for pos in [Vector3(-5.4, 0.45, -3.7), Vector3(-4.3, 0.3, -3.7)]:
		var ruin := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.9, pos.y * 2, 0.4)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("828674")
		mat.roughness = 1
		mesh.material = mat
		ruin.mesh = mesh
		ruin.position = pos
		scenery.add_child(ruin)
		add_obstacle(Vector3(pos.x, 0, pos.z), mesh.size)
	if visual != null:
		player.remove_child(visual)
		visual.queue_free()
	visual = make_sprite("character")
	player.add_child(visual)
	visual.play()
	if status != null:
		status.text = "Пакетов в сцене: %d · 32 px = 1 единица · камера 45°" % imported.size()

func add_obstacle(pos: Vector3, size_value: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size_value
	shape.shape = box
	shape.position.y = size_value.y / 2
	body.add_child(shape)
	body.position = pos
	scenery.add_child(body)

func _physics_process(delta: float) -> void:
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	).normalized()
	player.velocity.x = direction.x * 2.8
	player.velocity.z = direction.y * 2.8
	player.velocity.y -= 9.8 * delta
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -7.5, 7.5)
	player.position.z = clampf(player.position.z, -5.5, 5.5)
	if direction.length() > 0:
		var facing := "left" if direction.x < 0 else "right" if direction.x > 0 else "up" if direction.y < 0 else "down"
		for clip in ["walk_" + facing, "idle_" + facing, "idle_down"]:
			if visual.sprite_frames.has_animation(clip):
				visual.play(clip)
				break
	reload_timer += delta
	if reload_timer > 1.0:
		reload_timer = 0
		reload_assets()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			reload_assets(true)
		if event.keycode == KEY_L:
			evening = not evening
			sun.light_color = Color("b4b3e3") if evening else Color("f3e5be")
			sun.light_energy = 0.35 if evening else 1.0
			environment.ambient_light_energy = 0.25 if evening else 0.7

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.09, 0.88)
	style.border_color = Color("677e4a")
	style.set_border_width_all(1)
	style.set_content_margin_all(14)
	style.set_corner_radius_all(5)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "MY GAME STUDIO / ЛЕСНАЯ ПРОБА"
	title.add_theme_color_override("font_color", Color("c8dba5"))
	title.add_theme_font_size_override("font_size", 17)
	box.add_child(title)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 11)
	box.add_child(status)
	var help := Label.new()
	help.text = "WASD / стрелки — движение   ·   L — день / вечер   ·   F5 — обновить ассеты"
	help.add_theme_color_override("font_color", Color("9bad89"))
	help.add_theme_font_size_override("font_size", 11)
	box.add_child(help)
	panel.add_child(box)
	layer.add_child(panel)
