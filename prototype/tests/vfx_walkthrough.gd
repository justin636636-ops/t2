extends "res://tests/feedback_walkthrough.gd"
## Real weapon hits, returned ammunition and bell assistance. No outcome edits.
var help_score = 0
var moving_endpoint_error = 0.0
var moving_target_distance = 0.0
func screenshot(name_: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v22-vfx-"+name_+".png"))
func latest(kind_: String) -> Dictionary:
	for i in range(game.world.vfx.effects.size()-1,-1,-1):
		if game.world.vfx.effects[i].kind==kind_:return game.world.vfx.effects[i]
	return {}
func positions(e: Dictionary) -> Array:
	var result = []
	for i in range(e.node.multimesh.instance_count):
		var pose: Transform3D = e.node.multimesh.get_instance_transform(i)
		result.append([str(pose.origin),str(pose.basis.orthonormalized())])
	return result
func state_of(e: Dictionary) -> Array:
	var result = [e.age]
	for i in range(e.node.multimesh.instance_count):
		result.append(str(e.node.multimesh.get_instance_transform(i)))
		result.append(str(e.node.multimesh.get_instance_color(i)))
	return result
func visible_segments(e: Dictionary) -> int:
	var count_ = 0
	for i in range(e.node.multimesh.instance_count):
		if e.node.multimesh.get_instance_color(i).a>0.1:count_+=1
	return count_
func surrender() -> void:
	var event = InputEventKey.new()
	event.keycode = KEY_R
	event.physical_keycode = KEY_R
	event.pressed = true
	Input.parse_input_event(event)
	await frames(24)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(40)
func earn_help() -> void:
	await begin(0)
	await shoot(game.world.targets[0].weak_hit.global_position)
	await surrender()
	check(game.duck_energy==4 and game.duck_level==1 and game.records.size()==1 and game.records[0].valid and game.last_result.score==116,"actual weakpoint followed by returning four unused rounds earns level-one help without editing energy")
	await keyboard(KEY_SPACE)
	await frames(70)
	await shoot(game.world.bell.global_position)
	check(game.group_index==2 and game.group_duck_level==1 and game.records.back().base==5 and game.duck_used and game.world.targets[5].held>0,"real second-group bell activates the earned duck and holds the actual captain")
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
	await shoot(world.targets[0].weak_hit.global_position)
	check(game.records.back().valid and game.records.back().weak and game.records.back().destroyed and game.records.back().base==35,"actual first paper actor weakpoint still resolves immediately for 35")
	var paper = latest("debris")
	check(not paper.is_empty() and paper.paper and paper.node.multimesh.instance_count==20 and paper.node.multimesh.mesh is ArrayMesh,"actual paper kill emits one twenty-piece authored folded-paper batch")
	screenshot("paper-flash")
	var moving = positions(paper)
	await frames(4)
	check(positions(paper)!=moving,"actual folded scraps fan out and tumble while the scored actor retires")
	screenshot("paper-scatter")
	await keyboard(KEY_TAB)
	var frozen = state_of(paper)
	await frames(10)
	check(state_of(paper)==frozen,"real pause freezes every live paper transform, colour and age")
	await keyboard(KEY_ESCAPE)
	await frames(6)
	check(state_of(paper)!=frozen,"resume continues the same live paper batch")
	await frames(65)
	check(latest("debris").is_empty(),"first scored burst retires completely before the next action")
	game.set_reduced_motion(true)
	await begin(0)
	await shoot(world.targets[1].weak_hit.global_position)
	paper = latest("debris")
	check(game.records.back().weak and game.records.back().base==35 and paper.node.multimesh.instance_count==6 and fan_count()==0,"reduced real kill keeps six palette pieces and truthful scoring without radial spokes")
	var resting = positions(paper)
	await frames(4)
	check(positions(paper)==resting,"reduced paper remains stationary with no decorative flight or tumble")
	screenshot("reduced-paper")
	await frames(20)
	check(latest("debris").is_empty(),"reduced static pieces retire within their short cue")
	game.set_reduced_motion(false)
	await begin(1)
	await shoot(world.targets[2].global_position+Vector3(0,0,0.24))
	check(game.records.back().valid and not game.records.back().destroyed and world.targets[2].airborne,"actual spring preparation launches the actor with no invented kill")
	await frames(22)
	await shoot(world.targets[2].weak_hit.global_position)
	check(game.records.back().weak and game.records.back().air and game.records.back().relay and game.records.back().source_shot==0 and game.records.back().base==35,"actual aerial precision preserves its 35-point causal preparation relay")
	screenshot("aerial-flash")
	await frames(8)
	screenshot("aerial-scatter")
	await begin(0)
	await shoot(world.targets[5].global_position+Vector3(0,0,0.38))
	var chip = latest("debris")
	check(game.records.back().valid and game.records.back().base==5 and not game.records.back().destroyed and not chip.paper and chip.node.multimesh.instance_count==12,"real shield break emits its twelve painted-wood flakes and unchanged five points")
	screenshot("shield-flash")
	await frames(8)
	screenshot("shield-scatter")
	await frames(18)
	await shoot(world.targets[5].weak_hit.global_position)
	check(game.records.back().weak and game.records.back().destroyed and game.records.back().base==45,"opened actual pirate harvest keeps its 45-point weakpoint result")
	screenshot("wood-harvest")
	await earn_help()
	var ribbon = latest("ribbon")
	check(not ribbon.is_empty() and ribbon.target==world.targets[5] and visible_segments(ribbon)>0 and visible_segments(ribbon)<24,"earned assistance starts at the duck with a partial trail toward the actual held captain")
	if ribbon.is_empty():
		quit(1)
		return
	screenshot("help-start")
	var shared_mesh: RID = ribbon.node.multimesh.mesh.get_rid()
	await frames(12)
	check(visible_segments(ribbon)==24 and ribbon.node.multimesh.mesh.get_rid()==shared_mesh,"causal help reaches the whole route using the same reusable mesh")
	var pose: Transform3D = ribbon.node.multimesh.get_instance_transform(23)
	var endpoint: Vector3 = ribbon.node.to_global(pose*Vector3(0,0.5,0))
	check(endpoint.distance_to(world.targets[5].global_position+Vector3(0,0.8,0.1))<0.02,"last help segment reaches the live captain rather than a stale snapshot")
	screenshot("help-complete")
	await keyboard(KEY_TAB)
	frozen = state_of(ribbon)
	await frames(12)
	check(state_of(ribbon)==frozen,"pause freezes all help segments and their reveal/fade age")
	await keyboard(KEY_ESCAPE)
	await frames(6)
	check(ribbon.age>frozen[0] and ribbon.node.multimesh.mesh.get_rid()==shared_mesh,"resume keeps the live endpoint and shared mesh while finishing the cue")
	for index in range(5,9):
		await shoot(world.targets[index].weak_hit.global_position)
		if index<8:await frames(22)
	help_score = game.total_score
	check(help_score==4721 and game.last_result.score==4605 and game.records.size()==5 and game.records.all(func(v):return v.valid),"real 116-point training and level-one bell/four crew harvest settle the original 4721 total")
	await frames(70)
	check(latest("ribbon").is_empty(),"completed help path is reclaimed after its finite cue")
	game.set_reduced_motion(true)
	await earn_help()
	ribbon = latest("ribbon")
	if ribbon.is_empty():
		check(false,"reduced real bell did not create earned assistance")
		quit(1)
		return
	check(visible_segments(ribbon)==24,"reduced earned help shows the full quiet route immediately")
	resting = state_of(ribbon).slice(1)
	await frames(4)
	check(state_of(ribbon).slice(1)==resting,"reduced held-target route has no reveal pulse, width pulse or colour pulse")
	screenshot("help-reduced")
	if window_review:
		await keyboard(KEY_TAB)
		for size_ in [Vector2i(1152,720),Vector2i(1920,1080)]:
			root.size = size_
			await frames(5)
			check(root.get_visible_rect().has_point(world.camera.unproject_position(ribbon.start)) and root.get_visible_rect().has_point(world.camera.unproject_position(ribbon.target.global_position+Vector3(0,0.8,0.1))),"real help endpoints remain on screen at native width "+str(size_.x))
			screenshot("help-window-"+str(size_.x))
		root.size = Vector2i(1440,900)
		await frames(5)
	game.set_reduced_motion(false)
	await begin(0)
	for group in range(3):
		await shoot(world.targets[group].weak_hit.global_position)
		await surrender()
		await keyboard(KEY_SPACE)
		await frames(70)
	check(game.group_index==4 and game.duck_energy==9 and game.group_duck_level==3,"three actual hit-and-return groups earn level-three assistance on the fourth group")
	await shoot(world.bell.global_position)
	ribbon = latest("ribbon")
	check(not ribbon.is_empty() and ribbon.target==world.targets[5] and world.targets[5].airborne and game.records.back().base==5,"real level-three bell launches the captain and connects its cosmetic trail")
	if ribbon.is_empty():
		quit(1)
		return
	await frames(12)
	var moving_start: Vector3 = world.targets[5].global_position
	for i in range(20):
		var segment: Transform3D = ribbon.node.multimesh.get_instance_transform(23)
		var tip: Vector3 = ribbon.node.to_global(segment*Vector3(0,0.5,0))
		moving_endpoint_error = maxf(moving_endpoint_error,tip.distance_to(world.targets[5].global_position+Vector3(0,0.8,0.1)))
		moving_target_distance = maxf(moving_target_distance,moving_start.distance_to(world.targets[5].global_position))
		if i==8:screenshot("help-airborne")
		await frames(1)
	check(moving_target_distance>0.15 and moving_endpoint_error<0.02,"fully revealed trail follows the moving airborne captain in the same drawn frame")
	await keyboard(KEY_TAB)
	frozen = state_of(ribbon)
	var frozen_target: Vector3 = world.targets[5].global_position
	await frames(6)
	check(state_of(ribbon)==frozen and world.targets[5].global_position.is_equal_approx(frozen_target),"real pause freezes both airborne helper endpoint and every segment")
	await keyboard(KEY_ESCAPE)
	await frames(3)
	check(world.targets[5].global_position.distance_to(frozen_target)>0.01,"resume preserves the actual airborne trajectory under its cosmetic link")
	game.reset_round()
	await frames(3)
	check(world.vfx.effects.is_empty() and world.vfx.get_child_count()==0,"restart removes every earlier particle and assistance node")
	check(camera_pose.is_equal_approx(world.camera.global_transform),"new hit and assistance graphics leave the aiming camera unchanged")
	print("VFX REVIEW: ",JSON.stringify({"passed":passed,"failed":failed,"window_review":window_review,"actual_outcomes":outcomes,"earned_help_score":help_score,"moving_endpoint_error":moving_endpoint_error,"moving_target_distance":moving_target_distance,"camera_stable":camera_pose.is_equal_approx(world.camera.global_transform)}))
	await frames(24)
	for player in game.sound_players:
		player.stop()
		player.stream = null
	await frames(3)
	quit.call_deferred(1 if failed else 0)
