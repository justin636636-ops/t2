extends SceneTree
## Compare original primitives against batched geometry under identical lighting.

func _initialize() -> void:
	run.call_deferred()

func image_after_draw() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	root.size = Vector2i(1440, 900)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.root.hide()
	game.world.vfx.clear()
	for effect in game.world.effects:
		effect.node.queue_free()
	game.world.effects.clear()
	var originals: Array = []
	for target in game.world.targets:
		var node = Node3D.new()
		target.body_visual.add_child(node)
		var outer = game.world.ring(node, Vector3(0, 0, 0.21), 0.22, 0.045, Color("eedcae"))
		outer.rotation_degrees.x = 90
		var middle = game.world.ring(node, Vector3(0, 0, 0.23), 0.137, 0.028, Color("b36450"))
		middle.rotation_degrees.x = 90
		var center = game.world.cylinder(node, Vector3(0, 0, 0.24), 0.065, 0.025, Color("eedcae"))
		center.rotation_degrees.x = 90
		for point in [Vector3(-0.27, 0, 0.22), Vector3(0.27, 0, 0.22), Vector3(0, 0.27, 0.22), Vector3(0, -0.27, 0.22)]:
			game.world.box(node, point, Vector3(0.04, 0.04, 0.045), Color("eedcae"))
		node.hide()
		originals.append(node)
	for i in range(12):
		await process_frame
	var batched: Image = await image_after_draw()
	var batch_draws = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	batched.save_png(ProjectSettings.globalize_path("res://artifacts/v04-weakpoint-batched.png"))
	for i in range(originals.size()):
		originals[i].show()
		game.world.targets[i].weak_visual.hide()
	for i in range(4):
		await process_frame
	var original: Image = await image_after_draw()
	var original_draws = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	original.save_png(ProjectSettings.globalize_path("res://artifacts/v04-weakpoint-original.png"))
	# Byte comparison checks geometry, normal shading, silhouette and depth.
	var before = original.get_data()
	var after = batched.get_data()
	var different = 0
	var maximum = 0
	for i in range(before.size()):
		var difference = absi(int(before[i]) - int(after[i]))
		if difference > 1:
			different += 1
		maximum = maxi(maximum, difference)
	var result = {"original_draws": original_draws, "batched_draws": batch_draws, "saved_draws": original_draws - batch_draws, "channels_differing_over_1": different, "max_channel_difference": maximum, "image_bytes": before.size(), "identical_scene": true}
	print("WEAKPOINT REVIEW: ", JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if different == 0 and original_draws > batch_draws else 1)
