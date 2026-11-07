extends AnimatedSprite3D

@export var metadata_path: String
var metadata: Dictionary = {}

func _ready() -> void:
	if FileAccess.file_exists(metadata_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
		if parsed is Dictionary:
			metadata = parsed
	frame_changed.connect(_apply_pivot)
	animation_changed.connect(_apply_pivot)
	_apply_pivot()
	play()

func _apply_pivot() -> void:
	centered = true
	var pivot: Dictionary = metadata.get("pivot", {"x": 0, "y": 0})
	for clip in metadata.get("animations", []):
		for direction in clip.get("sequences", {}):
			if str(clip.name) + "_" + direction == str(animation):
				var sequence: Array = clip.sequences[direction]
				if frame >= sequence.size():
					continue
				for entry in metadata.get("frames", []):
					if entry.id == sequence[frame]:
						pivot = entry.pivot
	offset = Vector2(float(metadata.get("width", 0)) / 2.0 - float(pivot.x), float(pivot.y) - float(metadata.get("height", 0)) / 2.0)
