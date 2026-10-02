extends "res://tests/feedback_walkthrough.gd"
## Actual archived HUD/ticket and current cache under the same native game/clock.
var baseline = false
var images = {}
var comparisons: Array = []
func snapshot(name_: String) -> void:
	var image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://artifacts/v18-" + ("before-" if baseline else "after-") + "modal-" + name_ + ".png"))
	var rect: Rect2 = game.hud.modal.get_global_rect()
	if baseline:
		images[name_] = {"image":image,"rect":rect}
	else:
		var old: Dictionary = images[name_]
		var difference = 0.0
		var changed = 0
		for y in range(int(rect.position.y),int(rect.end.y)):
			for x in range(int(rect.position.x),int(rect.end.x)):
				var a = image.get_pixel(x,y)
				var b = old.image.get_pixel(x,y)
				var delta = maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
				difference = maxf(difference,delta)
				if delta > 1.0/255.0 + .000001:changed += 1
		comparisons.append({"state":name_,"same_panel_rect":rect.is_equal_approx(old.rect),"max_channel_difference":difference,"pixels_changed_over_one_code_value":changed,"panel_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
func make_game(before: bool) -> void:
	baseline = before
	review_aim = Vector2(720,450)
	var source = FileAccess.get_file_as_string("res://scripts/game.gd")
	var original = 'const Hud = preload("res://scripts/hud.gd")'
	if before:
		if not source.contains(original):
			push_error("Archived UI comparison cannot match current game HUD factory")
			quit(1)
			return
		source = source.replace(original,'const Hud = preload("res://../.art_archive/2026-10-02-v18/hud_legacy_art.gd")')
	var script = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		push_error("UI comparison could not compile the actual game")
		quit(1)
		return
	game = script.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound_on = false
	await frames(45)
func walk() -> void:
	snapshot("welcome")
	game.hud.show_tutorial()
	await frames(30)
	snapshot("tutorial")
	game.hud.show_settings(game.hud.show_tutorial)
	await frames(30)
	snapshot("settings")
	game.hud.close_settings()
	await begin(0)
	await keyboard(KEY_TAB)
	await frames(30)
	snapshot("configure")
	await keyboard(KEY_ESCAPE)
	await shoot(game.world.bell.global_position)
	await frames(22)
	await keyboard(KEY_TAB)
	await frames(30)
	snapshot("pause")
	await keyboard(KEY_ESCAPE)
	for i in range(5,9):
		await shoot(game.world.targets[i].weak_hit.global_position)
		if i<8:await frames(22)
	await frames(120)
	check(game.total_score==4605 and game.hud.score_ticket.completed,"art comparison uses actual settled 4605 and completed ink, baseline="+str(baseline))
	snapshot("score")
	await keyboard(KEY_ENTER)
	await frames(110)
	snapshot("win")
	game.hud.show_settings(func():game.hud.show_end(true))
	await frames(30)
	game.hud.close_settings()
	await frames(30)
	snapshot("win-return")
	await begin(0)
	for group in range(1,5):
		for i in range(5):
			await shoot(Vector3(-7.1,5.5,-4))
			if i<4:await frames(18)
		await frames(30)
		await keyboard(KEY_SPACE)
		if group<4:await frames(20)
	await frames(110)
	check(game.total_score==0 and game.state==game.State.END,"art comparison uses actual four-group zero-score failure, baseline="+str(baseline))
	snapshot("loss")
	for player in game.sound_players:
		player.stop()
		player.stream=null
	game.free()
	await process_frame
func run() -> void:
	root.size=Vector2i(1440,900)
	await make_game(true)
	await walk()
	await make_game(false)
	await walk()
	print("MODAL ART REVIEW: ",JSON.stringify({"actual_archived_hud_and_ticket":true,"same_game_world_models_fonts_shaders":true,"native_panel_comparisons":comparisons,"actual_score":4605,"actual_loss":0,"passed":passed,"failed":failed,"scope":"Native fixed 1/60 actual game updates, actual input/cooldown/accounting. Legacy HUD adapter only redirects original ticket preload to its backup. Nine settled UI states; max difference includes underlying partially transparent stage pixels, not human readability or all animation phases."}))
	if failed>0 or comparisons.any(func(v):return not v.same_panel_rect or v.max_channel_difference>.02):
		push_error("Retained UI changed the compared native panel layout or appearance")
		quit(1)
	else:quit()
