extends SceneTree
## Same actual v0.18 world and current stage, unchanged GLBs.
const LEGACY = "res://../.art_archive/2026-10-02-v19/"
var game: Node3D
var before_points: Array = []
var before_camera: Transform3D
var before_lights = 0
var before_colliders: Array = []
var before_faces: Array = []
var before_bell: Vector3
var before_bell_shape: Vector3
var before_draws: int

func _initialize() -> void:
	run.call_deferred()

func rendered() -> void:
	for i in range(5):
		await process_frame
		await RenderingServer.frame_post_draw

func snapshot(name_: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v19-" + name_ + ".png"))

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
		var script = GDScript.new()
		script.source_code = source
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
	snapshot("before-bell")
	before_camera = game.world.camera.global_transform
	before_lights = game.world.find_children("*", "Light3D", true, false).size()
	before_faces = faces()
	before_bell = game.world.bell.position
	before_bell_shape = game.world.bell.get_child(0).shape.size
	before_draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	for target in game.world.targets:
		before_points.append(game.world.camera.unproject_position(target.weak_hit.global_position))
		before_colliders.append(collider_description(target))
	game.free()
	await process_frame
	await setup(false)
	snapshot("after-bell")
	var world = game.world
	var registration = 0.0
	var collider_changes = 0
	for target in world.targets:
		registration = maxf(registration, before_points[target.index].distance_to(world.camera.unproject_position(target.weak_hit.global_position)))
		if before_colliders[target.index] != collider_description(target):
			collider_changes += 1
	var after_faces = faces()
	var after_draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var shown = root.get_texture().get_image()
	world.bell_mesh.hide()
	await rendered()
	var hidden = root.get_texture().get_image()
	var weak_pixel_change = 0.0
	for target in world.targets:
		var point = world.camera.unproject_position(target.weak_hit.global_position)
		for x in range(-4,5):
			for y in range(-4,5):
				var a = shown.get_pixel(int(point.x)+x,int(point.y)+y)
				var b = hidden.get_pixel(int(point.x)+x,int(point.y)+y)
				weak_pixel_change = maxf(weak_pixel_change,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
	world.bell_mesh.show()
	await rendered()
	var lens_bounds: Array = []
	for side in [-1, 1]:
		var point = world.camera.unproject_position(Vector3(side * 6.9, 6.24, -3.96))
		lens_bounds.append([point.x, point.y])
	print("BELL ART REVIEW: ", JSON.stringify({"actual_archived_world":true, "camera_stable":before_camera.is_equal_approx(world.camera.global_transform), "max_target_registration_change_px":registration, "collider_definition_changes":collider_changes, "dynamic_light_count_before":before_lights, "dynamic_light_count_after":world.find_children("*", "Light3D", true, false).size(), "bell_before_position":str(before_bell),"bell_after_position":str(world.bell.position),"bell_shape_unchanged":before_bell_shape == world.bell.get_child(0).shape.size,"weakpoint_hidden_bell_max_channel_difference":weak_pixel_change,"bell_batches":world.bell_mesh.pieces.size(),"before_held_draws":before_draws,"after_held_draws":after_draws, "before_faces":before_faces, "after_faces":after_faces, "scope":"Native same-camera held 1.3s stage with actual v0.18 world backup. Actual mechanism raised 0.7; hit size unchanged. Nine 5x5 cheek patches and 9x9 weakpoint on/off probes, not human identification or all poses. All GLBs unchanged. Held draw counts are one-pose scene cost, not FPS."}))
	if registration != 0 or collider_changes != 0 or not before_camera.is_equal_approx(world.camera.global_transform) or before_lights != world.find_children("*", "Light3D", true, false).size() or after_faces.any(func(v): return v.luminance < 0.2) or weak_pixel_change > 1.0/255.0 or before_bell_shape != world.bell.get_child(0).shape.size:
		push_error("Lighting art comparison failed registration, lights or cheek reading")
		quit(1)
		return
	world.camera.position = Vector3(7.65,3.7,-1.3)
	world.camera.look_at(world.bell.global_position + Vector3(0,-0.08,0))
	world.camera.fov = 30
	game.hud.root.hide()
	await rendered()
	snapshot("bell-hero")
	game.free()
	await process_frame
	quit()
