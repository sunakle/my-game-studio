@tool
extends RefCounted

const ROOT := "res://generated"
const MAX_ZIP := 64 * 1024 * 1024
const MAX_UNPACKED := 256 * 1024 * 1024
const DIRECTIONS := ["down", "left", "right", "up"]

static func failure(message: String) -> Dictionary:
	return {"ok": false, "message": "Импорт не выполнен: " + message}

static func valid_id(value: Variant) -> bool:
	if not value is String:
		return false
	var regex := RegEx.new()
	regex.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
	return regex.search(value) != null

static func valid_number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func valid_point(value: Variant) -> bool:
	return value is Dictionary and valid_number(value.get("x"), -8192, 8192) and valid_number(value.get("y"), -8192, 8192)

# Check central directory limits BEFORE ZIPReader allocates decompressed entries.
static func check_zip(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_ZIP:
		return "Архив недоступен или больше 64 МиБ."
	var bytes := file.get_buffer(file.get_length())
	file.close()
	if bytes.size() < 22:
		return "Повреждённый ZIP."
	var end := -1
	for i in range(bytes.size() - 22, maxi(-1, bytes.size() - 65558), -1):
		if bytes.decode_u32(i) == 0x06054b50:
			end = i
			break
	if end < 0:
		return "В ZIP отсутствует каталог."
	var count := bytes.decode_u16(end + 10)
	var pos := bytes.decode_u32(end + 16)
	if count < 1 or count > 8192 or bytes.decode_u16(end + 4) != 0 or bytes.decode_u16(end + 6) != 0:
		return "Многотомные и слишком большие архивы не поддерживаются."
	var total := 0
	for i in range(count):
		if pos + 46 > bytes.size() or bytes.decode_u32(pos) != 0x02014b50:
			return "Каталог ZIP повреждён."
		total += bytes.decode_u32(pos + 24)
		var length := bytes.decode_u16(pos + 28)
		var extra := bytes.decode_u16(pos + 30)
		var comment := bytes.decode_u16(pos + 32)
		if total > MAX_UNPACKED or pos + 46 + length + extra + comment > bytes.size():
			return "Лимит распакованных данных — 256 МиБ."
		var name := bytes.slice(pos + 46, pos + 46 + length).get_string_from_utf8()
		if name.begins_with("/") or name.contains("\\") or name.contains(":") or ".." in name.split("/"):
			return "Недопустимый путь в архиве."
		if name != "manifest.json" and not (name.begins_with("assets/") and name.ends_with(".png")):
			return "Разрешены только manifest.json и PNG в assets/."
		if (bytes.decode_u32(pos + 38) >> 16) & 0xf000 == 0xa000:
			return "Символьные ссылки запрещены."
		pos += 46 + length + extra + comment
	return ""

static func import_package(path: String, slot: String = "tree") -> Dictionary:
	var problem := check_zip(path)
	if problem != "":
		return failure(problem)
	if slot not in ["tree", "rock", "character", "grass", "path", "water"]:
		return failure("Неизвестный слот тестовой сцены.")
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return failure("Невозможно открыть ZIP.")
	var manifest = JSON.parse_string(reader.read_file("manifest.json").get_string_from_utf8())
	if not manifest is Dictionary or manifest.get("schemaVersion") != 1:
		reader.close()
		return failure("Неподдерживаемая версия manifest.json.")
	if not manifest.get("assets") is Array or manifest.assets.size() != 1:
		reader.close()
		return failure("Версия 1 импортирует ровно один ассет за операцию.")
	var a = manifest.assets[0]
	problem = validate_metadata(a)
	if problem != "":
		reader.close()
		return failure(problem)
	if not a.image in reader.get_files():
		reader.close()
		return failure("Отсутствует изображение атласа.")
	var png_bytes := reader.read_file(a.image)
	reader.close()
	if png_bytes.size() < 24 or png_bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return failure("Изображение не является PNG.")
	# PNG dimensions are big-endian. Bound them before decoding.
	var iw := (int(png_bytes[16]) << 24) | (int(png_bytes[17]) << 16) | (int(png_bytes[18]) << 8) | int(png_bytes[19])
	var ih := (int(png_bytes[20]) << 24) | (int(png_bytes[21]) << 16) | (int(png_bytes[22]) << 8) | int(png_bytes[23])
	if iw < 1 or ih < 1 or iw > 8192 or ih > 8192 or iw * ih > 64 * 1024 * 1024:
		return failure("Атлас превышает допустимый размер.")
	for f in a.frames:
		var r: Dictionary = f.rect
		if r.x + r.w > iw or r.y + r.h > ih:
			return failure("Прямоугольник кадра выходит за пределы PNG.")
	var image := Image.new()
	if image.load_png_from_buffer(png_bytes) != OK:
		return failure("PNG повреждён.")
	var texture := ImageTexture.create_from_image(image)
	var library := SpriteFrames.new()
	library.clear_all()
	if library.has_animation("default"):
		library.remove_animation("default")
	var frames_by_id: Dictionary = {}
	for f in a.frames:
		frames_by_id[f.id] = f
	for clip in a.animations:
		for direction in DIRECTIONS:
			var sequence: Array = clip.sequences[direction]
			if sequence.is_empty():
				continue
			var name: String = str(clip.name) + "_" + str(direction)
			if library.has_animation(name):
				return failure("Повторяется имя анимации.")
			library.add_animation(name)
			library.set_animation_speed(name, 1.0)
			library.set_animation_loop(name, clip.loop)
			for frame_id in sequence:
				var f: Dictionary = frames_by_id[frame_id]
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(f.rect.x, f.rect.y, f.rect.w, f.rect.h)
				atlas.filter_clip = true
				library.add_frame(name, atlas, float(f.durationMs) / 1000.0 / float(clip.speed))
	if library.get_animation_names().is_empty():
		return failure("В пакете нет кадров анимации.")
	# Only a validated UUID can determine the generated destination.
	var destination := ROOT + "/" + str(a.id)
	if DirAccess.make_dir_recursive_absolute(destination) != OK:
		return failure("Невозможно создать папку generated.")
	var stage := destination + "/frames.stage.tres"
	if ResourceSaver.save(library, stage) != OK:
		return failure("Невозможно записать ресурс кадров.")
	var meta_path := destination + "/metadata.json"
	var meta_file := FileAccess.open(meta_path + ".tmp", FileAccess.WRITE)
	var image_file := FileAccess.open(destination + "/sheet.png.tmp", FileAccess.WRITE)
	if meta_file == null or image_file == null:
		return failure("Нет доступа к файлам generated.")
	meta_file.store_string(JSON.stringify(a, "\t"))
	image_file.store_buffer(png_bytes)
	meta_file.close()
	image_file.close()
	for names in [["frames.stage.tres", "frames.tres"], ["metadata.json.tmp", "metadata.json"], ["sheet.png.tmp", "sheet.png"]]:
		if DirAccess.rename_absolute(destination + "/" + names[0], destination + "/" + names[1]) != OK:
			return failure("Не удалось заменить сгенерированный файл. Повторите импорт.")
	library.take_over_path(destination + "/frames.tres")
	var scene_2d := AnimatedSprite2D.new()
	scene_2d.name = "Asset2D"
	scene_2d.set_script(load("res://addons/my_game_studio/runtime/sprite_2d.gd"))
	scene_2d.metadata_path = meta_path
	scene_2d.sprite_frames = library
	scene_2d.animation = library.get_animation_names()[0]
	scene_2d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if a.technique == "pixel" else CanvasItem.TEXTURE_FILTER_LINEAR
	var packed_2d := PackedScene.new()
	packed_2d.pack(scene_2d)
	var scene_3d := AnimatedSprite3D.new()
	scene_3d.name = "Asset3D"
	scene_3d.set_script(load("res://addons/my_game_studio/runtime/sprite_3d.gd"))
	scene_3d.metadata_path = meta_path
	scene_3d.sprite_frames = library
	scene_3d.animation = library.get_animation_names()[0]
	scene_3d.pixel_size = 1.0 / float(a.pixelsPerUnit)
	scene_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	scene_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if a.technique == "pixel" else BaseMaterial3D.TEXTURE_FILTER_LINEAR
	scene_3d.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD if a.technique == "pixel" else SpriteBase3D.ALPHA_CUT_DISABLED
	var packed_3d := PackedScene.new()
	packed_3d.pack(scene_3d)
	var error_2d := ResourceSaver.save(packed_2d, destination + "/preview_2d.tscn")
	var error_3d := ResourceSaver.save(packed_3d, destination + "/preview_3d.tscn")
	scene_2d.free()
	scene_3d.free()
	if error_2d != OK or error_3d != OK:
		return failure("Не удалось записать сцены предпросмотра.")
	var bindings: Dictionary = {}
	if FileAccess.file_exists(ROOT + "/bindings.json"):
		var old = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "/bindings.json"))
		if old is Dictionary:
			bindings = old
	bindings[slot] = a.id
	var bindings_file := FileAccess.open(ROOT + "/bindings.json.tmp", FileAccess.WRITE)
	if bindings_file == null:
		return failure("Невозможно сохранить привязку тестовой сцены.")
	bindings_file.store_string(JSON.stringify(bindings))
	bindings_file.close()
	if DirAccess.rename_absolute(ROOT + "/bindings.json.tmp", ROOT + "/bindings.json") != OK:
		return failure("Не удалось обновить привязку.")
	return {"ok": true, "id": a.id, "directory": destination, "message": "Импортирован «" + str(a.name) + "».\nUUID: " + str(a.id) + "\nСлот: " + slot + ". В тестовой сцене нажмите F5.\nРучные сцены и игровая логика сохранены."}

static func validate_metadata(a: Variant) -> String:
	if not a is Dictionary or not valid_id(a.get("id")):
		return "Некорректный UUID ассета."
	if not a.get("name") is String or a.name.length() > 120 or a.get("technique") not in ["pixel", "painted", "vector"]:
		return "Некорректное название или техника."
	if not valid_number(a.get("width"), 1, 1024) or not valid_number(a.get("height"), 1, 1024) or not valid_number(a.get("pixelsPerUnit"), 1, 1024) or not valid_point(a.get("pivot")):
		return "Некорректные размеры, масштаб или опора."
	if a.get("image") != "assets/" + str(a.id) + "/sheet.png":
		return "Недопустимое расположение атласа."
	if not a.get("frames") is Array or a.frames.is_empty() or a.frames.size() > 256 or not a.get("animations") is Array or a.animations.size() > 64:
		return "Некорректное количество кадров или анимаций."
	var ids: Dictionary = {}
	for f in a.frames:
		if not f is Dictionary or not valid_id(f.get("id")) or ids.has(f.id) or not valid_number(f.get("durationMs"), 10, 60000) or not valid_point(f.get("pivot")):
			return "Некорректный кадр."
		ids[f.id] = true
		var r = f.get("rect")
		if not r is Dictionary or not valid_number(r.get("x"), 0, 8192) or not valid_number(r.get("y"), 0, 8192) or r.get("w") != a.width or r.get("h") != a.height:
			return "Некорректный прямоугольник кадра."
		if not f.get("events") is Array or f.events.size() > 128:
			return "Некорректные события."
		for event in f.events:
			if not event is Dictionary or not event.get("name") is String or event.name.length() > 120 or not valid_number(event.get("offsetMs"), 0, float(f.durationMs)):
				return "Некорректное событие кадра."
	for clip in a.animations:
		if not clip is Dictionary or not clip.get("name") is String or clip.name.is_empty() or clip.name.length() > 120 or not valid_number(clip.get("speed"), 0.1, 8) or not clip.get("loop") is bool or not clip.get("sequences") is Dictionary:
			return "Некорректная анимация."
		for direction in DIRECTIONS:
			var sequence = clip.sequences.get(direction)
			if not sequence is Array or sequence.size() > 256:
				return "Некорректное направление."
			for frame_id in sequence:
				if not ids.has(frame_id):
					return "В анимации указан отсутствующий кадр."
	return ""
