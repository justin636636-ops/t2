extends "res://tests/handoff_walkthrough.gd"
## Opening, a real bell/pirate win, menu navigation, then four actual empty
## groups. Inherits the native fixed-step input helpers; never changes scores.

func shoot_point(point: Vector3) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = game.world.camera.unproject_position(point)
	review_aim = event.position
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func run() -> void:
	var window_review = "--window-review" in OS.get_cmdline_user_args()
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await frames(60)
	game.start_round()
	await frames(12)
	await screenshot("stage-opening")
	await frames(48)
	await shoot_point(game.world.bell.global_position)
	await frames(18)
	await screenshot("stage-bell")
	for i in range(5, 9):
		await shoot(i)
		if game.records.is_empty() or not game.records.back().destroyed or game.records.back().target != i:
			push_error("Stage review did not harvest its actual exposed pirate")
			quit(1)
			return
		await frames(24)
	await frames(55)
	var win_score: int = game.total_score
	var win_records: Array = game.records.duplicate(true)
	if game.state != game.State.SCORE or win_score < 1800 or win_records.size() != 5:
		push_error("Stage review did not reach its real winning report")
		quit(1)
		return
	await keyboard(KEY_SPACE)
	await frames(18)
	await screenshot("stage-prize-rising")
	await frames(90)
	await screenshot("stage-win")
	# Movie Maker keeps a constant canvas. Inspect other native window sizes
	# in a separate run so the encoded video never changes resolution midway.
	if window_review:
		root.size = Vector2i(1152, 720)
		await frames(6)
		await screenshot("stage-win-small")
		root.size = Vector2i(1920, 1080)
		await frames(6)
		await screenshot("stage-win-wide")
		root.size = Vector2i(1440, 900)
		await frames(6)
	await keyboard(KEY_TAB)
	await keyboard(KEY_ENTER)
	await frames(12)
	await screenshot("stage-end-settings")
	await keyboard(KEY_ESCAPE)
	await frames(12)
	await keyboard(KEY_ENTER)
	await frames(12)
	if game.state != game.State.READY or game.world.award_lift.visible:
		push_error("Ending keyboard navigation did not reset the actual stage")
		quit(1)
		return
	game.start_round()
	await frames(45)
	var misses: Array = []
	for group in range(4):
		for slot in range(5):
			await shoot_point(Vector3(-7.1, 5.5, -4))
			if game.records.size() != slot + 1 or game.records.back().valid:
				push_error("Four-group failure review did not record its intended real miss")
				quit(1)
				return
			misses.append(game.records.back().duplicate())
			# Respect the weapon's real 0.25-second cooldown.
			await frames(18)
		await keyboard(KEY_SPACE)
	await frames(18)
	await screenshot("stage-loss-reaction")
	await frames(84)
	await screenshot("stage-loss")
	if game.state != game.State.END or game.world.finale_won or game.total_score != 0 or game.group_index != 4 or misses.size() != 20:
		push_error("Four real empty groups did not reach the intended loss")
		quit(1)
		return
	print("STAGE REVIEW: ", JSON.stringify({"win_score": win_score, "win_records": win_records, "loss_score": game.total_score, "loss_group": game.group_index, "actual_misses": misses, "keyboard_settings_and_restart": true, "window_review": window_review, "ticks": ticks}))
	quit()
