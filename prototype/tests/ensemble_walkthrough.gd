extends "res://tests/feedback_walkthrough.gd"
## Real collisions exercise attention, interruption and ending priorities.

func screenshot(name_: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v22-ensemble-" + name_ + ".png"))

func observers() -> Array:
	return game.world.targets.filter(func(actor): return actor.alive and actor.attention_age < actor.ATTENTION_DURATION)

func run() -> void:
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await frames(60)
	await begin(0)
	await shoot(Vector3(-7.1, 5.5, -4))
	check(not game.records.back().valid and observers().is_empty(), "a real miss leaves the surrounding cast quiet")
	await frames(20)
	var source = game.world.targets[2]
	await shoot(source.global_position + Vector3(0, 0, 0.24))
	check(game.records.back().destroyed and game.records.back().weak and observers().size() == 2 and not source.alive, "real precision kill assigns two living nearby observers without retaining the retiring source")
	await frames(12)
	screenshot("precision")
	var responding: Array = observers()
	var poses: Array = []
	var greatest_drift = 0.0
	for actor in responding:
		var root_pose: Transform3D = actor.transform
		var face_pose: Transform3D = actor.rig.parts.Pupil_L.transform
		poses.append({"index": actor.index, "age": actor.attention_age, "root": actor.transform, "face": face_pose})
		actor.animate(0, game.world.visual_clock)
		var marker: Vector2 = game.world.camera.unproject_position(actor.weak_visual.to_global(Vector3(0, 0, 0.24)))
		var hit: Vector2 = game.world.camera.unproject_position(actor.weak_hit.global_position)
		greatest_drift = maxf(greatest_drift, marker.distance_to(hit))
		check(actor.transform.is_equal_approx(root_pose) and marker.distance_to(hit) < 2, "observer %d changes decorative pivots while keeping its root and bullseye registered" % actor.index)
	check(responding[0].attention_direction.x * responding[1].attention_direction.x < 0, "the two neighbours look inward toward the actual impact")
	await keyboard(KEY_TAB)
	var frozen = responding.map(func(actor): return {"age": actor.attention_age, "face": actor.rig.parts.Pupil_L.transform, "hand": actor.rig.parts.Hand_L.transform})
	await frames(20)
	var stable = true
	for i in range(responding.size()):
		stable = stable and is_equal_approx(frozen[i].age, responding[i].attention_age) and frozen[i].face.is_equal_approx(responding[i].rig.parts.Pupil_L.transform) and frozen[i].hand.is_equal_approx(responding[i].rig.parts.Hand_L.transform)
	check(game.state == game.State.PAUSED and stable, "real pause freezes the observers' clocks, gaze and hand poses")
	await keyboard(KEY_ESCAPE)
	await frames(32)
	check(observers().is_empty(), "observers return to their individual idle poses after the short response")
	await shoot(game.world.targets[0].global_position + Vector3(0.44, 0, 0.24))
	check(game.records.back().destroyed and not game.records.back().weak and observers().size() <= 2, "real body kill also respects the two-observer limit")
	await frames(18)
	await shoot(game.world.targets[4].global_position + Vector3(0, 0, 0.24))
	check(observers().size() <= 2, "successive real shots never make the full cast react together")
	await frames(45)
	game.reset_round()
	check(observers().is_empty() and game.world.targets.all(func(actor): return actor.attention_cooldown == 0), "restart clears all previous attention and cooldown state")
	await begin(1)
	await shoot(game.world.targets[2].global_position + Vector3(0, 0, 0.24))
	check(game.records.back().valid and game.world.targets[2].airborne and observers().size() == 2, "real preparation lets the grounded neighbours follow the launched target")
	await frames(12)
	screenshot("prepare")
	var grounded = observers()[0]
	await frames(5)
	await shoot(grounded.global_position + Vector3(0, 0, 0.24))
	check(game.records.back().destroyed and grounded.attention_strength == 0 and grounded.death_age > 0, "a hit on an observer immediately gives retirement priority")
	await frames(50)
	await begin(0)
	game.set_reduced_motion(true)
	await shoot(game.world.targets[2].global_position + Vector3(0, 0, 0.24))
	check(game.records.back().destroyed and observers().is_empty(), "reduced motion preserves the real kill without decorative neighbour reactions")
	game.set_reduced_motion(false)
	await begin(0)
	for slot in range(5):
		await shoot(Vector3(-7.1, 5.5, -4))
		await frames(18)
	await keyboard(KEY_SPACE)
	await frames(10)
	var show_ = game.world.stage_show
	check(game.group_index == 2 and game.state == game.State.AIMING and show_.group_age < 0.3 and show_.levels.any(func(value): return value > 0.91), "a real next group gives one restrained practical-light cue with immediate input")
	screenshot("group")
	await keyboard(KEY_TAB)
	var group_age: float = show_.group_age
	var levels: Array = show_.levels.duplicate()
	await frames(15)
	check(is_equal_approx(group_age, show_.group_age) and levels == show_.levels, "pause freezes the actual group light cue")
	await keyboard(KEY_ESCAPE)
	await frames(50)
	check(show_.levels.all(func(value): return absf(value - 0.9) < 0.001), "the group cue settles back to steady target lighting")
	game.set_reduced_motion(true)
	game.world.begin_group()
	await frames(10)
	check(show_.levels.all(func(value): return absf(value - 0.9) < 0.001), "reduced motion leaves group lights steady")
	game.set_reduced_motion(false)
	await begin(1)
	await shoot(game.world.bell.global_position)
	await frames(18)
	for i in range(5, 9):
		await shoot(game.world.targets[i].global_position + Vector3(0, 0, 0.24))
		await frames(24)
	await frames(45)
	var real_win_score: int = game.total_score
	await keyboard(KEY_SPACE)
	await frames(18)
	screenshot("win-flourish")
	check(game.state == game.State.END and game.world.finale_won and real_win_score >= 1800 and observers().is_empty(), "actual bell-and-pirate victory switches the cast into its ending performance")
	var flourish_pose: Transform3D = game.world.targets[1].rig.parts.Hand_L.transform
	await frames(120)
	screenshot("win-rest")
	check(not flourish_pose.is_equal_approx(game.world.targets[1].rig.parts.Hand_L.transform) and show_.levels.all(func(value): return absf(value - 1.07) < 0.001), "winning cast and practical lights finish their flourish and settle")
	print("ENSEMBLE REVIEW: ", JSON.stringify({"outcomes": outcomes, "max_marker_drift_px": greatest_drift, "real_win_score": real_win_score, "passed": passed, "failed": failed}))
	print("ENSEMBLE RESULT: ", passed, " passed; ", failed, " failed")
	await frames(24)
	for player in game.sound_players:
		player.stop()
		player.stream = null
	await frames(3)
	quit.call_deferred(1 if failed else 0)
