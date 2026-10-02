extends SceneTree
## Actual archived v0.9 world versus current art at the same held native pose.

func _initialize() -> void:
	run.call_deferred()

func rendered() -> void:
	for i in range(8):
		await process_frame
		await RenderingServer.frame_post_draw

func run() -> void:
	root.size = Vector2i(1440, 900)
	var archive = ProjectSettings.globalize_path("res://../.art_archive/2026-10-02-v10/")
	var old_script = GDScript.new()
	old_script.source_code = FileAccess.get_file_as_string(archive + "world.gd")
	if old_script.reload() != OK:
		push_error("Cannot compile the archived v0.9 world")
		quit(1)
		return
	var before = old_script.new()
	root.add_child(before)
	before.update_world(0.3, false, 1)
	await rendered()
	var old_image: Image = root.get_texture().get_image()
	old_image.save_png(ProjectSettings.globalize_path("res://artifacts/v10-before-stage.png"))
	var before_points: Array = []
	for target in before.targets:
		before_points.append(before.camera.unproject_position(target.weak_hit.global_position))
	before.queue_free()
	await process_frame
	var current = load("res://scripts/world.gd").new()
	root.add_child(current)
	current.update_world(0.3, false, 1)
	await rendered()
	var image_: Image = root.get_texture().get_image()
	image_.save_png(ProjectSettings.globalize_path("res://artifacts/v10-after-stage.png"))
	var max_registration_change = 0.0
	var samples: Array = []
	for i in range(current.targets.size()):
		var target = current.targets[i]
		var screen: Vector2 = current.camera.unproject_position(target.weak_hit.global_position)
		max_registration_change = maxf(max_registration_change, screen.distance_to(before_points[i]))
		if i < 5:
			var cheek: Vector2 = current.camera.unproject_position(target.body_visual.to_global(Vector3(0.34, -0.15, 0.20)))
			var value = 0.0
			for x in range(-2, 3):
				for y in range(-2, 3):
					var c = image_.get_pixel(int(cheek.x) + x, int(cheek.y) + y)
					value += (c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722) / 25.0
			samples.append(value)
	if max_registration_change > 0.01 or samples.any(func(value): return value < 0.2):
		push_error("Art review changed target placement or blacked out a bare face sample")
		quit(1)
		return
	var art = current.attraction_art
	var triangles = 0
	for piece in art.pieces:
		triangles += piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	print("STAGE ART REVIEW: ", JSON.stringify({"same_camera_and_held_pose": true, "resolution": "1440x900", "max_target_registration_change_px": max_registration_change, "face_luminance": samples, "batches": art.pieces.size(), "triangles": triangles, "lettering_triangles": art.lettering_triangles, "letter_bounds": art.letter_bounds.map(func(bound): return {"position": [bound.position.x, bound.position.y, bound.position.z], "size": [bound.size.x, bound.size.y, bound.size.z]}), "scope": "Actual archived v0.9 world at the same native camera and held pose. Samples check gross visibility, not human readability or realtime performance."}))
	current.queue_free()
	await process_frame
	quit()
