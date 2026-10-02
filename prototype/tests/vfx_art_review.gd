extends "res://tests/feedback_walkthrough.gd"
## Actual archived/current effects in the same unchanged world and scoring path.
const LEGACY = "res://../.art_archive/2026-10-02-v22/vfx.gd"
var baseline = false
var runs: Array = []
func screenshot(name_: String) -> void:
	var prefix = "before" if baseline else "after"
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v22-"+prefix+"-vfx-"+name_+".png"))
func setup(old: bool) -> void:
	baseline = old
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound_on = false
	if old:
		game.world.free()
		var source = FileAccess.get_file_as_string("res://../.art_archive/2026-10-02-v22/world.gd")
		var script = GDScript.new()
		script.source_code = source.replace('const Vfx = preload("res://scripts/vfx.gd")','const Vfx = preload("'+LEGACY+'")')
		if script.reload()!=OK:
			push_error("Archived VFX world adapter did not compile")
			quit(1)
			return
		game.world = script.new()
		game.add_child(game.world)
	await frames(30)
	await begin(0)
func colliders() -> Array:
	var result = []
	for t in game.world.targets:
		for key in ["body_hit","weak_hit","shield_hit"]:
			var node = t.get(key)
			if node:result.append([t.index,key,str(node.position),str(node.get_child(0).shape.size),node.collision_layer])
	return result
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
func sequence() -> void:
	var world = game.world
	var registration = []
	for t in world.targets:registration.append(str(world.camera.unproject_position(t.weak_hit.global_position)))
	var result = {"target_centres":registration,"collider_definitions":colliders(),"camera":str(world.camera.global_transform),"dynamic_lights":world.find_children("*","Light3D",true,false).size(),"held_draws":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))}
	screenshot("ready")
	await shoot(world.targets[0].weak_hit.global_position)
	screenshot("paper-flash")
	await frames(8)
	screenshot("paper-scatter")
	await frames(18)
	screenshot("paper-decay")
	await begin(0)
	await shoot(world.targets[5].global_position+Vector3(0,0,0.38))
	screenshot("wood-flash")
	await frames(8)
	screenshot("wood-scatter")
	await begin(1)
	await shoot(world.targets[2].global_position+Vector3(0,0,0.24))
	await frames(22)
	await shoot(world.targets[2].weak_hit.global_position)
	screenshot("aerial-flash")
	await frames(8)
	screenshot("aerial-scatter")
	await begin(0)
	await shoot(world.targets[0].weak_hit.global_position)
	await surrender()
	result.training_score = game.total_score
	result.earned_duck_energy = game.duck_energy
	await keyboard(KEY_SPACE)
	await frames(70)
	await shoot(world.bell.global_position)
	screenshot("help-start")
	await frames(12)
	screenshot("help-complete")
	await frames(16)
	screenshot("help-decay")
	game.set_reduced_motion(true)
	await begin(0)
	await shoot(world.targets[1].weak_hit.global_position)
	screenshot("reduced-start")
	await frames(5)
	screenshot("reduced-rest")
	result.actual_outcomes = outcomes.duplicate(true)
	result.baseline = baseline
	runs.append(result)
func run() -> void:
	root.size = Vector2i(1440,900)
	for old in [true,false]:
		outcomes.clear()
		review_aim = Vector2(720,450)
		await setup(old)
		await sequence()
		game.free()
		await process_frame
	var a = runs[0]
	var b = runs[1]
	var stable = a.target_centres==b.target_centres and a.collider_definitions==b.collider_definitions and a.camera==b.camera and a.dynamic_lights==b.dynamic_lights and a.actual_outcomes==b.actual_outcomes
	print("VFX ART REVIEW: ",JSON.stringify({"before":a,"after":b,"same_registration_colliders_camera_lights_real_outcomes":stable,"actual_archived_v21_world_vfx":true,"scope":"Native same 1440x900 camera/assets/inputs/ticks. Actual v21 world and VFX backups; baseline world adapter only redirects VFX preload. Current VFX art and update order consume target poses after movement. Idle, paper/wood/aerial hit, earned bell help and reduced-particle frames. Effect differences intentional; not every shot pose, target occlusion, human recognition/comfort or physical FPS."}))
	if not stable or a.training_score!=116 or a.earned_duck_energy!=4:
		push_error("VFX actual before/after path comparison failed")
		quit(1)
		return
	quit()
