extends SceneTree
## Real input and collisions; one 1/60 gameplay update per drawn native frame.
## No outcome, collider, cooldown, or score overrides.

var game: Node3D
var review_aim = Vector2(720, 450)
var passed = 0
var failed = 0
var outcomes: Array = []
var window_review = false

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
		game.aim = review_aim
		game._physics_process(1.0 / 60.0)
		game._process(1.0 / 60.0)
		await RenderingServer.frame_post_draw

func keyboard(code: int) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func shoot(pos: Vector3) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = game.world.camera.unproject_position(pos)
	review_aim = event.position
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)
	var record: Dictionary = game.records.back().duplicate(true)
	record["feedback_mode"] = game.hud.shot_feedback.mode
	outcomes.append(record)

func screenshot(name_: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v22-feedback-" + name_ + ".png"))

func begin(preset: int) -> void:
	game.reset_round()
	game.start_round()
	await keyboard(KEY_TAB)
	game.set_loadout(preset)
	await keyboard(KEY_ESCAPE)
	await frames(75)

func fan_count() -> int:
	for effect in game.world.vfx.effects:
		if effect.kind == "sparks":
			return effect.node.multimesh.instance_count
	return 0

func run() -> void:
	window_review = "--window-review" in OS.get_cmdline_user_args()
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await frames(60)
	await begin(1)
	var target = game.world.targets[2]
	var camera_transform: Transform3D = game.world.camera.global_transform
	await shoot(target.global_position + Vector3(0, 0, 0.24))
	check(game.records.back().valid and not game.records.back().destroyed and game.hud.shot_feedback.mode == "prepare", "real spring preparation uses the upward mark")
	screenshot("prepare")
	await frames(22)
	await shoot(target.global_position + Vector3(0, 0, 0.24))
	check(game.records.back().destroyed and game.records.back().weak and game.records.back().air and game.records.back().relay and game.hud.shot_feedback.mode == "precision", "real aerial relay uses the segmented precision mark")
	check(fan_count() == 8, "precision hit has eight thin spokes in one cosmetic batch")
	check(game.sound_players.any(func(player): return player.stream == game.audio_cache.precision and player.playing and is_equal_approx(player.pitch_scale, 1)), "real weakpoint hit plays the authored precision chime at its fixed pitch")
	await frames(3)
	screenshot("precision")
	check(game.hud.toast_panel.is_visible_in_tree() and game.hud.toast_panel.get_global_rect().position.y > 699 and game.hud.toast_panel.get_global_rect().end.y < 749, "actual relay plaque stays below the aim area and above the ammunition")
	check(game.hud.toast_label.get_theme_font("font").get_string_size(game.hud.toast_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x <= game.hud.toast_label.size.x, "actual relay text fits its plaque")
	if window_review:
		await keyboard(KEY_TAB)
		for size_ in [Vector2i(1152, 720), Vector2i(1920, 1080)]:
			root.size = size_
			await frames(10)
			screenshot("pause-" + str(size_.x))
		root.size = Vector2i(1440, 900)
		await frames(10)
		await keyboard(KEY_ESCAPE)
	await keyboard(KEY_TAB)
	var feedback_age: float = game.hud.shot_feedback.age
	var toast_time: float = game.hud.toast_time
	var pulse: float = game.hud.slot_pulses[1]
	var card_scale: Vector2 = game.hud.slots[1].panel.scale
	var reload_age: float = game.hud.reload_age
	await frames(12)
	check(game.state == game.State.PAUSED and is_equal_approx(feedback_age, game.hud.shot_feedback.age) and is_equal_approx(toast_time, game.hud.toast_time) and is_equal_approx(pulse, game.hud.slot_pulses[1]) and game.hud.slots[1].panel.scale.is_equal_approx(card_scale) and is_equal_approx(reload_age, game.hud.reload_age), "real pause freezes hit mark, relay plaque, ticket pulse and reload clock")
	await keyboard(KEY_ESCAPE)
	await frames(18)
	check(game.hud.shot_feedback.age > feedback_age and game.hud.toast_time < toast_time and game.hud.slots[1].panel.scale.is_equal_approx(Vector2.ONE), "resume advances feedback and settles the ammunition ticket")
	check(game.world.camera.global_transform.is_equal_approx(camera_transform), "shooting response keeps the camera transform stable")
	await frames(75)
	await begin(1)
	check(game.hud.toast_time == 0 and game.hud.shot_feedback.age >= 1 and game.hud.slot_pulses.all(func(value): return value == 0), "restart clears prior hit feedback and relay plaque")
	var pirate = game.world.targets[5]
	await shoot(pirate.global_position + Vector3(0, 0, 0.45))
	check(not game.records.back().valid and not pirate.shield_broken and game.hud.shot_feedback.mode == "blocked", "a shield-blocked spring uses closed brackets without granting a hit")
	await frames(3)
	screenshot("blocked")
	await frames(22)
	await shoot(pirate.global_position + Vector3(0, 0, 0.45))
	check(game.records.back().valid and not game.records.back().destroyed and pirate.shield_broken and game.hud.shot_feedback.mode == "shield" and fan_count() == 6, "real shield break uses broken edges and six warm metal spokes")
	check(game.hud.toast_time == 0 and not game.hud.toast_panel.visible, "a subsequent valid shield hit clears the obsolete blocked-shot warning")
	await frames(3)
	screenshot("shield")
	await frames(24)
	await shoot(game.world.targets[1].global_position + Vector3(0.44, 0, 0.24))
	check(game.records.back().destroyed and not game.records.back().weak and game.hud.shot_feedback.mode == "body" and fan_count() == 4, "real body kill uses the plain hit mark and four cream spokes")
	await frames(3)
	screenshot("body")
	await frames(24)
	await shoot(Vector3(-7.1, 5.5, -4))
	check(not game.records.back().valid and game.hud.shot_feedback.mode == "miss", "real miss uses quiet horizontal strokes")
	screenshot("miss")
	await frames(70)
	await begin(1)
	await shoot(game.world.bell.global_position)
	check(game.records.back().valid and game.records.back().target == -1 and game.hud.shot_feedback.mode == "mechanism" and not game.hud.shot_feedback.spring, "spring ammunition hitting the bell uses the mechanism mark rather than a preparation arrow")
	await frames(3)
	screenshot("mechanism")
	await frames(24)
	await shoot(game.world.bell.global_position)
	check(not game.records.back().valid and game.records.back().display == "未响应" and game.hud.shot_feedback.mode == "blocked", "a cooling bell uses the blocked mark rather than confirming a hit")
	await frames(3)
	screenshot("cooldown")
	await frames(70)
	await begin(0)
	game.set_reduced_motion(true)
	await shoot(game.world.targets[0].global_position + Vector3(0, 0, 0.24))
	check(game.records.back().weak and game.hud.shot_feedback.mode == "precision" and game.hud.shot_feedback.reduced_motion and fan_count() == 0 and game.hud.slots[0].panel.scale.is_equal_approx(Vector2.ONE), "reduced motion keeps truthful precision feedback without spokes or ticket pulse")
	screenshot("reduced")
	await frames(65)
	game.reset_round()
	game.start_round()
	await keyboard(KEY_TAB)
	check(game.hud.slots.all(func(slot): return slot.panel.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(slot.panel.modulate.a, 1)), "reduced motion reload presents five fully visible tickets immediately")
	await frames(40)
	print("FEEDBACK REVIEW: ", JSON.stringify({"outcomes": outcomes, "window_review": window_review, "passed": passed, "failed": failed, "camera_stable": game.world.camera.global_transform.is_equal_approx(camera_transform)}))
	print("FEEDBACK RESULT: ", passed, " passed; ", failed, " failed")
	# Let the last score cue finish, then drain Movie Maker's audio playback.
	# Quitting with an active WAV leaves its playback retained by the mixer.
	await frames(24)
	for player in game.sound_players:
		player.stop()
		player.stream = null
	await frames(3)
	quit.call_deferred(1 if failed else 0)
