extends "res://tests/feedback_walkthrough.gd"
## Real raised mechanism input, cooldown, connected pivots and bounded performance.
func screenshot(name_: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v22-bell-" + name_ + ".png"))
func pose() -> Dictionary:
	var art = game.world.bell_mesh
	return {"age":art.age,"swing":art.swing.transform,"clapper":art.clapper.transform}
func harvest() -> void:
	await shoot(game.world.bell.global_position)
	await frames(20)
	for i in range(5,9):
		await shoot(game.world.targets[i].weak_hit.global_position)
		if i < 8:await frames(20)
func run() -> void:
	window_review = "--window-review" in OS.get_cmdline_user_args()
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await frames(30)
	await begin(0)
	var world = game.world
	var art = world.bell_mesh
	var original_camera: Transform3D = world.camera.global_transform
	check(world.bell.position.is_equal_approx(Vector3(6.9,4.35,-5)) and world.bell.get_child(0).shape.size == Vector3(0.9,1.1,0.65), "raised real mechanism keeps the original hit volume dimensions")
	check(art.pieces.size() == 7 and art.find_children("*","CollisionObject3D",true,false).is_empty() and art.find_children("*","Light3D",true,false).is_empty(), "authored bell is seven opaque batches without additional collision or light")
	check(art.swing.position.is_equal_approx(art.PIVOT) and art.clapper.get_parent() == art.swing and art.swing.get_parent() == art, "bell crown and independent clapper share the connected authored parent chain")
	check(art.age == 1 and art.swing.rotation.is_zero_approx() and art.clapper.rotation.is_zero_approx(), "untriggered bell rests instead of continuously swinging")
	screenshot("ready")
	await shoot(world.bell.global_position)
	check(game.records.size() == 1 and game.records[0].valid and game.records[0].base == 5 and game.records[0].target == -1, "real mouse click hits the raised copper bell and records its existing five points")
	check(world.targets.slice(5).all(func(t):return t.exposed > 0 and t.preparation_shot == 0), "the actual bell still opens four real covers with the triggering shot evidence")
	await frames(5)
	check(absf(art.swing.rotation.z) > 0.01 and absf(art.clapper.rotation.z) > 0.01 and art.swing.rotation.z * art.clapper.rotation.z < 0, "a valid trigger gives one opposite crown and clapper movement")
	screenshot("ringing")
	await keyboard(KEY_TAB)
	var frozen = pose()
	await frames(20)
	check(pose() == frozen, "actual pause freezes both hinge transforms and the bell age")
	await keyboard(KEY_ESCAPE)
	await frames(5)
	check(art.age > frozen.age and pose() != frozen, "resume continues the same short performance")
	await frames(35)
	check(art.age >= 0.72 and art.swing.rotation.is_zero_approx() and art.clapper.rotation.is_zero_approx(), "the short damped performance settles both connected parts")
	await shoot(world.bell.global_position)
	check(game.records.size() == 2 and not game.records.back().valid and game.records.back().base == 0 and game.records.back().display == "未响应", "a real cooldown click consumes its actual slot without repeating the five-point mechanism")
	check(art.age >= 0.72 and art.swing.rotation.is_zero_approx(), "blocked mechanism input cannot restart its cosmetic swing")
	await begin(0)
	await harvest()
	await frames(75)
	check(game.state == game.State.SCORE and game.last_result.score == 4605 and game.records.size() == 5, "raised mechanism and real four weakpoints preserve the 4605 harvest")
	await keyboard(KEY_SPACE)
	await frames(80)
	check(game.state == game.State.END and world.finale_won and game.total_score == 4605, "the actual harvest retains the existing winner and final stage performance")
	screenshot("win")
	game.set_reduced_motion(true)
	await begin(0)
	await shoot(world.bell.global_position)
	await frames(10)
	check(game.records[0].valid and game.records[0].base == 5 and art.swing.rotation.is_zero_approx() and art.clapper.rotation.is_zero_approx(), "reduced motion preserves the real mechanism while both bell parts remain still")
	screenshot("reduced")
	game.set_reduced_motion(false)
	await begin(0)
	await shoot(world.bell.global_position)
	await frames(5)
	game.reset_round()
	check(game.records.is_empty() and world.bell_cooldown == 0 and art.age == 1 and art.swing.rotation.is_zero_approx() and art.clapper.rotation.is_zero_approx(), "restart clears a live bell cue, cooldown and actual shot evidence")
	game.start_round()
	await frames(75)
	if window_review:
		for size_ in [Vector2i(1152,720),Vector2i(1920,1080)]:
			root.size = size_
			await frames(12)
			var point = world.camera.unproject_position(world.bell.global_position)
			var label_point = world.camera.unproject_position(world.bell_label.global_position)
			check(root.get_visible_rect().has_point(point) and label_point.y > 130 * size_.y / 900.0 and point.y < 690 * size_.y / 900.0, "actual copper bell and its label stay within the stage at width " + str(size_.x))
			screenshot("window-" + str(size_.x))
		root.size = Vector2i(1440,900)
		await frames(8)
	check(original_camera.is_equal_approx(world.camera.global_transform), "bell artwork and real input leave the aiming camera unchanged")
	print("BELL REVIEW: ",JSON.stringify({"passed":passed,"failed":failed,"window_review":window_review,"actual_outcomes":outcomes,"real_win_score":4605,"opaque_batches":art.pieces.size(),"camera_stable":original_camera.is_equal_approx(world.camera.global_transform)}))
	await frames(24)
	for player in game.sound_players:
		player.stop()
		player.stream = null
	await frames(3)
	quit.call_deferred(1 if failed else 0)
