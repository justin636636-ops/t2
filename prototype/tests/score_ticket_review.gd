extends "res://tests/feedback_walkthrough.gd"
## Real shots, cooldown, R surrender, keyboard continuation and native layouts.

func screenshot(name_: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v22-ticket-" + name_ + ".png"))

func ticket_fits() -> bool:
	var ticket = game.hud.score_ticket
	var valid = root.get_visible_rect().encloses(game.hud.modal.get_global_rect())
	for row in ticket.rows:
		for label in row.labels:
			var width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
			valid = valid and width <= label.size.x and ticket.get_global_rect().encloses(label.get_global_rect())
	return valid

func run() -> void:
	window_review = "--window-review" in OS.get_cmdline_user_args()
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await frames(30)
	await begin(0)
	for i in range(5):
		await shoot(game.world.targets[i].global_position + Vector3(0, 0, 0.24))
		if i < 4:
			await frames(18)
	var total: int = game.total_score
	var ticket = game.hud.score_ticket
	check(game.state == game.State.SCORE and total == 3780 and total == game.last_result.score, "five actual weakpoint shots account the full 3780 score before the receipt animation")
	check(not game.hud.modal.visible and ticket.age == 0 and ticket.score.text == str(total), "retirement remains unobscured and the prepared receipt already holds the truthful final number")
	await frames(10)
	screenshot("retirement")
	await frames(30)
	check(game.hud.modal.visible and ticket.stamped_count > 0 and ticket.stamped_count < 5, "receipt ink sequence begins only after the fifth target's physical retirement")
	screenshot("first-ink")
	var settled_time: float = game.time_left
	await frames(70)
	check(ticket.completed and ticket.stamped_count == 5 and ticket.result.steps == game.last_result.steps and game.total_score == total and game.time_left == settled_time, "five ink marks preserve the ordered Rules steps without changing score or the settled round clock")
	check(ticket.rows[4].labels[1].text == "×1.5" and ticket.rows[4].labels[2].text == "280 × 13.5", "the final smile stamp shows multiplication after the metronome addition")
	check(ticket_fits() and root.gui_get_focus_owner() is Button, "receipt fields fit the native card and continue has keyboard focus")
	screenshot("full")
	if window_review:
		for size_ in [Vector2i(1152, 720), Vector2i(1920, 1080)]:
			root.size = size_
			await frames(12)
			check(ticket_fits() and ticket.completed, "settled receipt fits native window " + str(size_.x) + " without replaying its ink")
			screenshot("full-" + str(size_.x))
		root.size = Vector2i(1440, 900)
		await frames(12)
	await keyboard(KEY_ENTER)
	check(game.state == game.State.END and game.hud.score_ticket == null, "Enter leaves a completed receipt and retires its presentation owner")
	await frames(35)
	await begin(0)
	await shoot(game.world.targets[0].global_position + Vector3(0, 0, 0.24))
	await frames(18)
	var r = InputEventKey.new()
	r.physical_keycode = KEY_R
	r.keycode = KEY_R
	r.pressed = true
	Input.parse_input_event(r)
	await frames(24)
	r = r.duplicate()
	r.pressed = false
	Input.parse_input_event(r)
	await frames(2)
	ticket = game.hud.score_ticket
	check(game.state == game.State.SCORE and game.duck_energy == 4 and game.hud.modal.visible, "real held R creates the early surrender receipt and grants four actual unspent rounds of growth")
	check(ticket.result.score == game.last_result.score and ticket.rows[3].labels[1].text == "未触发" and ticket.rows[4].labels[1].text == "未触发", "early surrender retains inactive equipment as explicit untriggered entries")
	await frames(58)
	screenshot("early")
	await keyboard(KEY_SPACE)
	check(game.state == game.State.AIMING and game.group_index == 2 and game.hud.score_ticket == null and not game.hud.overlay.visible, "Space loads the next real group without stale paper covering the stage")
	await frames(20)
	# Skip a new receipt during its ink sequence, rather than only before reveal.
	for i in range(5):
		await shoot(Vector3(-7.1, 5.5, -4))
		if i < 4:
			await frames(18)
	await frames(12)
	ticket = game.hud.score_ticket
	check(ticket.score.text == "0" and ticket.rows[1].labels[1].text == "无追加" and not ticket.completed, "five real misses display zero and no extra performance while stamping")
	screenshot("empty-stamping")
	await keyboard(KEY_SPACE)
	await frames(75)
	check(game.state == game.State.AIMING and game.group_index == 3 and game.hud.score_ticket == null and not game.hud.overlay.visible, "skipping active ink cannot resurrect an old receipt or duplicate its score")
	game.time_left = 0.001
	await frames(2)
	check(game.state == game.State.SCORE and game.hud.modal.visible and game.hud.score_ticket.score.text == "0", "timeout with no shots has a truthful immediate zero receipt")
	await frames(65)
	screenshot("timeout")
	game.reset_round()
	check(game.hud.score_ticket == null and game.hud.modal_mode == "welcome", "restart cancels the receipt owner as well as its pending ink")
	game.set_reduced_motion(true)
	await begin(0)
	for i in range(5):
		await shoot(game.world.targets[i].global_position + Vector3(0, 0, 0.24))
		if i < 4:
			await frames(18)
	ticket = game.hud.score_ticket
	check(game.hud.modal.visible and ticket.completed and ticket.stamped_count == 5 and ticket.seal.scale.is_equal_approx(Vector2.ONE), "reduced motion exposes every exact number and the final seal immediately")
	await frames(8)
	var age: float = ticket.age
	await frames(12)
	check(ticket.age == age and ticket.rows.all(func(row): return row.node.scale.is_equal_approx(Vector2.ONE)), "reduced receipt remains static without repeated stamping or row scaling")
	screenshot("reduced")
	game.set_reduced_motion(false)
	print("TICKET REVIEW: ", JSON.stringify({"passed": passed, "failed": failed, "real_outcomes": outcomes, "full_score": total, "window_review": window_review}))
	await frames(24)
	for player in game.sound_players:
		player.stop()
		player.stream = null
	await frames(3)
	quit.call_deferred(1 if failed else 0)
