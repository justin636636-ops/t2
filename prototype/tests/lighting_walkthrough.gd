extends "res://tests/feedback_walkthrough.gd"
## Real input and unchanged accounting across four visual acts and actual endings.
var real_groups: Array = []
var group_tints: Array = []
func screenshot(name_: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v22-lighting-" + name_ + ".png"))
func look() -> Dictionary:
	var lighting = game.world.stage_lighting
	var material = game.world.stage_backdrop.painted_materials[0]
	return {"tint":lighting.look_tint, "gain":lighting.cue_gain, "clock":lighting.clock, "bell_age":lighting.bell_age, "bell_energy":lighting.bell.light_energy, "lens":lighting.lens_material.get_shader_parameter("power"), "sea_clock":material.get_shader_parameter("sea_clock"), "sea_motion":material.get_shader_parameter("sea_motion"), "rim":lighting.rim.light_energy, "fill":lighting.fill.light_energy}
func run() -> void:
	window_review = "--window-review" in OS.get_cmdline_user_args()
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await frames(30)
	game.start_round()
	game.toggle_pause()
	game.set_loadout(0)
	game.toggle_pause()
	var world = game.world
	var lighting = world.stage_lighting
	var camera_pose: Transform3D = world.camera.global_transform
	check(lighting.pieces.size() == 3 and lighting.find_children("*", "Light3D", true, false).is_empty() and lighting.find_children("*", "CollisionObject3D", true, false).is_empty(), "two authored theatre fixtures are three static batches without extra lights or colliders")
	await frames(18)
	check(lighting.mode == "opening" and lighting.cue_gain > 0.76 and lighting.cue_gain < 1 and is_equal_approx(world.stage_key.light_energy, 6.2), "opening raises backstage illumination while front key stays immediately playable")
	screenshot("opening")
	await keyboard(KEY_TAB)
	var frozen = look()
	await frames(20)
	check(look() == frozen, "real pause freezes existing lamp energies, lens and painted water time together")
	await keyboard(KEY_ESCAPE)
	await frames(65)
	check(is_equal_approx(lighting.cue_gain, 1) and is_equal_approx(lighting.fill.light_energy, 1.25), "opening settles without a continuing shooting-light pulse")
	var initial_fill: Color = lighting.fill.light_color
	for group in range(1, 5):
		await frames(60)
		check(game.group_index == group and lighting.group_number == group and lighting.look_tint.is_equal_approx(lighting.CAST_COLORS[group - 1]) and lighting.fill.light_color == initial_fill, "actual group " + str(group) + " reaches its authored backdrop tint with steady face fill")
		group_tints.append(lighting.look_tint.to_html(false))
		screenshot("group-" + str(group))
		await shoot(world.targets[group - 1].weak_hit.global_position)
		await keyboard(KEY_R) # short press must not submit
		check(game.state == game.State.AIMING and game.records.size() == 1, "a short real R press in group " + str(group) + " cannot substitute a visual transition for settlement")
		var event = InputEventKey.new()
		event.keycode = KEY_R
		event.physical_keycode = KEY_R
		event.pressed = true
		Input.parse_input_event(event)
		await frames(26)
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
		await frames(30)
		real_groups.append({"group":game.group_index, "score":game.last_result.score, "energy":game.duck_energy, "record":game.records[0].duplicate(true)})
		check(game.state == game.State.SCORE and game.records.size() == 1 and game.records[0].weak and game.records[0].destroyed and game.total_score < 1800, "actual weakpoint and held R settle one real low-score group without any score overrides")
		await keyboard(KEY_SPACE)
		if group < 4:
			await frames(16)
			screenshot("group-transition-" + str(group + 1))
			check(lighting.group_age < 0.85 and lighting.look_tint != lighting.CAST_COLORS[group], "real continue gives one short colour handoff without delaying the next playable group")
	await frames(80)
	check(game.state == game.State.END and not world.finale_won and lighting.mode == "loss" and lighting.cue_gain >= 0.80 and world.stage_key.light_energy > 5.0, "real four-group failure settles into a quiet blue set while faces retain their key")
	screenshot("loss")
	await begin(0)
	await shoot(world.bell.global_position)
	await frames(8)
	check(lighting.bell_age < 0.2 and lighting.bell.light_energy > 1.5 and game.records.back().base == 5, "a real valid five-point bell gives its own short existing-lamp response")
	screenshot("bell")
	await keyboard(KEY_TAB)
	frozen = look()
	await frames(18)
	check(look() == frozen, "pause freezes a live bell cue without touching its real exposure")
	await keyboard(KEY_ESCAPE)
	await frames(33)
	check(is_equal_approx(lighting.bell.light_energy, 1.5), "the bell light returns to its steady level after a single bounded response")
	for index in range(5, 9):
		await shoot(world.targets[index].weak_hit.global_position)
		if index < 8:await frames(22)
	await frames(70)
	await keyboard(KEY_SPACE)
	await frames(85)
	var real_win_score: int = game.total_score
	check(game.state == game.State.END and world.finale_won and real_win_score == 4605 and lighting.mode == "win", "actual bell and four pirate weakpoints keep the 4605 victory under the new show")
	screenshot("win")
	var resting = look()
	await frames(50)
	var after_rest = look()
	check(resting.tint == after_rest.tint and is_equal_approx(resting.gain, after_rest.gain) and is_equal_approx(resting.lens, after_rest.lens), "victory lights settle to one steady composition after their short handoff")
	game.set_reduced_motion(true)
	await begin(0)
	var reduced_start = look()
	await frames(18)
	var reduced_after = look()
	check(reduced_start.gain == 1 and reduced_start.sea_clock == 0 and reduced_start.sea_motion == 0 and reduced_after.sea_clock == 0, "reduced motion cuts opening to a stable look and fixes painted water")
	await shoot(world.bell.global_position)
	await frames(12)
	check(lighting.bell.light_energy == 1.5 and game.records.back().base == 5, "reduced motion suppresses lamp pulses and preserves the actual bell mechanism")
	await frames(10)
	for index in range(5, 9):
		await shoot(world.targets[index].weak_hit.global_position)
		if index < 8:await frames(22)
	await keyboard(KEY_SPACE)
	check(game.state == game.State.END and lighting.mode == "win" and is_equal_approx(lighting.cue_gain, 1.12) and lighting.look_tint.is_equal_approx(Color("bbab8c")), "reduced actual victory immediately applies its final steady lighting")
	screenshot("reduced-win")
	game.reset_round()
	check(lighting.mode == "idle" and lighting.group_number == 1 and lighting.clock == 0 and is_equal_approx(lighting.cue_gain, 1) and lighting.bell_age == 1, "restart clears all previous show phases and returns the actual lamps to the first look")
	game.set_reduced_motion(false)
	game.start_round()
	await frames(80)
	if window_review:
		for size_ in [Vector2i(1152, 720), Vector2i(1920, 1080)]:
			root.size = size_
			await frames(12)
			var inside = true
			for side in [-1, 1]:
				var point = world.camera.unproject_position(Vector3(side * 6.9, 6.24, -3.96))
				inside = inside and root.get_visible_rect().has_point(point) and point.y > 130
			check(inside, "actual theatre fixtures stay in the stage under top counters at native width " + str(size_.x))
			screenshot("window-" + str(size_.x))
		root.size = Vector2i(1440, 900)
		await frames(8)
	check(camera_pose.is_equal_approx(world.camera.global_transform), "opening, all four groups, real endings and resets leave the aiming camera unchanged")
	print("LIGHTING REVIEW: ", JSON.stringify({"passed":passed, "failed":failed, "window_review":window_review, "real_groups":real_groups, "group_tints":group_tints, "actual_outcomes":outcomes, "real_win_score":real_win_score, "camera_stable":camera_pose.is_equal_approx(world.camera.global_transform), "fixture_batches":lighting.pieces.size(), "dynamic_lights_added":lighting.find_children("*", "Light3D", true, false).size()}))
	await frames(24)
	for player in game.sound_players:
		player.stop()
		player.stream = null
	await frames(3)
	quit.call_deferred(1 if failed else 0)
