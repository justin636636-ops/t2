extends "res://tests/feedback_walkthrough.gd"
## Actual inputs/collision/score in the five finished models, no outcome overrides.
func screenshot(name_: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v22-monsters-"+name_+".png"))
func actor_pose(target: Node3D) -> Dictionary:
	var poses = {"root":target.transform,"body":target.body_visual.transform,"weak":target.weak_hit.global_transform}
	for key in target.rig.parts:poses[key]=target.rig.parts[key].transform
	return poses
func run() -> void:
	window_review = "--window-review" in OS.get_cmdline_user_args()
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await frames(30)
	await begin(0)
	var world = game.world
	var camera_pose: Transform3D = world.camera.global_transform
	var parents = true
	for t in world.targets.slice(0,5):
		parents = parents and t.rig.parts.Pupil_L.get_parent()==t.rig.parts.Eye_L and t.rig.parts.Pupil_R.get_parent()==t.rig.parts.Eye_R and t.rig.parts.has("Hand_L") and t.rig.parts.has("Hand_R") and t.rig.parts.has("Mouth")
	check(parents,"all five finished actors keep their real facial and glove part hierarchy")
	screenshot("ready")
	for i in range(5):
		await shoot(world.targets[i].weak_hit.global_position)
		var record = game.records.back()
		check(record.valid and record.destroyed and record.weak and record.base==35 and record.target==i,"actual normal mouse input hits the finished actor "+str(i)+" scoring centre")
		if i<4:await frames(20)
	await frames(70)
	check(game.state==game.State.SCORE and game.last_result.score==3780 and game.records.size()==5,"the real five-weakpoint group keeps its actual 3780-point equipment result")
	screenshot("score")
	await keyboard(KEY_SPACE)
	await frames(80)
	check(game.state==game.State.END and world.finale_won and game.total_score==3780,"the actual finished-model group retains its existing winner")
	screenshot("win")
	await begin(1)
	var target = world.targets[1]
	await shoot(target.weak_hit.global_position)
	check(game.records.back().valid and not game.records.back().destroyed and game.records.back().base==0 and target.airborne,"real spring preparation lifts the costumed bat without changing its zero base score")
	await frames(6)
	screenshot("spring")
	await keyboard(KEY_TAB)
	var frozen = actor_pose(target)
	await frames(22)
	check(actor_pose(target)==frozen,"actual pause freezes the airborne shell, gloves and facial pivots together")
	await keyboard(KEY_ESCAPE)
	await frames(12)
	check(actor_pose(target)!=frozen and target.airborne,"resume advances the same actual airborne actor")
	await shoot(target.weak_hit.global_position)
	check(game.records.back().destroyed and game.records.back().weak and game.records.back().air and game.records.back().relay and game.records.back().source_shot==0,"the detailed airborne costume cannot block its real weakpoint relay")
	check(target.body_hit.collision_layer==0 and target.weak_hit.collision_layer==0,"actual aerial retirement immediately removes both hit volumes")
	await frames(4)
	screenshot("retirement")
	await frames(45)
	check(target.rig.meshes.all(func(m):return m.transparency>=0.999),"all finished mesh batches follow the original complete cosmetic retirement")
	game.set_reduced_motion(true)
	await begin(1)
	target = world.targets[2]
	await shoot(target.weak_hit.global_position)
	await frames(22)
	await shoot(target.weak_hit.global_position)
	check(game.records.back().destroyed and game.records.back().air and game.records.back().weak and game.records.back().relay,"reduced motion retains actual lantern spring and aerial weakpoint accounting")
	game.reset_round()
	var restored = true
	for t in world.targets.slice(0,5):
		for key in t.rig.parts:restored = restored and t.rig.parts[key].transform.is_equal_approx(t.rig.rests[key])
		for mesh in t.rig.meshes:restored = restored and mesh.transparency==0
	check(restored and game.records.is_empty(),"real restart restores every finished costume/face part and clears the shot evidence")
	game.set_reduced_motion(false)
	game.start_round()
	await frames(75)
	if window_review:
		for size_ in [Vector2i(1152,720),Vector2i(1920,1080)]:
			root.size = size_
			await frames(12)
			var within = true
			for t in world.targets.slice(0,5):
				var point = world.camera.unproject_position(t.weak_hit.global_position)
				within = within and root.get_visible_rect().has_point(point) and point.y>130*size_.y/900.0 and point.y<690*size_.y/900.0
			check(within,"all five actual finished scoring centres fit native width "+str(size_.x))
			screenshot("window-"+str(size_.x))
		root.size = Vector2i(1440,900)
		await frames(8)
	check(camera_pose.is_equal_approx(world.camera.global_transform),"finished models keep the same actual aiming camera through shots and resets")
	print("MONSTER REVIEW: ",JSON.stringify({"passed":passed,"failed":failed,"window_review":window_review,"actual_outcomes":outcomes,"real_full_score":3780,"camera_stable":camera_pose.is_equal_approx(world.camera.global_transform)}))
	await frames(24)
	for player in game.sound_players:
		player.stop()
		player.stream = null
	await frames(3)
	quit.call_deferred(1 if failed else 0)
