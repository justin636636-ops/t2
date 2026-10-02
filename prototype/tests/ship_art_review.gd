extends SceneTree
## Both ships use the same runtime glTF importer, camera, HUD and held pose.

class ReviewWorld extends "res://scripts/world.gd":
	var ship_asset: String
	func prepare_fabric(node: Node, top: float, bottom: float, amplitude: float, tailored: bool = false) -> void:
		# The archived ship keeps its actual v0.11 fabric treatment.
		super.prepare_fabric(node, top, bottom, amplitude, tailored and not ".art_archive/" in ship_asset)
	func model(asset: String, parent: Node3D, pos: Vector3 = Vector3.ZERO) -> Node3D:
		if asset != "pirate_ship":
			return super.model(asset, parent, pos)
		var document = GLTFDocument.new()
		var data = GLTFState.new()
		if document.append_from_file(ship_asset, data) != OK:
			push_error("Unable to load comparison ship: " + ship_asset)
			return Node3D.new()
		var node = document.generate_scene(data)
		node.position = pos
		parent.add_child(node)
		apply_finishes(node)
		return node

var game: Node3D
func _initialize() -> void:
	run.call_deferred()

func rendered() -> void:
	for i in range(8):
		await process_frame
		await RenderingServer.frame_post_draw

func setup(path_: String) -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.sound_on = false
	game.world.free()
	var world = ReviewWorld.new()
	world.ship_asset = path_
	game.world = world
	game.add_child(world)
	game.start_round()
	world.update_world(0.30, false, 1)
	game._process(0)
	await rendered()

func luminance(image_: Image, screen: Vector2) -> float:
	var value = 0.0
	for x in range(-2, 3):
		for y in range(-2, 3):
			var c = image_.get_pixel(int(screen.x) + x, int(screen.y) + y)
			value += (c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722) / 25.0
	return value

func info(image_: Image) -> Dictionary:
	var world = game.world
	var points: Array = []
	var faces: Array = []
	for target in world.targets:
		points.append(world.camera.unproject_position(target.weak_hit.global_position))
		if target.index < 5:
			faces.append(luminance(image_, world.camera.unproject_position(target.body_visual.to_global(Vector3(.34, -.15, .20)))))
	var cloth_sample: Vector2 = world.camera.unproject_position(Vector3(1.1, 6.65, -8.9))
	return {"points": points, "face_luminance": faces, "cloth_luminance": luminance(image_, cloth_sample), "cloth_sample": [cloth_sample.x, cloth_sample.y], "camera": world.camera.global_transform}

func run() -> void:
	root.size = Vector2i(1440, 900)
	var archive = ProjectSettings.globalize_path("res://../.art_archive/2026-10-02-v12/pirate_ship.glb")
	await setup(archive)
	var old_image: Image = root.get_texture().get_image()
	old_image.save_png(ProjectSettings.globalize_path("res://artifacts/v12-before-ship.png"))
	var before = info(old_image)
	game.free()
	await process_frame
	await setup(ProjectSettings.globalize_path("res://assets/models/pirate_ship.glb"))
	var image_: Image = root.get_texture().get_image()
	image_.save_png(ProjectSettings.globalize_path("res://artifacts/v12-after-ship.png"))
	var after = info(image_)
	var max_registration = 0.0
	for i in range(before.points.size()):
		max_registration = maxf(max_registration, before.points[i].distance_to(after.points[i]))
	if max_registration > .01 or not before.camera.is_equal_approx(after.camera) or after.face_luminance.any(func(v): return v < .2):
		push_error("Ship art changed camera/registration or obscured a sampled face")
		quit(1)
		return
	print("SHIP ART REVIEW: ", JSON.stringify({"same_runtime_importer_camera_hud_and_held_pose": true, "max_target_registration_change_px": max_registration, "before_face_luminance": before.face_luminance, "after_face_luminance": after.face_luminance, "before_cloth_luminance": before.cloth_luminance, "after_cloth_luminance": after.cloth_luminance, "cloth_sample": before.cloth_sample, "scope": "Actual archived v0.11 GLB vs current GLB via same runtime importer; native 1440x900 HUD view. Small luminance samples test gross visibility, not human recognition or performance."}))
	# Inspect the actual imported asset at three-quarter view, away from actors.
	game.hud.root.hide()
	game.world.gun.hide()
	var world = game.world
	var ship_root: Node3D = world.ship_rig.parts.Sail.get_parent()
	for node in world.get_children():
		if node is Node3D and node != ship_root and not node is Camera3D and not node is Light3D:
			node.hide()
	ship_root.position = Vector3.ZERO
	world.camera.position = Vector3(9.5, 5.3, 15.0)
	world.camera.fov = 40
	world.camera.look_at(Vector3(0, 1.65, 0))
	world.stage_key.position = Vector3(-4, 8, 6)
	world.stage_key.look_at(Vector3(0, 1.7, 0))
	await rendered()
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v12-ship-hero.png"))
	game.free()
	await process_frame
	quit()
