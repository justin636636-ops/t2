extends SceneTree
## Native fixed-step review of the natural fifth shot and immediate skip paths.

var game: Node3D
var review_aim = Vector2(720, 450)
var ticks = 0

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		game.aim = review_aim
		game._physics_process(1.0 / 60.0)
		game._process(1.0 / 60.0)
		ticks += 1
		await RenderingServer.frame_post_draw

func shoot(index: int, weak: bool = true) -> void:
	var target = game.world.targets[index]
	var offset = Vector3(0 if weak else 0.44, 0, 0.24)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = game.world.camera.unproject_position(target.global_position + offset)
	review_aim = event.position
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func screenshot(name_: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v14-" + name_ + ".png"))

func keyboard(code: int) -> void:
	var key = InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await frames(2)

func run() -> void:
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await frames(60)
	game.start_round()
	await frames(70)
	await shoot(2)
	await frames(20)
	await shoot(2)
	await frames(38)
	await shoot(0, false)
	await frames(38)
	await shoot(1)
	await frames(38)
	await shoot(3, false)
	var settled_score: int = game.total_score
	var settled_time: float = game.time_left
	if game.state != game.State.SCORE or game.hud.modal.visible or not game.records.back().destroyed:
		push_error("Fifth-shot handoff did not settle with an unobscured retirement")
		quit(1)
		return
	await frames(7)
	await screenshot("last-hit")
	await frames(9)
	await screenshot("retirement")
	await frames(9)
	await screenshot("before-card")
	await frames(18)
	await screenshot("report")
	if not game.hud.modal.visible or game.world.targets[3].body_visual.visible or game.total_score != settled_score or game.time_left != settled_time:
		push_error("Report did not follow the retirement without changing accounting")
		quit(1)
		return
	print("HANDOFF REVIEW: ", JSON.stringify({"score": settled_score, "records": game.records, "time_held": true, "retirement_completed": true, "report_revealed": true, "ticks": ticks}))
	await frames(90)
	await keyboard(KEY_SPACE)
	await frames(180)
	await screenshot("victory")
	quit()
