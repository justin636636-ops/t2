extends "res://tests/crew_performance_review.gd"
func run() -> void:
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.sound_on = false
	print("DISPLAY_REVIEW: ",JSON.stringify({"hz":DisplayServer.screen_get_refresh_rate(),"vsync":DisplayServer.window_get_vsync_mode(),"max_fps":Engine.max_fps}))
	for i in range(120):await process_frame
	fresh_round()
	await crew_session(30.0)
	if not session_valid:return
	print("BELL_PERF_SCOPE: Normal native auto process/physics, actual raised bell and four weakpoints. Audio off; no other owned native task/capture/encoder, external environment not isolated. Skips receipts/endings for loop. Process intervals not physical FPS or GPU times; short sample not a fair historical comparison or hardware certification.")
	quit()
