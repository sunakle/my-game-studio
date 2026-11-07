extends SceneTree

const Importer = preload("res://addons/my_game_studio/importer.gd")

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Передайте путь к .mgasset.zip после --")
		quit(1)
		return
	var result: Dictionary = Importer.import_package(args[0], "tree")
	if not result.ok:
		push_error(result.message)
		quit(1)
		return
	var directory: String = result.directory
	var frames: SpriteFrames = ResourceLoader.load(directory + "/frames.tres", "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if frames == null or not frames.has_animation("idle_down"):
		push_error("SpriteFrames отсутствует")
		quit(1)
		return
	assert(is_equal_approx(frames.get_frame_duration("idle_down", 0), 0.125))
	var texture: AtlasTexture = frames.get_frame_texture("idle_down", 0)
	assert(texture.region == Rect2(2, 2, 64, 96))
	var manual := FileAccess.open("res://manual_sentinel.txt", FileAccess.WRITE)
	manual.store_string("ручная игровая логика")
	manual.close()
	var result_again: Dictionary = Importer.import_package(args[0], "tree")
	assert(result_again.ok and result_again.id == result.id)
	assert(FileAccess.get_file_as_string("res://manual_sentinel.txt") == "ручная игровая логика")
	var invalid := FileAccess.open("res://invalid_test.zip", FileAccess.WRITE)
	invalid.store_string("invalid")
	invalid.close()
	assert(not Importer.import_package("res://invalid_test.zip").ok)
	assert(FileAccess.file_exists(directory + "/frames.tres"))
	var scene_2d: PackedScene = ResourceLoader.load(directory + "/preview_2d.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var node_2d: AnimatedSprite2D = scene_2d.instantiate()
	root.add_child(node_2d)
	await process_frame
	assert(node_2d.animation == "idle_down" and node_2d.sprite_frames.get_frame_count(node_2d.animation) > 0)
	assert(node_2d.offset == Vector2(-32, -88))
	var scene_3d: PackedScene = ResourceLoader.load(directory + "/preview_3d.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var node_3d: AnimatedSprite3D = scene_3d.instantiate()
	root.add_child(node_3d)
	await process_frame
	assert(node_3d.animation == "idle_down" and node_3d.sprite_frames.get_frame_count(node_3d.animation) > 0)
	assert(is_equal_approx(node_3d.pixel_size, 1.0 / 32.0))
	assert(node_3d.offset == Vector2(0, 40))
	if args.size() > 1:
		var old_hash := FileAccess.get_sha256(directory + "/sheet.png")
		var update_result: Dictionary = Importer.import_package(args[1], "tree")
		assert(update_result.ok and update_result.id == result.id)
		assert(FileAccess.get_sha256(directory + "/sheet.png") != old_hash, "Изображение должно реально измениться")
		var updated: SpriteFrames = ResourceLoader.load(directory + "/frames.tres", "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		var updated_texture: AtlasTexture = updated.get_frame_texture("idle_down", 0)
		assert(updated_texture.atlas.get_image().get_pixel(34, 50).r > 0.95)
		# Leave the original demonstration artwork for the user.
		assert(Importer.import_package(args[0], "tree").ok)
	if args.size() > 2:
		var water: Dictionary = Importer.import_package(args[2], "water")
		assert(water.ok)
		var water_frames: SpriteFrames = ResourceLoader.load(str(water.directory) + "/frames.tres", "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		assert(water_frames.get_frame_count("idle_down") == 4)
		assert(is_equal_approx(water_frames.get_frame_duration("idle_down", 0), 0.18))
	print("PASS: ZIP -> SpriteFrames -> 2D/3D; pivot, scale, reimport and manual scene preservation")
	DirAccess.remove_absolute("res://invalid_test.zip")
	DirAccess.remove_absolute("res://manual_sentinel.txt")
	quit(0)
