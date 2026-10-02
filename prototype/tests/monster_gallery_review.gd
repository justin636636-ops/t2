extends SceneTree
## Native asset gallery: front, three-quarter, then the same unlit silhouettes.
## This is an art inspection scene, not a gameplay or performance recording.

const WeakpointArt = preload("res://scripts/weakpoint_art.gd")
const ASSETS = ["monster_coral", "monster_mint", "monster_lilac", "monster_honey", "monster_rose"]
var actors: Array[Node3D] = []
var meshes: Array[MeshInstance3D] = []
var baseline = false

func _initialize() -> void:
	run.call_deferred()

func collect(node: Node) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		collect(child)

func render_image() -> Image:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	baseline = "--baseline" in OS.get_cmdline_user_args()
	var prefix = "v22-before-gallery" if baseline else "v22-after-gallery"
	root.size = Vector2i(1600, 900)
	var stage = Node3D.new()
	root.add_child(stage)
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("1c2536")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bacbe0")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.08
	var space = WorldEnvironment.new()
	space.environment = environment
	stage.add_child(space)
	var key = DirectionalLight3D.new()
	key.rotation = Vector3(-0.40, -0.5, 0)
	key.light_color = Color("ffe6c4")
	key.light_energy = 2.2
	stage.add_child(key)
	var fill = DirectionalLight3D.new()
	fill.rotation = Vector3(0.18, 2.6, 0)
	fill.light_color = Color("9bc2df")
	fill.light_energy = 1.1
	stage.add_child(fill)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 8.9
	camera.position = Vector3(0, 0, 9)
	stage.add_child(camera)
	camera.current = true
	# Use the same cached bullseye meshes/materials as the actual target.
	var material_provider = load("res://scripts/world.gd").new()
	for row in range(2):
		for i in range(ASSETS.size()):
			var actor = Node3D.new()
			actor.position = Vector3((i - 2) * 1.78, 1.1 if row == 0 else -1.35, 0)
			actor.rotation.y = 0 if row == 0 else -0.28
			stage.add_child(actor)
			# Both versions use the same runtime GLTF importer for a fair asset
			# comparison. The baseline reads the pre-edit backup, never swaps files.
			var folder = "res://../.art_archive/2026-10-02-v20/models/" if baseline else "res://assets/models/"
			var document = GLTFDocument.new()
			var state = GLTFState.new()
			var error = document.append_from_file(ProjectSettings.globalize_path(folder + ASSETS[i] + ".glb"), state)
			if error != OK:
				push_error("Cannot load art-review model: " + ASSETS[i])
				quit(1)
				return
			var model = document.generate_scene(state)
			actor.add_child(model)
			material_provider.apply_finishes(model)
			WeakpointArt.build(actor, material_provider)
			collect(actor)
			actors.append(actor)
	var image_: Image = await render_image()
	image_.save_png(ProjectSettings.globalize_path("res://artifacts/" + prefix + "-characters.png"))
	var ink = StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color.BLACK
	for mesh in meshes:
		mesh.material_override = ink
	environment.background_color = Color.WHITE
	var silhouette: Image = await render_image()
	silhouette.save_png(ProjectSettings.globalize_path("res://artifacts/" + prefix + "-silhouettes.png"))
	var masks: Array[PackedByteArray] = []
	var measurements: Array = []
	for i in range(5):
		var mask = PackedByteArray()
		var pixels = 0
		var minimum = Vector2i(320, 450)
		var maximum = Vector2i.ZERO
		for y in range(450):
			for x in range(320):
				var solid = silhouette.get_pixel(i * 320 + x, y).r < 0.1
				mask.append(1 if solid else 0)
				if solid:
					pixels += 1
					minimum = Vector2i(mini(minimum.x, x), mini(minimum.y, y))
					maximum = Vector2i(maxi(maximum.x, x), maxi(maximum.y, y))
		masks.append(mask)
		measurements.append({"asset": ASSETS[i], "solid_pixels": pixels, "bounds_px": [minimum.x, minimum.y, maximum.x, maximum.y]})
	var comparisons: Array = []
	for a in range(5):
		for b in range(a + 1, 5):
			var intersection = 0
			var union_ = 0
			for p in range(masks[a].size()):
				intersection += 1 if masks[a][p] and masks[b][p] else 0
				union_ += 1 if masks[a][p] or masks[b][p] else 0
			comparisons.append({"a": ASSETS[a], "b": ASSETS[b], "silhouette_iou": float(intersection) / union_})
	print("MONSTER GALLERY REVIEW: ", JSON.stringify({"baseline": baseline, "measurements": measurements, "comparisons": comparisons, "scope": "native front silhouettes with identical camera, scale, current finishes and runtime GLTF importer; separate asset gallery, no gameplay readability claim"}))
	material_provider.free()
	quit()
