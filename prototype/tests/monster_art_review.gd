extends SceneTree
## Actual five archived/current GLBs through the same runtime importer and world.
const LEGACY = "res://../.art_archive/2026-10-02-v20/models/"
class ReviewWorld extends "res://scripts/world.gd":
	var archived = false
	func model(asset: String,parent: Node3D,pos: Vector3=Vector3.ZERO) -> Node3D:
		if not asset.begins_with("monster_"):return super.model(asset,parent,pos)
		var document = GLTFDocument.new()
		var state = GLTFState.new()
		var folder = "res://../.art_archive/2026-10-02-v20/models/" if archived else "res://assets/models/"
		if document.append_from_file(ProjectSettings.globalize_path(folder+asset+".glb"),state)!=OK:
			push_error("Unable to import original monster artwork")
		var node = document.generate_scene(state)
		node.position = pos
		parent.add_child(node)
		apply_finishes(node)
		return node
var game: Node3D
var camera_before: Transform3D
var points_before: Array = []
var colliders_before: Array = []
var pixels_before: Array = []
var before_draws = 0
func _initialize() -> void:run.call_deferred()
func rendered() -> void:
	for i in range(5):
		await process_frame
		await RenderingServer.frame_post_draw
func snapshot(name_: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v22-"+name_+".png"))
func setup(before: bool) -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound_on = false
	game.world.free()
	var world = ReviewWorld.new()
	world.archived = before
	game.world = world
	game.add_child(world)
	game.start_round()
	world.update_world(1.3,false,1)
	game.hud.update_hud(1.3)
	await rendered()
func collider_description(t: Node3D) -> Dictionary:
	var result = {}
	for key in ["body_hit","weak_hit","shield_hit"]:
		var node = t.get(key)
		if node:result[key]={"position":str(node.position),"size":str(node.get_child(0).shape.size),"layer":node.collision_layer}
	return result
func probes(image_: Image,radius: int=4) -> Array:
	var values = []
	for t in game.world.targets:
		var point = game.world.camera.unproject_position(t.weak_hit.global_position)
		var patch = []
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):patch.append(image_.get_pixel(int(point.x)+x,int(point.y)+y))
		values.append(patch)
	return values
func difference(a: Array,b: Array) -> float:
	var largest = 0.0
	for i in range(a.size()):
		for j in range(a[i].size()):
			largest = maxf(largest,maxf(absf(a[i][j].r-b[i][j].r),maxf(absf(a[i][j].g-b[i][j].g),absf(a[i][j].b-b[i][j].b))))
	return largest
func run() -> void:
	root.size = Vector2i(1440,900)
	await setup(true)
	snapshot("before-monsters")
	camera_before = game.world.camera.global_transform
	before_draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	pixels_before = probes(root.get_texture().get_image())
	for t in game.world.targets:
		points_before.append(game.world.camera.unproject_position(t.weak_hit.global_position))
		colliders_before.append(collider_description(t))
	game.free()
	await process_frame
	await setup(false)
	snapshot("after-monsters")
	var world = game.world
	var draws = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var changed_pixels = difference(pixels_before,probes(root.get_texture().get_image()))
	var registration = 0.0
	var collider_changes = 0
	var face_parents = true
	for t in world.targets:
		registration = maxf(registration,points_before[t.index].distance_to(world.camera.unproject_position(t.weak_hit.global_position)))
		if colliders_before[t.index]!=collider_description(t):collider_changes+=1
		if t.kind=="balloon":face_parents = face_parents and t.rig.parts.Pupil_L.get_parent()==t.rig.parts.Eye_L and t.rig.parts.Pupil_R.get_parent()==t.rig.parts.Eye_R
	# The 9x9 contextual patch includes the gaps between target rings, where the
	# shell is intentionally the visible background. Only probe the filled core
	# for geometry occlusion when hiding the model; compare all 9x9 pixels old/new.
	var visible = probes(root.get_texture().get_image(),1)
	for t in world.targets.slice(0,5):t.body_visual.get_child(0).hide()
	await rendered()
	var hidden_difference = difference(visible,probes(root.get_texture().get_image(),1))
	for t in world.targets.slice(0,5):t.body_visual.get_child(0).show()
	await rendered()
	print("MONSTER ART REVIEW: ",JSON.stringify({"actual_archived_five_glbs":true,"same_runtime_importer_world_finishes":true,"camera_stable":camera_before.is_equal_approx(world.camera.global_transform),"max_target_registration_change_px":registration,"collider_definition_changes":collider_changes,"eyes_parented":face_parents,"before_held_draws":before_draws,"after_held_draws":draws,"before_after_weakpoint_9x9_max_channel_difference":changed_pixels,"hidden_monster_weakpoint_core_3x3_max_channel_difference":hidden_difference,"scope":"Same current unchanged world/target/shaders, native 1440x900 fixed 1.3s pose. Actual archived five GLBs or current five through same runtime importer, no file swapping. Nine 9x9 old/new context patches and 3x3 filled-core model-hide probes, not all aim/airborne states or human recognition."}))
	if registration>.01 or collider_changes!=0 or not face_parents or not camera_before.is_equal_approx(world.camera.global_transform) or hidden_difference>.01:
		push_error("Monster art review failed registration, parenting or weakpoint occlusion")
		quit(1)
		return
	game.free()
	await process_frame
	quit()
