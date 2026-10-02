extends SceneTree
## Same actual v0.16 world/backdrop/shader and current stage, unchanged GLBs.
const LEGACY = "res://../.art_archive/2026-10-02-v21/"
var game: Node3D
var before_points: Array = []
var before_camera: Transform3D
var before_lights = 0
var before_colliders: Array = []
var before_faces: Array = []
var before_batches = 0
var before_draws = 0

func _initialize() -> void:
	run.call_deferred()

func rendered() -> void:
	for i in range(5):
		await process_frame
		await RenderingServer.frame_post_draw

func snapshot(name_: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v22-" + name_ + ".png"))

func setup(before: bool) -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound_on = false
	game.world.free()
	var world: Node3D
	if before:
		# Legacy backdrop adapter only redirects its shader to its exact backup.
		var source = FileAccess.get_file_as_string(ProjectSettings.globalize_path(LEGACY + "world.gd"))
		var original = 'const StageBackdrop = preload("res://scripts/stage_backdrop.gd")'
		if not source.contains(original):
			push_error("Archived lighting world adapter did not match")
			quit(1)
			return
		var script = GDScript.new()
		source = source.replace('const AttractionArt = preload("res://scripts/attraction_art.gd")', 'const AttractionArt = preload("' + LEGACY + 'attraction_art.gd")')
		script.source_code = source.replace(original, 'const StageBackdrop = preload("' + LEGACY + 'stage_backdrop_legacy.gd")')
		if script.reload() != OK:
			push_error("Archived lighting world could not compile")
			quit(1)
			return
		world = script.new()
	else:
		world = load("res://scripts/world.gd").new()
	game.world = world
	game.add_child(world)
	game.start_round()
	world.update_world(1.3, false, 1)
	game.hud.update_hud(1.3)
	await rendered()

func collider_description(target: Node3D) -> Dictionary:
	var description = {}
	for name_ in ["body_hit", "weak_hit", "shield_hit"]:
		var body = target.get(name_)
		if body:
			description[name_] = {"position":str(body.position), "size":str(body.get_child(0).shape.size), "layers":body.collision_layer}
	return description

func faces() -> Array:
	var image = root.get_texture().get_image()
	var values: Array = []
	for target in game.world.targets:
		var local = Vector3(0.34, -0.15, 0.20) if target.kind == "balloon" else Vector3(0.26, 0.56, 0.16)
		var point = game.world.camera.unproject_position(target.body_visual.to_global(local))
		var luma = 0.0
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var color = image.get_pixel(int(point.x) + dx, int(point.y) + dy)
				luma += (color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722) / 25.0
		values.append({"target":target.index, "point":[point.x, point.y], "luminance":luma})
	return values

func run() -> void:
	root.size = Vector2i(1440, 900)
	await setup(true)
	snapshot("before-harbour")
	before_camera = game.world.camera.global_transform
	before_lights = game.world.find_children("*", "Light3D", true, false).size()
	before_faces = faces()
	before_batches = game.world.stage_backdrop.pieces.size()+game.world.attraction_art.pieces.size()+game.world.stage_lighting.pieces.size()
	before_draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	for target in game.world.targets:
		before_points.append(game.world.camera.unproject_position(target.weak_hit.global_position))
		before_colliders.append(collider_description(target))
	game.free()
	await process_frame
	await setup(false)
	snapshot("after-harbour")
	var world = game.world
	var registration = 0.0
	var collider_changes = 0
	for target in world.targets:
		registration = maxf(registration, before_points[target.index].distance_to(world.camera.unproject_position(target.weak_hit.global_position)))
		if before_colliders[target.index] != collider_description(target):
			collider_changes += 1
	var after_faces = faces()
	var lens_bounds: Array = []
	for side in [-1, 1]:
		var point = world.camera.unproject_position(Vector3(side * 6.9, 6.24, -3.96))
		lens_bounds.append([point.x, point.y])
	print("HARBOUR ART REVIEW: ", JSON.stringify({"actual_archived_v20_world_backdrop_shader_attraction":true, "camera_stable":before_camera.is_equal_approx(world.camera.global_transform), "max_target_registration_change_px":registration, "collider_definition_changes":collider_changes, "dynamic_light_count_before":before_lights, "dynamic_light_count_after":world.find_children("*", "Light3D", true, false).size(), "held_draws_before":before_draws, "held_draws_after":int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), "scenic_batches_before":before_batches, "scenic_batches_after":world.stage_backdrop.pieces.size()+world.attraction_art.pieces.size()+world.stage_lighting.pieces.size(), "fixture_points":lens_bounds, "before_faces":before_faces, "after_faces":after_faces, "scope":"Native same-camera held 1.3s stage with actual v0.20 world/backdrop/shader/attraction backups. Nine 5x5 cheek patches, not human identification or all poses. All GLBs unchanged; the current painting replaces two harbour material batches."}))
	if registration != 0 or collider_changes != 0 or not before_camera.is_equal_approx(world.camera.global_transform) or before_lights != world.find_children("*", "Light3D", true, false).size() or after_faces.any(func(v): return v.luminance < 0.2):
		push_error("Lighting art comparison failed registration, lights or cheek reading")
		quit(1)
		return
	game.free()
	await process_frame
	quit()
