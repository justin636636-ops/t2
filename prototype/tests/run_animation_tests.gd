extends SceneTree

var game: Node3D
var passed = 0
var failed = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if value:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func key(code: int) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames()

func run() -> void:
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(20)
	game.sound_on = false
	var world = game.world
	var body_font: Font = game.hud.root.theme.default_font
	var missing_glyphs: Array = []
	for source in ["game", "hud", "rules", "world", "target"]:
		var text_ = FileAccess.get_file_as_string("res://scripts/" + source + ".gd")
		for i in range(text_.length()):
			var code = text_.unicode_at(i)
			if code >= 0x4e00 and code <= 0x9fff and not body_font.has_char(code):
				missing_glyphs.append(code)
	check(missing_glyphs.is_empty(), "bundled body font covers every Chinese character in game text")
	check(world.world_font == body_font and game.hud.number_font == world.world_number_font, "HUD and scoring labels share cached bundled fonts")
	check(not world.gun.visible and not world.duck.visible and not world.foreground.visible and not game.hud.score_label.is_visible_in_tree(), "title page hides gameplay equipment and counters")
	await key(KEY_TAB)
	check(root.gui_get_focus_owner() is Button and "第一次" in root.gui_get_focus_owner().text, "title-page Tab reaches the independent tutorial entry")
	game.hud.show_tutorial()
	await frames(20)
	check(game.state == game.State.READY and not world.foreground.visible and game.hud.modal.position.x > 100, "tutorial opens independently without starting the round")
	game.hud.show_start()
	await frames(20)
	for i in range(5):
		var target = world.targets[i]
		check(target.rig.parts.has_all(["Eye_L", "Eye_R", "Pupil_L", "Pupil_R", "Brow_L", "Brow_R", "Hand_L", "Hand_R"]), "monster %d exports independently animated facial parts and hands" % i)
		var left: Node3D = target.rig.parts.get("Eye_L")
		var right: Node3D = target.rig.parts.get("Eye_R")
		check(left != null and right != null and left.position.x < 0 and right.position.x > 0, "monster %d eye pivots keep the original face layout" % i)
		check(target.rig.parts.Pupil_L.get_parent() == left and target.rig.parts.Pupil_R.get_parent() == right, "monster %d pupils stay attached during a blink" % i)
	check(world.targets[0].weak_visual.get_child_count() == 2 and world.targets[0].weak_visual.get_child(0).mesh == world.targets[1].weak_visual.get_child(0).mesh, "targets share two material batches for their unchanged bullseyes")
	for i in range(5):
		var actor = world.targets[i]
		var original_root: Transform3D = actor.transform
		var greatest_drift = 0.0
		for clock in [0.20, 0.60, 2.1, 4.5, 7.8]:
			actor.animate(0, clock)
			var marker: Vector2 = world.camera.unproject_position(actor.weak_visual.to_global(Vector3(0, 0, 0.24)))
			var collider: Vector2 = world.camera.unproject_position(actor.weak_hit.global_position)
			greatest_drift = maxf(greatest_drift, marker.distance_to(collider))
		check(actor.transform.is_equal_approx(original_root) and greatest_drift < 2, "character %d personality poses keep its target root and visible bullseye registered" % i)
		actor.reset_target()
		var restored = true
		for part in actor.rig.parts:
			restored = restored and actor.rig.parts[part].transform.is_equal_approx(actor.rig.rests[part])
		check(restored, "character %d returns all independently sized facial and accessory pivots to its rest pose" % i)
	check(world.duck_rig.parts.has_all(["Wing_L", "Wing_R", "Key"]), "duck exports wings and mechanical key")
	check(world.gun_rig.parts.has_all(["Cylinder", "Hammer"]), "revolver exports cylinder and hammer")
	check(world.gun_rig.parts.has("Trigger"), "revolver exports a working trigger pivot")
	for i in range(5):
		var rig = world.targets[i].rig
		check(rig.parts.has("Mouth") and (rig.parts.has("Antenna") if i == 3 else rig.parts.has_all(["Crest_L", "Crest_R"])), "monster %d exports its mouth and characteristic ears or antenna" % i)
	for point in [Vector3(-6, 3.0, -3), Vector3(6, 4.8, -6.1), Vector3(0, 5.5, -3)]:
		world.gun_focus = point
		world.recoil = 0
		world.gun_reload = 1
		world.animate_gun(0, true)
		var muzzle: Vector3 = world.gun.to_global(Vector3(0, 0.035, -1.07))
		var axis: Vector3 = -world.gun.global_basis.z.normalized()
		check(axis.dot((point - muzzle).normalized()) > 0.9999, "barrel converges on real left/right/elevated targets including its muzzle offset")
	var old_follow: Quaternion = world.gun_follow
	world.gun_focus = Vector3(-6, 4, -3)
	world.animate_gun(1.0 / 60.0)
	check(old_follow.angle_to(world.gun_follow) > 0.01 and old_follow.angle_to(world.gun_follow) < 0.5, "aim movement follows promptly with bounded smoothing")
	check(world.stage_rig.parts.has_all(["Curtain_L", "Curtain_R"]) and world.ship_rig.parts.has_all(["Sail", "Pennant"]), "cloth scenery keeps separate pivots and its attached ornaments")
	world.animate_stage(0.12)
	var cloth_pose: Vector3 = world.ship_rig.parts.Sail.rotation
	world.visual_clock += 1.0
	world.animate_stage(0.12)
	check(not cloth_pose.is_equal_approx(world.ship_rig.parts.Sail.rotation), "the environment changes on the pause-controlled presentation clock")
	world.vfx.clear()
	world.shot_effect(Vector3(0, 3, -3), true)
	check(world.vfx.effects.back().spring_ammo and world.vfx.effects.back().node.mesh == world.vfx.meshes.spring_ray, "spring shots use a helical tracer rather than the ordinary ray")
	world.shot_effect(Vector3(0, 3, -3), false)
	check(not world.vfx.effects.back().spring_ammo and world.vfx.effects.back().node.mesh == world.vfx.meshes.ray, "ordinary shots preserve the straight tracer")
	check(world.vfx.effects.back().node.to_global(Vector3(0, 0.5, 0)).distance_to(Vector3(0, 3, -3)) < 0.001, "shot tracer ends at the resolved impact rather than a separate cosmetic aim")
	check(absf(world.gun_rig.parts.Trigger.rotation.x) > 0.2, "the trigger pulls immediately on a shot")
	world.carpet_rebound(Vector3(2.23, 2.7, -3))
	world.animate_stage(0.08)
	check(world.carpet_pads[9].node.position.y < 1.70 and is_equal_approx(world.carpet_pads[8].node.position.y, 1.70), "only the landing cushion compresses at the real target position")
	world.shot_effect(Vector3(0, 3, -3))
	world.update_world(0.21, false, 1)
	var cylinder_after_first: float = world.gun_rig.parts.Cylinder.rotation.z
	world.shot_effect(Vector3(0, 3, -3))
	check(absf(world.gun_rig.parts.Cylinder.rotation.z - cylinder_after_first) < 0.01, "a second shot continues cylinder rotation without snapping back")
	world.reload_weapon()
	world.update_world(0.08, false, 1)
	world.shot_effect(Vector3(0, 3, -3))
	check(world.gun_reload > 0.32 and world.gun.position.y > -0.66, "firing interrupts the cosmetic reload without delaying the shot")
	world.score_popup(Vector3.ZERO, 35, "precision")
	world.begin_group()
	check(world.effects.is_empty(), "new group clears previous-group score labels")
	var target = world.targets[0]
	var root_before: Transform3D = target.transform
	target.animate(0, 0.08)
	check(target.rig.parts.Eye_L.scale.y < 0.10, "blink closes the eye geometry")
	target.animate(0, 0.3)
	check(target.rig.parts.Eye_L.scale.y > 0.95, "blink reopens without resetting gameplay")
	check(target.transform.is_equal_approx(root_before), "decorative pose never shifts the target root or collider")
	var ring_center: Vector3 = target.weak_visual.to_global(Vector3(0, 0, 0.24))
	var collider_center: Vector3 = target.weak_hit.global_position
	check(world.camera.unproject_position(ring_center).distance_to(world.camera.unproject_position(collider_center)) < 2, "animated bullseye remains aligned to its real hitbox")
	game.start_round()
	game.aim = world.camera.unproject_position(target.weak_hit.global_position)
	game._physics_process(0)
	game.hud.update_hud(0)
	check(not game.hover_text.is_empty() and game.hud.next_detail.text == game.hover_text and not game.hud.crosshair_label.visible, "real target context appears in the ammo card instead of covering moving faces")
	target.launch(1, 0)
	target.animate(0.016, 0.5)
	check(target.rig.parts.Brow_L.position.y > target.rig.rests.Brow_L.origin.y + 0.03 and target.rig.parts.Eye_L.scale.y > 1.0, "airborne targets visibly widen their eyes and lift their brows")
	target.reset_target()
	var context_position: Vector3 = target.global_position + Vector3(-0.2, 0, 0.2)
	target.launch(1, 0)
	target.destroy(context_position, true)
	target.animate(0.075, 0.5)
	check(target.death_air and target.death_weak and target.death_side < 0 and target.rig.parts.Mouth.scale.y > 1.3, "aerial weakpoint impact preserves its direction and triggers a facial shock")
	check(not target.alive and target.weak_hit.collision_layer == 0 and world.vfx.effects.any(func(e): return e.kind == "glyph" and e.asset == "halo" and e.size > 0.5), "aerial precision effects never retain a scoring collider")
	target.reset_target()
	check(not target.death_air and not target.death_weak and is_equal_approx(target.rig.parts.Mouth.scale.y, 1), "reset clears the impact context and facial shock")
	target.destroy()
	check(not target.alive and target.body_visual.visible and target.weak_hit.collision_layer == 0, "death disables scoring collision immediately while the retreat is visible")
	await frames(9)
	check(target.body_visual.position.y < -0.01 and target.body_visual.visible, "death performs a visible retreat before retirement")
	await frames(25)
	check(not target.body_visual.visible, "retreated target is removed visually")
	target.reset_target()
	check(target.alive and target.body_hit.collision_layer == 1 and target.rig.meshes[0].transparency == 0, "respawn restores collision and clears instance fade")
	target.destroy()
	target.animate(0.28, 0.8)
	check(target.body_visual.position.y < -0.4 and target.rig.meshes[0].transparency == 0, "grounded retirement drops behind the stage while retaining opaque paint")
	target.reset_target()
	target.launch(1, 0)
	target.destroy()
	target.animate(0.44, 0.8)
	check(target.body_visual.visible and target.body_visual.scale.x < 0.35 and target.rig.meshes[0].transparency == 0, "airborne paper retirement contracts before its final fade")
	target.reset_target()
	var pirate = world.targets[5]
	var hinge_before: Vector3 = pirate.body_visual.to_global(Vector3(0, -0.85, 0))
	pirate.destroy()
	pirate.animate(0.21, 0.5)
	check(pirate.body_visual.rotation.x < -0.4 and pirate.body_visual.scale.x > 0.8, "wooden pirates fold backwards without balloon-like squashing")
	check(pirate.body_visual.to_global(Vector3(0, -0.85, 0)).distance_to(hinge_before) < 0.10, "the pirate folds around its lower mounting hinge rather than floating about its center")
	pirate.reset_target()
	world.activate_bell(1, 0, 0)
	await frames(18)
	check(pirate.shield_hit.collision_layer == 0 and pirate.shield_visual.visible and absf(pirate.shield_visual.rotation.x) > 1, "exposure physically opens the shield while preserving its visible hinge action")
	pirate.reset_target()
	pirate.break_shield()
	check(pirate.shield_hit.collision_layer == 0 and pirate.shield_visual.visible, "shield break removes collision before its debris animation")
	await frames(25)
	check(not pirate.shield_visual.visible and pirate.alive, "shield retires without destroying its pirate")
	world.vfx.duck_help(world.duck.global_position, world.targets[6], 1)
	world.duck_flash = 0.8
	game.toggle_pause()
	var before = world.visual_clock
	var effect_age = world.vfx.effects.back().age
	var pose: Vector3 = world.duck_rig.parts.Wing_L.rotation
	var weapon_pose: Transform3D = world.gun.transform
	var curtain_pose: Transform3D = world.stage_rig.parts.Curtain_L.transform
	var pad_age: float = world.carpet_pads[9].age
	var fabric_clock: float = world.fabric_materials[0].material.get_shader_parameter("fabric_clock")
	await frames(10)
	check(is_equal_approx(before, world.visual_clock) and is_equal_approx(effect_age, world.vfx.effects.back().age) and pose.is_equal_approx(world.duck_rig.parts.Wing_L.rotation), "pause freezes effects, toy poses and the presentation clock")
	check(curtain_pose.is_equal_approx(world.stage_rig.parts.Curtain_L.transform) and is_equal_approx(pad_age, world.carpet_pads[9].age) and is_equal_approx(fabric_clock, world.fabric_materials[0].material.get_shader_parameter("fabric_clock")), "pause also freezes cloth deformation and cushion recovery")
	check(weapon_pose.is_equal_approx(world.gun.transform), "pause freezes aim-follow, recoil and reload poses")
	game.hud.show_settings(game.hud.show_pause)
	await frames(20)
	root.size = Vector2i(1920, 1080)
	await frames(20)
	check(absf(game.hud.modal.position.x + game.hud.modal.size.x / 2 - game.hud.root.size.x / 2) < 1, "widescreen modal follows the real expanded viewport center")
	check(root.gui_get_focus_owner() is HSlider, "settings default focus starts on the volume slider")
	await key(KEY_TAB)
	check(root.gui_get_focus_owner() is CheckButton, "Tab traverses settings instead of resuming gameplay")
	await key(KEY_ESCAPE)
	check(game.state == game.State.PAUSED and not game.hud.settings_visible, "Escape returns from settings to pause")
	game.set_reduced_motion(true)
	game.toggle_pause()
	world.gun_focus = Vector3(4, 3, -3)
	world.recoil = 0
	world.gun_reload = 1
	world.animate_gun(0.016)
	var calm_muzzle: Vector3 = world.gun.to_global(Vector3(0, 0.035, -1.07))
	check((-world.gun.global_basis.z.normalized()).dot((world.gun_focus - calm_muzzle).normalized()) > 0.9999, "reduced motion retains truthful weapon aiming without follow lag")
	target.reset_target()
	target.launch(1, 0)
	await frames(12)
	check(target.airborne and target.lift > 0.5 and is_zero_approx(target.body_visual.rotation.z), "reduced motion preserves meaningful ballistic action without decorative sway")
	check(world.ship_rig.parts.Sail.rotation.is_zero_approx() and world.stage_rig.parts.Curtain_L.rotation.is_zero_approx() and is_zero_approx(world.fabric_materials[0].material.get_shader_parameter("flutter_power")), "reduced motion removes cloth sway and vertex flutter")
	world.vfx.clear()
	for i in range(100):
		world.vfx.glyph(Vector3.ZERO, "star", Color.WHITE, 0.2, 1)
	check(world.vfx.effects.size() <= world.vfx.MAX_EFFECTS, "burst spam remains within the cosmetic effect budget")
	world.vfx.advance(1.0)
	await frames()
	check(world.vfx.effects.is_empty() and world.vfx.get_child_count() == 0, "expired effect instances are reclaimed")
	world.vfx.debris(Vector3.ZERO)
	check(world.vfx.effects[0].particles.size() <= 6, "reduced motion also limits particle count")
	game.reset_round()
	check(world.vfx.effects.is_empty() and world.effects.is_empty(), "restart clears previous-round cosmetic effects")
	check(world.finale_age < 0 and is_equal_approx(world.stage_age, 1.0) and is_equal_approx(world.carpet_pads[9].node.scale.y, 1.0), "restart clears the ending performance and cushion deformation")
	game.queue_free()
	await process_frame
	print("\nANIMATION RESULT: ", passed, " passed; ", failed, " failed")
	quit(1 if failed else 0)
