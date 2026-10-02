extends SceneTree

var game: Node3D

func _initialize() -> void:
	run.call_deferred()

func sample(name_: String, seconds: float, fire: bool, cycle: bool = false) -> void:
	var times: Array[float] = []
	var end_at = Time.get_ticks_usec() + int(seconds * 1000000)
	var last = Time.get_ticks_usec()
	var next_shot = last + 100000
	var shots = 0
	var max_draws = 0
	var max_process_ms = 0.0
	var max_physics_ms = 0.0
	var spikes: Array = []
	while Time.get_ticks_usec() < end_at:
		await process_frame
		var now = Time.get_ticks_usec()
		var frame_ms = float(now - last) / 1000
		times.append(frame_ms)
		if frame_ms > 16.7:
			spikes.append({"frame_ms": frame_ms, "recorded_shots": game.records.size()})
		last = now
		max_draws = maxi(max_draws, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		max_process_ms = maxf(max_process_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
		max_physics_ms = maxf(max_physics_ms, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000)
		if cycle and game.state == game.State.SCORE:
			game.continue_group()
		if cycle and game.state == game.State.END:
			game.reset_round()
			game.start_round()
			game.toggle_pause()
			game.set_loadout(0)
			game.toggle_pause()
		if fire and now >= next_shot and (shots < 5 or cycle) and game.state == game.State.AIMING:
			var target = game.world.targets[game.records.size() if cycle else shots]
			var event = InputEventMouseButton.new()
			event.position = game.world.camera.unproject_position(target.global_position + Vector3(0, 0, 0.24))
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = true
			Input.parse_input_event(event)
			event = event.duplicate()
			event.pressed = false
			Input.parse_input_event(event)
			shots += 1
			next_shot = now + 290000
	var total = 0.0
	for value in times:
		total += value
	times.sort()
	var result = {"phase": name_, "frames": times.size(), "mean_ms": total / times.size(), "p95_ms": times[int(times.size() * 0.95)], "max_ms": times.back(), "max_draw_calls": max_draws, "max_process_ms": max_process_ms, "max_physics_ms": max_physics_ms, "shots_recorded": game.records.size(), "shots_sent": shots, "cycles_enabled": cycle, "spikes_over_16_7_ms": spikes}
	print("PERFORMANCE_REVIEW: ", JSON.stringify(result))

func run() -> void:
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound_on = false
	print("DISPLAY_REVIEW: ", JSON.stringify({"hz": DisplayServer.screen_get_refresh_rate(), "vsync": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps}))
	for i in range(120):
		await process_frame
	game.start_round()
	game.toggle_pause()
	game.set_loadout(0)
	game.toggle_pause()
	await sample("idle-moving-stage", 2.0, false)
	await sample("five-real-shots-and-retreats", 2.0, true)
	await sample("score-ticket-ink-and-rest", 2.0, false)
	if "--long-review" in OS.get_cmdline_user_args():
		game.reset_round()
		game.start_round()
		game.toggle_pause()
		game.set_loadout(0)
		game.toggle_pause()
		await sample("30-second-real-shot-restart-session", 30.0, true, true)
	print("PERFORMANCE_SCOPE: Apple M5, Metal Forward+, 1440x900; local sample, not minimum hardware certification")
	quit()
