extends SceneTree
## Frozen-scene native comparison of practical lamp submission and emission.

var game: Node3D

func _initialize() -> void:
	run.call_deferred()

func image_after_draw() -> Image:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func lamp_luminance(image_: Image, pos: Vector3) -> float:
	var center = Vector2i(game.world.camera.unproject_position(pos))
	var luminance = 0.0
	for y in range(-1, 2):
		for x in range(-1, 2):
			var color = image_.get_pixel(center.x + x, center.y + y)
			luminance += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return luminance / 9

func run() -> void:
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.root.hide()
	game.world.vfx.clear()
	for effect in game.world.effects:
		effect.node.queue_free()
	game.world.effects.clear()
	var originals = Node3D.new()
	game.world.add_child(originals)
	for i in range(29):
		var pos = Vector3(-8.6 + i * 0.614, 6.58 - 0.10 * sin(i / 28.0 * PI), -4.12)
		game.world.line_between(originals, pos + Vector3(0, 0.2, 0), pos, 0.011, Color("2b2427"))
		game.world.sphere(originals, pos, 0.056, Color("ffce8f"), Vector3(1, 1.2, 1), 4.0)
	originals.hide()
	var current: Image = await image_after_draw()
	var batched_draws = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	current.save_png(ProjectSettings.globalize_path("res://artifacts/v07-practicals-batched.png"))
	var luminances: Array[float] = []
	for i in range(29):
		var pos = game.world.stage_show.bulbs.multimesh.get_instance_transform(i).origin
		luminances.append(lamp_luminance(current, pos))
	game.world.stage_show.hide()
	originals.show()
	var previous: Image = await image_after_draw()
	var original_draws = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	previous.save_png(ProjectSettings.globalize_path("res://artifacts/v07-practicals-original.png"))
	var total = 0.0
	for value in luminances:
		total += value
	luminances.sort()
	var result = {"batched_draws": batched_draws, "original_draws": original_draws, "saved_draws": original_draws - batched_draws, "core_luminance_mean": total / 29, "core_luminance_min": luminances.front(), "core_luminance_max": luminances.back(), "scope": "same frozen scene and lamp positions; new emission intentionally differs, not a pixel-equivalence test or realtime benchmark"}
	print("PRACTICAL REVIEW: ", JSON.stringify(result))
	var valid = original_draws > batched_draws and total / 29 > 0.7 and luminances.front() > 0.5
	if not valid:
		push_error("Practical batching or visible lamp emission did not meet the native review")
	game.queue_free()
	await process_frame
	quit(0 if valid else 1)
