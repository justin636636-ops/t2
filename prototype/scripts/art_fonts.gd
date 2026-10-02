extends RefCounted
## Bundled OFL fonts make the game's typography independent of the host OS.

static var cache: Dictionary = {}

static func get_font(kind: String = "body") -> Font:
	if not cache.has(kind):
		var file = "MidnightDisplay" if kind == "title" else ("MidnightNumber" if kind == "number" else "MidnightSans")
		var font: FontFile = load("res://assets/fonts/" + file + ".ttf")
		font.allow_system_fallback = false
		cache[kind] = font
	return cache[kind]
