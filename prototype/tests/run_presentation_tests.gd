extends SceneTree

var game: Node3D
var passed = 0
var failed = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if value:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func start() -> void:
	game.reset_round()
	game.start_round()
	game.toggle_pause()
	game.set_loadout(0)
	game.toggle_pause()
	await frames(4)

func shoot(index: int) -> void:
	game.cooldown = 0
	var target = game.world.targets[index]
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = game.world.camera.unproject_position(target.global_position + Vector3(0, 0, 0.24))
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func key(code: int) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func five_shots() -> void:
	await start()
	for i in range(5):
		await shoot(i)

func miss() -> void:
	game.cooldown = 0
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = game.world.camera.unproject_position(Vector3(-7.1, 5.5, -4))
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func run() -> void:
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(20)
	game.sound_on = false
	await five_shots()
	check(game.state == game.State.SCORE and game.total_score == game.last_result.score and game.records.size() == 5, "last-shot accounting completes immediately and exactly once")
	check(game.hud.score_reveal_remaining > 0 and not game.hud.modal.visible and game.hud.dim.color.a == 0, "last-shot retirement stays unobscured while the prepared report is hidden")
	check(absf(game.hud.progress.value - minf(100, game.hud.displayed_score * 100 / 1800)) < 0.01 and "Space" in game.hud.hint_label.text, "animated score and progress stay synchronized while the stage offers immediate continue")
	var target = game.world.targets[4]
	check(not target.alive and target.weak_hit.collision_layer == 0 and target.body_visual.visible, "retiring fifth target cannot be scored twice")
	var remaining: float = game.time_left
	await frames(12)
	check(target.death_age > 0.15 and not game.hud.modal.visible and is_equal_approx(remaining, game.time_left), "retirement advances while the round clock and report stay settled")
	await frames(25)
	check(game.hud.modal.visible and not target.body_visual.visible and game.hud.score_reveal_remaining == 0, "report appears after the actual retirement completes")
	check(root.gui_get_focus_owner() is Button, "revealed report gives its continue button keyboard focus")
	await five_shots()
	game.hud.mute_button.grab_focus()
	await key(KEY_SPACE)
	check(game.state == game.State.END and game.hud.score_reveal_remaining == 0, "Space skips the presentation immediately even when another widget owns focus")
	await frames(36)
	check(game.hud.modal_mode != "score", "skipped score reveal cannot replace the ending page later")
	await five_shots()
	await key(KEY_ENTER)
	check(game.state == game.State.END and game.hud.score_reveal_remaining == 0, "Enter also bypasses the last-shot presentation")
	await start()
	for i in range(4):
		await miss()
	await shoot(0)
	check(game.state == game.State.SCORE and game.total_score < 1800 and game.hud.score_reveal_remaining > 0, "a non-winning full group also keeps its last reaction visible")
	await key(KEY_SPACE)
	check(game.state == game.State.AIMING and game.group_index == 2 and game.records.is_empty() and not game.hud.overlay.visible, "immediate continue enters the next playable group without waiting")
	await frames(32)
	check(game.state == game.State.AIMING and not game.hud.overlay.visible and game.hud.score_reveal_remaining == 0, "a skipped report cannot cover the next group after its old delay")
	await five_shots()
	game.reset_round()
	await frames(36)
	check(game.state == game.State.READY and game.hud.modal_mode == "welcome" and game.hud.score_reveal_remaining == 0, "restart cancels a pending report and never resurrects it")
	await start()
	await shoot(0)
	game.settle("early")
	check(game.hud.modal.visible and game.hud.score_reveal_remaining == 0, "explicit early surrender reports immediately")
	await start()
	game.time_left = 0.001
	await frames(2)
	check(game.state == game.State.SCORE and game.hud.modal.visible and game.hud.score_reveal_remaining == 0, "timeout reports immediately without a theatrical hold")
	game.set_reduced_motion(true)
	await five_shots()
	check(game.hud.modal.visible and game.hud.score_reveal_remaining == 0, "reduced motion shows the report directly")
	game.set_reduced_motion(false)
	await start()
	var air = game.world.stage_air
	check(air.dust.multimesh.instance_count == air.MOTE_COUNT and air.get_child_count() == 3, "stage air has exactly two beam draws and one bounded mote batch")
	var initial: Transform3D = air.dust.multimesh.get_instance_transform(0)
	await frames(12)
	check(not initial.is_equal_approx(air.dust.multimesh.get_instance_transform(0)), "ambient motes drift on the world presentation clock")
	game.toggle_pause()
	var paused: Transform3D = air.dust.multimesh.get_instance_transform(0)
	var clock: float = air.beam_material.get_shader_parameter("air_clock")
	await frames(12)
	check(paused.is_equal_approx(air.dust.multimesh.get_instance_transform(0)) and is_equal_approx(clock, air.beam_material.get_shader_parameter("air_clock")), "pause freezes ambient geometry and shader time")
	game.set_reduced_motion(true)
	game.toggle_pause()
	await frames(3)
	check(not air.dust.visible and air.beam_material.get_shader_parameter("air_clock") == 0.0, "reduced motion removes drifting dust and holds the light haze static")
	game.set_reduced_motion(false)
	await five_shots()
	await key(KEY_SPACE)
	await frames(75)
	var world = game.world
	var show_ = world.stage_show
	check(game.hud.modal_mode == "ending" and game.hud.modal.position.x < 100 and game.hud.dim.color.a < 0.3, "ending card leaves the stage visible beside a shallow dim layer")
	check(not game.hud.score_label.is_visible_in_tree() and not game.hud.timer_label.is_visible_in_tree() and not world.gun.visible and world.duck.is_visible_in_tree(), "ending hides inactive combat counters and weapon while preserving the prize performer")
	check(world.award_cart.position.x > 1.2 and world.award_lift.visible and world.duck.scale.x > 1.5, "victory presents the companion on its raised physical stand")
	check(absf(world.award_lift.position.y + world.award_lift.scale.y / 2 - (world.award_plinth.position.y - 0.85)) < 0.01, "extended support reaches the authored pedestal foot instead of leaving a floating prize")
	var hero: Vector2 = world.camera.unproject_position(world.duck.global_position)
	check(hero.x > game.hud.modal.position.x + game.hud.modal.size.x + 100 and hero.y < root.size.y - 180, "the winning performer sits in the visible side of the actual camera frame")
	check(root.gui_get_focus_owner() is Button and "再营业" in root.gui_get_focus_owner().text, "the ending restart action receives keyboard focus without waiting for the performance")
	await key(KEY_TAB)
	check(root.gui_get_focus_owner() is Button and "声音" in root.gui_get_focus_owner().text, "ending Tab reaches sound and motion settings")
	await key(KEY_ENTER)
	check(game.state == game.State.END and game.hud.settings_visible and root.gui_get_focus_owner() is HSlider, "ending settings keep the settled game state and slider focus")
	await key(KEY_ESCAPE)
	check(game.hud.modal_mode == "ending" and not game.hud.settings_visible and not world.gun.visible, "returning from settings restores the clean ending layout")
	await key(KEY_ENTER)
	check(game.state == game.State.READY and world.award_cart.position.is_equal_approx(Vector3(-0.8, 1.035, 5.8)) and not world.award_lift.visible and is_equal_approx(world.duck.scale.x, 1), "keyboard restart restores the original stand, companion scale and welcome state")
	game.set_reduced_motion(true)
	await five_shots()
	await key(KEY_SPACE)
	check(world.award_cart.position.x > 1.2 and world.duck.scale.x > 1.5, "reduced motion cuts directly to the completed prize composition")
	await frames(4)
	var reduced_levels: Array = show_.levels.duplicate()
	await frames(12)
	check(show_.levels == reduced_levels, "reduced motion holds the winning practical lights static")
	game.set_reduced_motion(false)
	await start()
	check(show_.bulbs.multimesh.instance_count == 29 and show_.wires.multimesh.instance_count == 29 and show_.get_child_count() == 2 and show_.find_children("*", "CollisionObject3D", true, false).is_empty(), "practical lamps and cords remain two bounded cosmetic batches with no colliders")
	var bell_shot = InputEventMouseButton.new()
	bell_shot.button_index = MOUSE_BUTTON_LEFT
	bell_shot.position = world.camera.unproject_position(world.bell.global_position)
	bell_shot.pressed = true
	Input.parse_input_event(bell_shot)
	bell_shot = bell_shot.duplicate()
	bell_shot.pressed = false
	Input.parse_input_event(bell_shot)
	await frames(3)
	check(game.records.back().valid and "机关" in game.records.back().display and show_.bell_age < 0.2, "a real valid bell shot triggers the practical response without changing its score")
	await key(KEY_TAB)
	var frozen_levels: Array = show_.levels.duplicate()
	var frozen_age: float = show_.bell_age
	await frames(12)
	check(game.state == game.State.PAUSED and show_.levels == frozen_levels and is_equal_approx(show_.bell_age, frozen_age), "real pause freezes practical intensity and the bell response clock")
	await key(KEY_ESCAPE)
	await frames(80)
	check(show_.levels.all(func(value): return absf(value - 0.9) < 0.001), "after the bell response expires the stage returns to steady shooting illumination")
	game.time_left = 0.001
	await frames(2)
	await key(KEY_SPACE)
	await frames(75)
	check(game.state == game.State.END and not world.finale_won and not world.award_lift.visible and is_equal_approx(world.duck.scale.x, 1) and world.award_cart.position.x > 0.8, "timeout uses a quieter side composition without the winning lift or enlargement")
	await RenderingServer.frame_post_draw
	var loss_image: Image = root.get_texture().get_image()
	# Sample bare lacquer below the eye, using the actual animated mesh transform.
	# The previous upper-face point could land on the intentionally dark eye rim.
	var cheek: Vector2 = world.camera.unproject_position(world.targets[2].body_visual.to_global(Vector3(0.34, -0.15, 0.20)))
	var face_luminance = 0.0
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var face_color = loss_image.get_pixel(int(cheek.x) + dx, int(cheek.y) + dy)
			face_luminance += (face_color.r * 0.2126 + face_color.g * 0.7152 + face_color.b * 0.0722) / 25.0
	loss_image.save_png(ProjectSettings.globalize_path("res://artifacts/v22-presentation-loss.png"))
	print("LOSS FACE SAMPLE: ", JSON.stringify({"point": [cheek.x, cheek.y], "luminance": face_luminance, "alive": world.targets[2].alive}))
	check(show_.levels.all(func(value): return value > 0.5) and face_luminance > 0.2, "native loss frame keeps the actual exposed face readable instead of blacking out the stage")
	game.queue_free()
	await process_frame
	print("PRESENTATION RESULT: ", passed, " passed; ", failed, " failed")
	quit(1 if failed else 0)
