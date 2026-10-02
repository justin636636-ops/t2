extends SceneTree
## Native review clip with one gameplay tick per captured frame.
## Uses real input, collision and scoring; does not alter outcomes or target state.

var game: Node3D
var review_aim = Vector2(720, 450)

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		game.aim = review_aim
		game._physics_process(1.0 / 60.0)
		game._process(1.0 / 60.0)
		await RenderingServer.frame_post_draw

func aim_at(pos: Vector3) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position = game.world.camera.unproject_position(pos)
	review_aim = motion.position
	Input.parse_input_event(motion)
	await frames(1)

func shoot(pos: Vector3) -> void:
	await aim_at(pos)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	# Use the intended shot coordinate; live OS pointer motion must not replace
	# the injected review click while another application is being used.
	event.position = game.world.camera.unproject_position(pos)
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func screenshot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v22-" + name_ + ".png"))

func run() -> void:
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	# Offline capture must not catch up several gameplay ticks between drawn
	# frames when the host is rendering another GPU-heavy application.
	game.set_physics_process(false)
	game.set_process(false)
	await frames(90)
	game.start_round()
	await frames(90)
	# Show continuous aim-follow without spending ammunition or moving the camera.
	for i in [0, 4, 3, 1, 2]:
		await aim_at(game.world.targets[i].global_position + Vector3(0, 0, 0.24))
		await frames(18)
	var target = game.world.targets[2]
	await shoot(target.global_position + Vector3(0, 0, 0.24))
	await screenshot("13-spring-shot")
	await frames(18)
	await screenshot("10-spring-motion")
	# Keep the real target alive long enough to show its first carpet rebound.
	for i in range(100):
		if target.carpet_used:
			break
		await frames(1)
	await frames(5)
	await screenshot("14-carpet-rebound")
	await frames(12)
	await shoot(target.global_position + Vector3(0, 0, 0.24))
	await frames(3)
	var kill: Dictionary = game.records.back() if not game.records.is_empty() else {}
	print("MOTION FIRST KILL: ", JSON.stringify(kill))
	if not kill.get("destroyed", false) or not kill.get("air", false) or not kill.get("weak", false):
		push_error("Review did not complete the intended aerial weakpoint kill")
		quit(1)
		return
	await screenshot("11-impact-motion")
	await frames(45)
	var key = InputEventKey.new()
	key.physical_keycode = KEY_R
	key.keycode = KEY_R
	key.pressed = true
	Input.parse_input_event(key)
	await frames(24)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await frames(85)
	game.continue_group()
	await frames(55)
	await shoot(game.world.bell.global_position)
	await frames(16)
	await screenshot("12-duck-motion")
	var pirate = game.world.targets[5]
	await shoot(pirate.global_position + Vector3(0, 0, 0.24))
	await frames(34)
	await shoot(game.world.targets[6].global_position + Vector3(0, 0, 0.24))
	await frames(34)
	await shoot(game.world.targets[7].global_position + Vector3(0, 0, 0.24))
	await frames(34)
	await shoot(game.world.targets[8].global_position + Vector3(0, 0, 0.24))
	await frames(95)
	game.continue_group()
	await frames(180)
	await screenshot("15-victory")
	print("MOTION REVIEW: group=", game.group_index, " score=", game.total_score, " relay=", game.saw_relay, " duck=", game.saw_duck)
	quit()
