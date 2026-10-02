extends "res://tests/crew_performance_review.gd"
## Method wall-time diagnostic in the unchanged actual game, no outcome overrides.
var reset_cpu: Array = []
func fresh_round() -> void:
	var began = Time.get_ticks_usec()
	if "--user-restart-review" in OS.get_cmdline_user_args():
		game.reset_round()
		game.start_round()
	else:
		super.fresh_round()
	reset_cpu.append(float(Time.get_ticks_usec() - began) / 1000.0)
func stats(values: Array) -> Dictionary:
	var sorted = values.duplicate()
	sorted.sort()
	var total = 0.0
	for value in values:total += value
	return {"samples":values.size(), "mean_ms":total/values.size(), "p95_ms":sorted[int(sorted.size()*.95)], "max_ms":sorted.back()}
func run() -> void:
	root.size = Vector2i(1440, 900)
	var source = FileAccess.get_file_as_string("res://scripts/game.gd")
	var world_const = 'const World = preload("res://scripts/world.gd")'
	var hud_const = 'const Hud = preload("res://scripts/hud.gd")'
	if not source.contains(world_const) or not source.contains(hud_const):
		push_error("Profiling adapter could not match exact original game factories")
		quit(1)
		return
	var script = GDScript.new()
	var hud_path = "res://../.art_archive/2026-10-02-v18/reset_profile_hud_legacy.gd" if "--baseline" in OS.get_cmdline_user_args() else "res://tests/reset_profile_hud.gd"
	script.source_code = source.replace(world_const, 'const World = preload("res://tests/reset_profile_world.gd")').replace(hud_const, 'const Hud = preload("' + hud_path + '")')
	if script.reload() != OK:
		push_error("Profiling game could not compile")
		quit(1)
		return
	game = script.new()
	root.add_child(game)
	game.sound_on = false
	for i in range(120):await process_frame
	game.start_round()
	game.toggle_pause()
	game.set_loadout(0)
	game.toggle_pause()
	for i in range(30):await process_frame
	game.world.reset_cpu.clear()
	game.hud.modal_cpu.clear()
	await crew_session(30.0)
	if not session_valid:return
	var modal = {}
	for kind in game.hud.modal_cpu:modal[kind] = stats(game.hud.modal_cpu[kind])
	print("RESET CPU PROFILE: ", JSON.stringify({"archived_hud_and_ticket":"--baseline" in OS.get_cmdline_user_args(), "restart_flow":"reset_start" if "--user-restart-review" in OS.get_cmdline_user_args() else "reset_start_two_config_builds", "reset_world":stats(game.world.reset_cpu), "fresh_round_including_start_pause_config":stats(reset_cpu), "modal_inclusive_method_times":modal, "scope":"Native normal auto physics/process, method wall-times from exact current game with two preload adapters and super-call timers. Nested modal times overlap; deferred layout, free and GPU work excluded. Audio off, no other owned native task; external environment not isolated, not physical FPS. Paired flow flags must match; setup config precedes sampling."}))
	quit()
