extends SceneTree
## Native same-camera comparison, loading the actual v0.7 world/shader backup.
## Does not swap files or change project assets. Both scenes hold identical poses.

func _initialize() -> void:
	run.call_deferred()

func rendered() -> void:
	for i in range(6):
		await process_frame
		await RenderingServer.frame_post_draw

func screenshot(name_: String) -> Image:
	var img = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://artifacts/" + name_))
	return img

func run() -> void:
	root.size = Vector2i(1440, 900)
	var archive = ProjectSettings.globalize_path("res://../.art_archive/2026-10-02-v08/")
	var old_script = GDScript.new()
	old_script.source_code = FileAccess.get_file_as_string(archive + "world.gd")
	if old_script.reload() != OK:
		push_error("Cannot compile the archived world for the native art comparison")
		quit(1)
		return
	var before = old_script.new()
	root.add_child(before)
	for value in before.material_cache.values():
		if value is ShaderMaterial:
			var name_ = value.shader.resource_path.get_file()
			if name_ in ["crafted_surface.gdshader", "fabric_surface.gdshader"]:
				var original = Shader.new()
				original.code = FileAccess.get_file_as_string(archive + name_)
				value.shader = original
	before.update_world(0.3, false, 1)
	await rendered()
	screenshot("v08-before-materials.png")
	before.queue_free()
	await process_frame
	var current = load("res://scripts/world.gd").new()
	root.add_child(current)
	current.update_world(0.3, false, 1)
	await rendered()
	var image_ = screenshot("v08-after-materials.png")
	# Native face-vs-background samples are a gross visibility check, not a
	# player identification study or a pixel-equivalence test.
	var samples = []
	for target in current.targets.slice(0, 5):
		var spot = current.camera.unproject_position(target.global_position + Vector3(0.30, 0.15, 0.23))
		var face = image_.get_pixel(int(spot.x), int(spot.y))
		samples.append(face.r * 0.2126 + face.g * 0.7152 + face.b * 0.0722)
	if samples.any(func(value): return value < 0.2):
		push_error("Current native face samples are unexpectedly dark")
		quit(1)
		return
	print("MATERIAL REVIEW: ", JSON.stringify({"resolution": "1440x900", "face_luminance_samples": samples, "scope": "actual archived v0.7 world/shaders and current world at the same camera and held pose; native artwork review, no human readability or realtime performance claim"}))
	current.queue_free()
	await process_frame
	quit()
