extends SceneTree

const Rules = preload("res://scripts/rules.gd")
var passed = 0
var failed = 0
var game: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func tick(frames: int = 2) -> void:
	for i in range(frames):
		await physics_frame
		await process_frame

func fire(pos: Vector3) -> void:
	game.cooldown = 0
	var event = InputEventMouseButton.new()
	event.position = game.world.camera.unproject_position(pos)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await tick()

func key_event(key: int, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	await tick(1)

func new_round(preset: int = 1) -> void:
	game.reset_round()
	game.start_round()
	game.toggle_pause()
	game.set_loadout(preset)
	game.toggle_pause()
	await tick()

func run() -> void:
	root.size = Vector2i(1440, 900)
	# Reference calculation from v0.4, including order dependence.
	var five: Array = []
	for i in range(5):
		five.append({"base": 35 if i >= 2 else 20, "valid": true, "destroyed": true, "weak": i >= 2, "air": false})
	check(Rules.evaluate(five, ["paper", "metronome", "smile"]).score == 3375, "five balloons reference = 3375")
	check(Rules.evaluate(five, ["paper", "smile", "metronome"]).score == 2875, "reordered prizes reference = 2875")
	check(Rules.growth_gain([], "early") == 0, "empty early report gives no energy")
	check(Rules.growth_gain([{"valid": false}], "early") == 0, "misses alone give no energy")
	check(Rules.growth_gain([{"valid": true}], "timeout") == 0, "forced timeout gives no energy")
	check(Rules.growth_gain([{"valid": true}], "early") == 4, "only real unused slots yield energy")
	var partial = [{"base": 35, "valid": true, "destroyed": true, "weak": true}, {"base": 0, "valid": false}]
	check(Rules.evaluate(partial).performances.has("精准 1 次"), "a miss preserves completed precision")
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await tick(4)
	game.sound_on = false
	await new_round()
	game.toggle_pause()
	var spring_id = game.core_ids[0]
	game.set_loadout(2)
	check(game.core_ids[2] == spring_id, "moving spring core preserves its unique instance identity")
	game.set_loadout(1)
	game.toggle_pause()
	await tick()
	var target = game.world.targets[2]
	await fire(target.global_position + Vector3(0, 0, 0.24))
	check(game.records.size() == 1, "real mouse input spends one trigger")
	check(game.records[0].valid and game.records[0].base == 0 and not game.records[0].destroyed, "spring is a nonlethal valid preparation with zero score")
	check(target.alive and target.airborne, "spring changes a live target's actual position state")
	await tick(18)
	check(target.lift > 1.0, "ballistic lift changes the actual world position")
	var raised = target.global_position
	var old_position = Vector3(raised.x, target.base_position.y, raised.z)
	var at_raised = game.raycast(game.world.camera.unproject_position(raised + Vector3(0, 0, 0.24)))
	check(not at_raised.is_empty() and at_raised.collider.has_meta("target") and at_raised.collider.get_meta("target") == target, "raycast hits the moved target")
	var at_old = game.raycast(game.world.camera.unproject_position(old_position + Vector3(0, 0, 0.24)))
	check(at_old.is_empty() or not at_old.collider.has_meta("target") or at_old.collider.get_meta("target") != target, "target collider no longer occupies its old position")
	await fire(raised + Vector3(0, 0, 0.24))
	check(game.records.size() == 2 and game.records[1].destroyed and game.records[1].air and game.records[1].relay, "ordinary bullet cashes in aerial preparation")
	check(game.records[1].weak, "front bullseye collision records precision")
	await key_event(KEY_R, true)
	await tick(5)
	check(game.state == game.State.AIMING and game.hold_time < 0.35, "short R press does not submit")
	await key_event(KEY_R, false)
	check(game.hold_time == 0 and game.state == game.State.AIMING, "releasing R cancels submission")
	await key_event(KEY_R, true)
	await tick(25)
	await key_event(KEY_R, false)
	check(game.duck_energy == 3 and game.duck_level == 1, "two fired slots and three surrendered slots upgrade the duck")
	check(game.group_duck_level == 0, "growth does not apply retroactively")
	var score = game.total_score
	game.settle("early")
	check(game.total_score == score and game.duck_energy == 3, "settlement cannot submit score or growth twice")
	game.continue_group()
	await tick()
	check(game.group_index == 2 and game.records.is_empty() and game.group_duck_level == 1, "next group refreshes ammunition and activates grown ability")
	check(game.ammo[0] == "spring", "ammo component persists between groups")
	await fire(game.world.bell.global_position)
	check(game.records[0].valid and game.records[0].base == 5 and game.saw_duck, "real bell shot triggers the grown duck")
	var pirate = game.world.targets[5]
	check(pirate.held > 0 and pirate.exposed > 0, "duck holds a genuinely exposed pirate")
	await fire(pirate.global_position + Vector3(0, 0, 0.24))
	check(game.records[1].relay and game.records[1].destroyed, "bell preparation links to a later weapon kill")
	var before_time = game.time_left
	var before_pos = game.world.targets[1].position
	await key_event(KEY_TAB, true)
	await key_event(KEY_TAB, false)
	check(game.state == game.State.PAUSED, "actual Tab input opens pause before GUI focus traversal")
	await tick(8)
	check(is_equal_approx(game.time_left, before_time) and game.world.targets[1].position.is_equal_approx(before_pos), "pause freezes countdown and target motion")
	game.set_loadout(0)
	check(game.ammo[0] == "spring", "loadout is locked after first trigger")
	game.r_held = true
	game.toggle_pause()
	check(not game.r_held and not game.queued_shot, "resume clears held and queued input")
	# Carpet bounces once and inherits the original preparation, without damage.
	await new_round()
	target = game.world.targets[2]
	await fire(target.global_position + Vector3(0, 0, 0.24))
	for i in range(100):
		if target.carpet_used:
			break
		await tick(1)
	check(target.carpet_used and target.airborne and target.alive, "real carpet landing re-launches a live target")
	check(target.preparation_shot == 0 and target.preparation_group == game.group_index, "carpet inherits the originating shot's evidence")
	await tick(85)
	check(not target.airborne and target.alive, "carpet does not bounce again or deal damage")
	# Crossing a group cannot re-use old preparation evidence.
	await new_round()
	target = game.world.targets[2]
	await fire(target.global_position + Vector3(0, 0, 0.24))
	game.settle("early")
	game.continue_group()
	game.toggle_pause()
	game.set_loadout(0)
	game.toggle_pause()
	await tick(2)
	await fire(target.global_position + Vector3(0, 0, 0.24))
	check(game.records[0].air and not game.records[0].relay, "cross-group airborne target retains aerial state but not relay evidence")
	# Shielded preparation must fail without granting a hit or a source.
	await new_round()
	pirate = game.world.targets[5]
	await fire(pirate.global_position + Vector3(0, 0, 0.45))
	check(not game.records[0].valid and not pirate.airborne and not pirate.shield_broken, "shield blocks nonlethal preparation without taking damage")
	# Five-shot cap and valid reference scoring through actual collision.
	await new_round(0)
	for i in range(5):
		target = game.world.targets[i]
		await fire(target.global_position + Vector3(0.36 if i < 2 else 0, 0, 0.24))
	check(game.records.size() == 5 and game.state == game.State.SCORE, "fifth trigger automatically reports")
	check(game.last_result.score == 3375, "physical five-balloon run reproduces 3375 reference")
	check(game.duck_energy == 0, "full group cannot grant surrender energy")
	game.continue_group()
	check(game.state == game.State.END and game.total_score >= 1800, "score goal ends the round with a win")
	# Time ending settles partial evidence exactly once and grants no investment.
	await new_round(0)
	await fire(game.world.targets[2].global_position + Vector3(0, 0, 0.24))
	game.time_left = 0.01
	await tick()
	check(game.state == game.State.SCORE and game.duck_energy == 0, "timeout forces partial settlement without duck growth")
	game.continue_group()
	check(game.state == game.State.END, "timeout ends the round")
	game.queue_free()
	await process_frame
	print("\nRESULT: ", passed, " passed; ", failed, " failed")
	quit(1 if failed else 0)
