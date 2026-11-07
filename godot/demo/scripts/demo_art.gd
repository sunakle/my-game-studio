extends RefCounted

# Original procedural placeholders, made for this project. No external artwork.
static func texture(kind: String) -> ImageTexture:
	var w := 64 if kind == "tree" else 32
	var h := 96 if kind == "tree" else 48 if kind == "character" else 32
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	if kind in ["grass", "path", "water"]:
		var base := Color("5a7245") if kind == "grass" else Color("8b7754") if kind == "path" else Color("426d78")
		image.fill(base)
		for y in range(h):
			for x in range(w):
				if (x * 73 + y * 131 + x * y * 17) % 31 == 0:
					image.set_pixel(x, y, base.lightened(0.15))
	if kind == "tree":
		ellipse(image, Vector2(32, 88), Vector2(22, 5), Color("25382c"))
		image.fill_rect(Rect2i(27, 45, 12, 43), Color("5e4934"))
		image.fill_rect(Rect2i(28, 48, 4, 38), Color("977348"))
		image.fill_rect(Rect2i(23, 85, 21, 4), Color("493d30"))
		ellipse(image, Vector2(32, 38), Vector2(27, 27), Color("253e30"))
		ellipse(image, Vector2(20, 42), Vector2(17, 18), Color("34563a"))
		ellipse(image, Vector2(43, 39), Vector2(17, 20), Color("3c6140"))
		ellipse(image, Vector2(29, 25), Vector2(22, 19), Color("4d7545"))
		ellipse(image, Vector2(22, 23), Vector2(14, 12), Color("72924f"))
		ellipse(image, Vector2(40, 20), Vector2(13, 11), Color("5e8449"))
	if kind == "rock":
		ellipse(image, Vector2(16, 28), Vector2(14, 3), Color("26382e"))
		ellipse(image, Vector2(16, 20), Vector2(13, 8), Color("777f73"))
		ellipse(image, Vector2(14, 17), Vector2(10, 5), Color("a4a592"))
	if kind == "character":
		ellipse(image, Vector2(16, 46), Vector2(9, 2), Color("26382e"))
		image.fill_rect(Rect2i(11, 29, 4, 15), Color("343530"))
		image.fill_rect(Rect2i(18, 29, 4, 15), Color("343530"))
		image.fill_rect(Rect2i(8, 18, 17, 15), Color("b78056"))
		image.fill_rect(Rect2i(8, 19, 4, 13), Color("e0bc79"))
		image.fill_rect(Rect2i(10, 7, 14, 12), Color("dfb58b"))
		image.fill_rect(Rect2i(9, 5, 15, 7), Color("4c3d33"))
		image.fill_rect(Rect2i(9, 8, 5, 8), Color("4c3d33"))
		image.fill_rect(Rect2i(22, 13, 2, 2), Color("283630"))
	return ImageTexture.create_from_image(image)

static func ellipse(image: Image, center: Vector2, radius: Vector2, color: Color) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var relative := (Vector2(x, y) - center) / radius
			if relative.length_squared() <= 1.0:
				image.set_pixel(x, y, color)
