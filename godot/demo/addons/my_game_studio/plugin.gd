@tool
extends EditorPlugin

const Importer = preload("res://addons/my_game_studio/importer.gd")
var dock: VBoxContainer
var picker: FileDialog
var message: RichTextLabel
var slot: OptionButton

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "My Game Studio"
	var title := Label.new()
	title.text = "My Game Studio · пакет v1"
	dock.add_child(title)
	var description := Label.new()
	description.text = "PNG и анимации из браузерной студии.\nПовторный импорт обновляет ассет по UUID."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(description)
	slot = OptionButton.new()
	for entry in ["Дерево", "Камень", "Персонаж", "Трава", "Дорожка", "Вода"]:
		slot.add_item(entry)
	dock.add_child(slot)
	var button := Button.new()
	button.text = "Импортировать .mgasset.zip"
	dock.add_child(button)
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.filters = PackedStringArray(["*.zip ; My Game Studio asset package"])
	picker.size = Vector2i(800, 560)
	button.pressed.connect(func(): picker.popup_centered())
	picker.file_selected.connect(_import)
	dock.add_child(picker)
	message = RichTextLabel.new()
	message.custom_minimum_size = Vector2(220, 150)
	message.fit_content = true
	message.text = "Соединение с сайтом не требуется.\nВыберите слот тестовой сцены и скачанный пакет.\nВ запущенной сцене нажмите F5 для обновления."
	dock.add_child(message)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)

func _import(path: String) -> void:
	var keys := ["tree", "rock", "character", "grass", "path", "water"]
	var result: Dictionary = Importer.import_package(path, keys[slot.selected])
	message.text = result.get("message", "Неизвестный результат")
	if result.get("ok", false):
		get_editor_interface().get_resource_filesystem().scan()

func _exit_tree() -> void:
	remove_control_from_docks(dock)
	dock.queue_free()
