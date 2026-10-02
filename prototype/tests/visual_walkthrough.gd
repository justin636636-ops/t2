extends SceneTree

var game: Node3D
var folder = "res://artifacts/"

func _initialize() -> void:
	run.call_deferred()

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image = root.get_texture().get_image()
	var error = image.save_png(ProjectSettings.globalize_path(folder + filename))
	print("VISUAL: ", filename, " error=", error)

func mouse_shot(pos: Vector3) -> void:
	game.cooldown = 0
	var e = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = game.world.camera.unproject_position(pos)
	e.pressed = true
	Input.parse_input_event(e)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await frames()

func run() -> void:
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(20)
	game.sound_on = false
	await capture("01-welcome.png")
	game.start_round()
	await frames(6)
	await capture("02-booth.png")
	# Sample warmed rendering in the actual moving scene on this machine.
	var started = Time.get_ticks_usec()
	for i in range(120):
		await process_frame
	var milliseconds = float(Time.get_ticks_usec() - started) / 1000.0
	print("RENDER_SAMPLE: ", JSON.stringify({"frames": 120, "mean_frame_ms": milliseconds / 120.0, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "visible_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), "resolution": "1440x900", "scope": "local warm scene sample; not a hardware minimum"}))
	game.toggle_pause()
	await frames(16)
	await capture("03-configuration.png")
	game.toggle_pause()
	var target = game.world.targets[2]
	await mouse_shot(target.global_position + Vector3(0, 0, 0.24))
	await frames(18)
	await capture("04-airborne.png")
	await mouse_shot(target.global_position + Vector3(0, 0, 0.24))
	game.settle("early")
	await frames(16)
	await capture("05-report-growth.png")
	game.continue_group()
	await frames(4)
	await mouse_shot(game.world.bell.global_position)
	await frames(4)
	await capture("06-duck-help.png")
	# Verify the scaled layout on a smaller display through the real renderer.
	game.toggle_pause()
	root.size = Vector2i(1152, 720)
	await frames(16)
	await capture("07-smaller-window.png")
	root.size = Vector2i(1920, 1080)
	await frames(5)
	await capture("08-widescreen.png")
	game.hud.show_settings(game.hud.show_pause)
	await frames(16)
	await capture("09-presentation-settings.png")
	game.reset_round()
	game.hud.show_tutorial()
	await frames(20)
	await capture("17-tutorial.png")
	game.hud.show_start()
	game.start_round()
	game.time_left = 0.01
	await frames(4)
	game.continue_group()
	await frames(20)
	await capture("16-timeout-failure.png")
	game.queue_free()
	await process_frame
	quit()
