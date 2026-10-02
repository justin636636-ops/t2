extends Node3D

signal carpet_bounced

const Target = preload("res://scripts/target.gd")
const Vfx = preload("res://scripts/vfx.gd")
const ToyRig = preload("res://scripts/toy_rig.gd")
const ArtFonts = preload("res://scripts/art_fonts.gd")
const StageAir = preload("res://scripts/stage_air.gd")
const StageShow = preload("res://scripts/stage_show.gd")
const StageLighting = preload("res://scripts/stage_lighting.gd")
const StageBackdrop = preload("res://scripts/stage_backdrop.gd")
const AttractionArt = preload("res://scripts/attraction_art.gd")
const BellArt = preload("res://scripts/bell_art.gd")
const CREAM = Color("f3e3b8")
const WOOD = Color("714744")
const DARK = Color("30243e")
const MINT = Color("85d2bc")
const CORAL = Color("e87f79")
const STAGE_LIGHT_ENERGY = 6.2
# Lowest webbed-foot vertex and the imported velvet cushion top.
const DUCK_FOOT_DEPTH = 0.265
const DUCK_CUSHION_TOP = 0.09
const WEAPON_HOME = Vector3(1.08, -0.30, -2.65)
const WEAPON_SCALE = 0.66

var camera: Camera3D
var targets: Array = []
var bell: StaticBody3D
var bell_mesh: Node3D
var bell_label: Label3D
var duck: Node3D
var duck_label: Label3D
var carpet: Node3D
var gun: Node3D
var recoil = 0.0
var material_cache: Dictionary = {}
var carpet_enabled = true
var time = 0.0
var bell_cooldown = 0.0
var duck_flash = 0.0
var effects: Array = []
var vfx: Node3D
var visual_clock = 0.0
var duck_rig = ToyRig.new()
var gun_rig = ToyRig.new()
var stage_rig = ToyRig.new()
var ship_rig = ToyRig.new()
var carpet_pads: Array = []
var fabric_materials: Array = []
var stage_age = 1.0
var finale_age = -1.0
var finale_won = false
var duck_growth = 0.0
var duck_key_angle = 0.0
var duck_help_direction = Vector2.ZERO
var current_duck_level = 0
var gun_cycle = 1.0
var gun_step = 0
var gun_reload = 1.0
var gun_aim = Vector2.ZERO
var gun_focus = Vector3(0, 2.7, -5)
var gun_follow = Quaternion.IDENTITY
var reduced_motion = false
var wheel: Node3D
var foreground: Node3D
var stage_air: Node3D
var stage_show: Node3D
var stage_lighting: Node3D
var stage_backdrop: Node3D
var attraction_art: Node3D
var award_cart: Node3D
var award_plinth: Node3D
var award_lift: MeshInstance3D
var award_collar: MeshInstance3D
var prize_light: OmniLight3D
var stage_key: SpotLight3D
var world_font: Font
var world_number_font: Font

func _ready() -> void:
	world_font = ArtFonts.get_font()
	world_number_font = ArtFonts.get_font("number")
	build_world()
	# Populate the exact floating-score glyph size during the title page.
	var warm_number = label3(self, "+0123456789", Vector3(0, 3, -3), 52, Color(1, 1, 1, 0.001), 0.009, world_number_font)
	warm_number.no_depth_test = true
	effects.append({"node": warm_number, "life": 0.12, "kind": "warmup"})
	var warm_caption = label3(self, "弱点 空中靶心 空中击破 击破 翻盖 破盾", Vector3(0, 3, -3), 23, Color(1, 1, 1, 0.001), 0.007)
	effects.append({"node": warm_caption, "life": 0.12, "kind": "warmup"})

func mat(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key = str(color) + str(emission)
	if material_cache.has(key):
		return material_cache[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	if color in [Color("c7a363"), Color("b89566"), Color("9e7849")]:
		m.metallic = 0.6
		m.roughness = 0.32
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	material_cache[key] = m
	return m

func mesh(parent: Node3D, geometry: Mesh, pos: Vector3, color: Color, emission: float = 0) -> MeshInstance3D:
	var item = MeshInstance3D.new()
	item.mesh = geometry
	item.position = pos
	item.material_override = mat(color, emission)
	parent.add_child(item)
	return item

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, color)

func sphere(parent: Node3D, pos: Vector3, radius: float, color: Color, scale_ = Vector3.ONE, emission: float = 0) -> MeshInstance3D:
	var shape = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 20
	shape.rings = 10
	var item = mesh(parent, shape, pos, color, emission)
	item.scale = scale_
	return item

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = -1) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.top_radius = radius if top < 0 else top
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 24
	return mesh(parent, shape, pos, color)

func ring(parent: Node3D, pos: Vector3, radius: float, thickness: float, color: Color) -> MeshInstance3D:
	var shape = TorusMesh.new()
	shape.inner_radius = radius - thickness
	shape.outer_radius = radius
	shape.rings = 32
	shape.ring_segments = 8
	return mesh(parent, shape, pos, color)

func line_between(parent: Node3D, a: Vector3, b: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var item = cylinder(parent, (a + b) * 0.5, radius, a.distance_to(b), color)
	var direction = (b - a).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		item.quaternion = Quaternion(Vector3.UP, direction)
	return item

func label3(parent: Node3D, text: String, pos: Vector3, size: int, color: Color, pixel_size: float = 0.005, font_override: Font = null) -> Label3D:
	var l = Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = pixel_size
	l.modulate = color
	l.outline_size = 6
	l.outline_modulate = DARK
	l.no_depth_test = false
	l.font = font_override if font_override else world_font
	parent.add_child(l)
	return l

func collider(parent: Node3D, size: Vector3, pos: Vector3, layer: int = 2) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = pos
	parent.add_child(body)
	var shape = CollisionShape3D.new()
	var geometry = BoxShape3D.new()
	geometry.size = size
	shape.shape = geometry
	body.add_child(shape)
	return body

func model(asset: String, parent: Node3D, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var packed: PackedScene = load("res://assets/models/" + asset + ".glb")
	var node: Node3D = packed.instantiate()
	node.position = pos
	parent.add_child(node)
	apply_finishes(node)
	return node

func apply_finishes(node: Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var original = node.mesh.surface_get_material(i)
			if original is StandardMaterial3D:
				var name_ = original.resource_name
				if name_ in ["wood_planks", "carved_mahogany", "wine_velvet", "velvet_shadow", "aged_brass", "antique_gold", "revolver_brass", "duck_brass", "crew_brass"]:
					var key = "finish_" + name_
					if not material_cache.has(key):
						var finish = ShaderMaterial.new()
						finish.shader = load("res://assets/shaders/crafted_surface.gdshader")
						finish.set_shader_parameter("tint", original.albedo_color)
						finish.set_shader_parameter("base_roughness", original.roughness)
						finish.set_shader_parameter("metalness", original.metallic)
						finish.set_shader_parameter("finish_mode", 1.0 if "velvet" in name_ else (2.0 if "brass" in name_ or "gold" in name_ else 0.0))
						material_cache[key] = finish
					node.set_surface_override_material(i, material_cache[key])
				elif name_.begins_with("crew_") and name_.ends_with("_wood"):
					if not material_cache.has(name_):
						var finish = ShaderMaterial.new()
						finish.shader = preload("res://assets/shaders/crew_painted_wood.gdshader")
						finish.set_shader_parameter("tint", original.albedo_color)
						finish.set_shader_parameter("base_roughness", original.roughness)
						material_cache[name_] = finish
					node.set_surface_override_material(i, material_cache[name_])
				elif name_ == "worker_canvas":
					if not material_cache.has(name_):
						var finish = ShaderMaterial.new()
						finish.shader = preload("res://assets/shaders/worker_canvas.gdshader")
						finish.set_shader_parameter("tint", original.albedo_color)
						finish.set_shader_parameter("base_roughness", original.roughness)
						material_cache[name_] = finish
					node.set_surface_override_material(i, material_cache[name_])
				elif "enamel" in name_ or "lacquer" in name_:
					var key = "lacquer_" + name_
					if not material_cache.has(key):
						var finish = ShaderMaterial.new()
						finish.shader = preload("res://assets/shaders/lacquer_surface.gdshader")
						finish.set_shader_parameter("tint", original.albedo_color)
						finish.set_shader_parameter("base_roughness", original.roughness)
						material_cache[key] = finish
					node.set_surface_override_material(i, material_cache[key])
	for child in node.get_children():
		apply_finishes(child)

func prepare_fabric(node: Node, top: float, bottom: float, amplitude: float, tailored: bool = false) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var original: Material = node.get_active_material(i)
			var key = "fabric_%s_%s" % [original.get_instance_id(), top]
			if not material_cache.has(key):
				var fabric = ShaderMaterial.new()
				fabric.shader = preload("res://assets/shaders/sail_surface.gdshader") if tailored else preload("res://assets/shaders/fabric_surface.gdshader")
				if original is ShaderMaterial:
					for parameter in ["tint", "base_roughness", "metalness", "finish_mode"]:
						fabric.set_shader_parameter(parameter, original.get_shader_parameter(parameter))
				elif original is StandardMaterial3D:
					fabric.set_shader_parameter("tint", original.albedo_color)
					fabric.set_shader_parameter("base_roughness", original.roughness)
					fabric.set_shader_parameter("metalness", original.metallic)
					fabric.set_shader_parameter("finish_mode", 1.0)
				fabric.set_shader_parameter("fabric_top", top)
				fabric.set_shader_parameter("fabric_bottom", bottom)
				material_cache[key] = fabric
				fabric_materials.append({"material": fabric, "amplitude": amplitude})
			node.set_surface_override_material(i, material_cache[key])
	for child in node.get_children():
		prepare_fabric(child, top, bottom, amplitude, tailored)

func build_world() -> void:
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("090f22")
	sky_mat.sky_horizon_color = Color("372943")
	sky_mat.ground_bottom_color = Color("14152b")
	sky_mat.ground_horizon_color = Color("372943")
	sky_mat.sky_energy_multiplier = 0.65
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.08
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.3
	env.ssao_enabled = true
	env.ssao_radius = 0.75
	env.ssao_intensity = 1.2
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 22
	env.fog_depth_end = 70
	env.fog_light_color = Color("242339")
	environment.environment = env
	add_child(environment)
	var moonlight = DirectionalLight3D.new()
	moonlight.rotation_degrees = Vector3(-35, -35, 0)
	moonlight.light_color = Color("a9b9e7")
	moonlight.light_energy = 0.65
	# The warm stage key supplies the readable cast shadow. Four extra moon
	# cascades on distant ornaments add cost without improving target reading.
	moonlight.shadow_enabled = false
	add_child(moonlight)
	var key = SpotLight3D.new()
	stage_key = key
	key.position = Vector3(-4, 8, 4)
	key.light_color = Color("ffe3b0")
	key.light_energy = STAGE_LIGHT_ENERGY
	key.spot_range = 30
	key.spot_angle = 55
	key.spot_attenuation = 0.35
	key.shadow_enabled = true
	add_child(key)
	key.look_at(Vector3(0, 3, -5))
	var face_fill = OmniLight3D.new()
	face_fill.position = Vector3(3, 4, 0)
	face_fill.light_color = Color("ffd5a5")
	face_fill.light_energy = 1.4
	face_fill.omni_range = 15
	add_child(face_fill)
	var rim_light = OmniLight3D.new()
	rim_light.position = Vector3(0, 5.5, -8)
	rim_light.light_color = Color("71cbbc")
	rim_light.light_energy = 4.5
	rim_light.omni_range = 13
	add_child(rim_light)
	camera = Camera3D.new()
	camera.position = Vector3(0, 3.5, 10)
	camera.fov = 57
	camera.far = 90
	add_child(camera)
	camera.look_at(Vector3(0, 2.7, -5))
	camera.current = true
	vfx = Vfx.new()
	vfx.camera = camera
	add_child(vfx)
	# Sculpted GLB assets carry the silhouettes; imported PBR finishes carry detail.
	stage_rig.collect(model("carnival_booth", self))
	stage_backdrop = StageBackdrop.new()
	add_child(stage_backdrop)
	ship_rig.collect(model("pirate_ship", self, Vector3(0, 2.6, -9)))
	for part in ["Curtain_L", "Curtain_R"]:
		prepare_fabric(stage_rig.parts[part], 6.66, 1.74, 0.045)
	prepare_fabric(ship_rig.parts.Sail, 7.15, 4.9, 0.055, true)
	var ground = box(self, Vector3(0, -0.25, -6), Vector3(90, 0.5, 80), Color("17272a"))
	var paving = ShaderMaterial.new()
	paving.shader = preload("res://assets/shaders/courtyard_surface.gdshader")
	paving.set_shader_parameter("tint", Color("17272a"))
	ground.material_override = paving
	var rng = RandomNumberGenerator.new()
	rng.seed = 301001
	var stars = MultiMeshInstance3D.new()
	var star_mesh = SphereMesh.new()
	star_mesh.radius = 1
	star_mesh.height = 2
	star_mesh.radial_segments = 6
	star_mesh.rings = 3
	var star_instances = MultiMesh.new()
	star_instances.transform_format = MultiMesh.TRANSFORM_3D
	star_instances.mesh = star_mesh
	star_instances.instance_count = 120
	for i in range(120):
		var pos = Vector3(rng.randf_range(-45, 45), rng.randf_range(9, 28), -45)
		var radius = rng.randf_range(0.025, 0.06)
		star_instances.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * radius), pos))
	stars.multimesh = star_instances
	stars.material_override = mat(CREAM, 2)
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)
	var park_moon = sphere(self, Vector3(-22, 22, -43), 1.2, Color("b8c7e4"), Vector3(1, 1, 0.12))
	var moon_paint = ShaderMaterial.new()
	moon_paint.shader = preload("res://assets/shaders/painted_moon.gdshader")
	park_moon.material_override = moon_paint
	# Distant park rides are atmospheric silhouettes, well behind the shootable bell.
	wheel = Node3D.new()
	wheel.position = Vector3(16, 6, -26)
	add_child(wheel)
	var rim = ring(wheel, Vector3.ZERO, 4.5, 0.055, Color("494959"))
	rim.rotation_degrees.x = 90
	for i in range(14):
		var p = Vector3(sin(i * TAU / 14) * 4.5, cos(i * TAU / 14) * 4.5, 0)
		line_between(wheel, Vector3.ZERO, p, 0.025, Color("393d51"))
		box(wheel, p + Vector3(0, -0.30, 0), Vector3(0.5, 0.43, 0.5), Color("343944"))
		sphere(wheel, p, 0.06, Color("d9a477"), Vector3.ONE, 2)
	for x in [12.5, 19.5]:
		line_between(self, Vector3(x, 0, -26), wheel.position, 0.10, Color("303440"))
	for side in [-1, 1]:
		var tent = cylinder(self, Vector3(side * 21, 3, -22), 3.2, 3.0, Color("462637"), 0)
		box(self, Vector3(side * 21, 0.8, -22), Vector3(6, 1.6, 5), Color("242839"))
		cylinder(self, Vector3(side * 21, 4.7, -22), 0.07, 1.8, WOOD)
	# Original gold sign embedded in the attraction, not a second app header.
	attraction_art = AttractionArt.new()
	add_child(attraction_art)
	# Amber practical lights emphasize the frame and give a real source for warm light.
	stage_show = StageShow.new()
	add_child(stage_show)
	var practical_lamps: Array[OmniLight3D] = []
	for x in [-8.4, 8.4]:
		var lamp = OmniLight3D.new()
		lamp.position = Vector3(x, 5.4, -3)
		lamp.light_color = Color("ffad69")
		lamp.light_energy = 1.2
		lamp.omni_range = 6
		add_child(lamp)
		practical_lamps.append(lamp)
	stage_air = StageAir.new()
	add_child(stage_air)
	stage_lighting = StageLighting.new()
	stage_lighting.fill = face_fill
	stage_lighting.rim = rim_light
	stage_lighting.backdrop = stage_backdrop
	stage_lighting.air = stage_air
	# Reuse the two established warm practical lamps, no new dynamic lights.
	stage_lighting.frame_lamps = practical_lamps
	add_child(stage_lighting)
	# Carpet remains a real bounded landing area with springs instead of painted hints.
	carpet = Node3D.new()
	add_child(carpet)
	for x in range(-7, 8):
		var pad = model("spring_pad", carpet, Vector3(x, 1.70, -3))
		carpet_pads.append({"node": pad, "age": 1.0})
	# Bell framed by a carved pedestal, with its own clear highlight.
	# Lift the actual mechanism and its unchanged hit volume clear of front-row ears.
	bell = collider(self, Vector3(0.9, 1.1, 0.65), Vector3(6.9, 4.35, -5), 1)
	bell.set_meta("mechanism", true)
	bell_mesh = BellArt.new()
	bell.add_child(bell_mesh)
	bell_label = label3(bell, "铃铛", Vector3(0, 0.9, 0.15), 29, CREAM, 0.008)
	var bell_light = OmniLight3D.new()
	bell_light.position = Vector3(6.9, 4.4, -3)
	bell_light.light_color = Color("ffd494")
	bell_light.light_energy = 1.5
	bell_light.omni_range = 3
	add_child(bell_light)
	stage_lighting.bell = bell_light
	stage_lighting.reset_show(reduced_motion)
	for i in range(9):
		var target = Target.new()
		target.index = i
		target.kind = "balloon" if i < 5 else "pirate"
		target.base_position = Vector3(-6.2 + i * 3.1, 2.7, -3.0) if i < 5 else Vector3(-4.9 + (i - 5) * 2.8, 3.7, -6.0)
		target.world = self
		add_child(target)
		targets.append(target)
	# Walnut desk, engraved inlay, lacquered revolver and a proper wind-up sculpture.
	foreground = Node3D.new()
	add_child(foreground)
	box(foreground, Vector3(0, 0.92, 7), Vector3(8.2, 0.2, 2), Color("382a24"))
	box(foreground, Vector3(0, 1.03, 6.8), Vector3(8.3, 0.07, 2.1), Color("78543a"))
	gun = Node3D.new()
	gun.position = WEAPON_HOME
	gun.scale = Vector3.ONE * WEAPON_SCALE
	camera.add_child(gun)
	model("revolver", gun)
	gun_rig.collect(gun)
	for visual in gun_rig.meshes:
		visual.layers = 4
	# A viewmodel-only soft fill reads the cloth and inlay without lighting targets.
	var weapon_fill = SpotLight3D.new()
	weapon_fill.name = "WeaponFill"
	gun.add_child(weapon_fill)
	weapon_fill.position = Vector3(-0.8, 0.9, 0.65)
	weapon_fill.look_at(gun.to_global(Vector3(0, -0.12, -0.1)))
	weapon_fill.light_color = Color("e4d5b8")
	weapon_fill.light_energy = 0.65
	weapon_fill.spot_range = 2.8
	weapon_fill.spot_angle = 48
	weapon_fill.spot_attenuation = 0.55
	weapon_fill.light_cull_mask = 4
	award_cart = Node3D.new()
	award_cart.position = Vector3(-0.8, 1.035, 5.8)
	foreground.add_child(award_cart)
	award_plinth = model("prize_plinth", award_cart, Vector3(0, 0.815, 0))
	award_lift = cylinder(award_cart, Vector3.ZERO, 0.085, 1.0, Color("c7a363"))
	award_collar = cylinder(award_cart, Vector3(0, 0.045, 0), 0.145, 0.10, Color("9e7849"))
	award_lift.visible = false
	award_collar.visible = false
	duck = Node3D.new()
	duck.position = Vector3(0, 0.815 + DUCK_CUSHION_TOP + DUCK_FOOT_DEPTH, 0)
	award_cart.add_child(duck)
	model("duck", duck)
	duck_rig.collect(duck)
	duck_label = label3(duck, "", Vector3(0, 0.63, 0), 24, CREAM, 0.004)
	set_duck_level(0)
	prize_light = OmniLight3D.new()
	prize_light.position = Vector3(-1, 3, 7)
	prize_light.light_color = Color("ffd696")
	prize_light.light_energy = 1.2
	prize_light.omni_range = 4
	add_child(prize_light)
	collider(self, Vector3(18, 8, 0.3), Vector3(0, 4, -10), 2)
	collider(self, Vector3(18, 1.6, 8), Vector3(0, 0.8, -5.2), 2)

func update_world(delta: float, moving: bool, group: int, presentation: bool = true) -> void:
	if not presentation:
		return
	visual_clock += delta
	stage_air.advance(visual_clock, reduced_motion)
	stage_show.advance(delta, reduced_motion)
	stage_lighting.advance(delta, reduced_motion)
	animate_stage(delta)
	gun_cycle += delta
	gun_reload += delta
	recoil = maxf(0, recoil - delta * 5)
	animate_gun(delta)
	for i in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[i]
		effect.life -= delta
		if effect.life <= 0:
			effect.node.queue_free()
			effects.remove_at(i)
		elif effect.kind == "popup":
			effect.node.position.y += delta * 0.55
			effect.node.modulate.a = minf(1, effect.life / 0.22)
		elif effect.kind == "score":
			effect.age += delta
			effect.node.position.y += delta * 0.60
			effect.node.scale = Vector3.ONE * (1 + sin(clampf(effect.age / 0.18, 0, 1) * PI) * 0.13)
			for child in effect.node.get_children():
				child.modulate.a = minf(1, effect.life / 0.25)
	duck_flash = maxf(0, duck_flash - delta)
	duck_growth = maxf(0, duck_growth - delta)
	animate_duck(delta)
	bell_mesh.advance(delta, reduced_motion)
	if not reduced_motion:
		wheel.rotation.z += delta * 0.025
	if not moving:
		for target in targets:
			target.animate(delta, visual_clock)
		vfx.advance(delta)
		return
	time += delta
	bell_cooldown = maxf(0, bell_cooldown - delta)
	for target in targets:
		target.advance(delta, time, group, carpet_enabled)
		target.animate(delta, visual_clock)
	# Cosmetic links consume the drawn target pose, including this tick's lift.
	vfx.advance(delta)

func animate_stage(delta: float) -> void:
	var motion = 0.0 if reduced_motion else 1.0
	for fabric in fabric_materials:
		fabric.material.set_shader_parameter("fabric_clock", visual_clock)
		fabric.material.set_shader_parameter("flutter_power", fabric.amplitude * motion)
	stage_age = minf(1.0, stage_age + delta)
	if finale_age >= 0:
		finale_age += delta
	var opening = sin(clampf(stage_age / 0.9, 0, 1) * PI) * 0.25 * motion
	# Everything is decorative, hung at authored pivots away from the bell and targets.
	for side in [-1, 1]:
		var part = "Curtain_L" if side < 0 else "Curtain_R"
		stage_rig.turn(part, Vector3(sin(visual_clock * 0.85 + side) * 0.006, 0, side * sin(visual_clock * 0.65) * 0.006) * motion)
		if stage_rig.parts.has(part):
			stage_rig.parts[part].position.x = side * (7.58 + opening)
	ship_rig.turn("Sail", Vector3(sin(visual_clock * 0.75) * 0.022, sin(visual_clock * 0.65) * 0.008, 0) * motion)
	ship_rig.turn("Pennant", Vector3(0, sin(visual_clock * 1.8) * 0.065, sin(visual_clock * 1.1) * 0.018) * motion)
	for pad in carpet_pads:
		pad.age = minf(1.0, pad.age + delta)
		var pulse = sin(clampf(pad.age / 0.40, 0, 1) * TAU) * exp(-pad.age * 7)
		pad.node.position.y = 1.70 - maxf(0, pulse) * 0.075 * motion
		pad.node.scale.y = 1.0 - pulse * 0.23 * motion

func carpet_rebound(landing: Vector3) -> void:
	var tile = clampi(roundi(landing.x) + 7, 0, carpet_pads.size() - 1)
	carpet_pads[tile].age = 0.0
	vfx.spring(Vector3(landing.x, 1.88, landing.z), true)
	carpet_bounced.emit()

func open_stage() -> void:
	stage_age = 0.0
	finale_age = -1.0
	stage_show.open()
	stage_lighting.open(reduced_motion)

func finish_stage(won: bool) -> void:
	finale_age = 0.0
	finale_won = won
	stage_show.finish(won)
	stage_lighting.finish(won, reduced_motion)
	if reduced_motion:
		animate_award(0)
	vfx.celebrate(won)

func animate_duck(delta: float) -> void:
	# The same pausable clock drives the assembled toy; gameplay remains in bell.
	var motion = 0.2 if reduced_motion else 1.0
	var help = sin(clampf((0.8 - duck_flash) / 0.8, 0, 1) * PI) if duck_flash > 0 else 0.0
	var growth = sin(clampf((0.65 - duck_growth) / 0.65, 0, 1) * PI) if duck_growth > 0 else 0.0
	var win = sin(clampf(finale_age / 1.4, 0, 1) * PI) if finale_age >= 0 and finale_won else 0.0
	var loss = sin(clampf(finale_age / 1.2, 0, 1) * PI) if finale_age >= 0 and not finale_won else 0.0
	var active = maxf(help, maxf(growth, win)) * motion
	duck.rotation = Vector3(0, sin(visual_clock * 0.8) * 0.045 * (0.0 if reduced_motion else 1.0), sin((0.8 - duck_flash) * TAU / 0.8) * help * 0.025 * motion)
	animate_award(help * motion)
	# One shoulder glance toward the actual assisted pirate, one proud nod on
	# growing/winning, then a settled face. Nothing waits for this flourish.
	duck_rig.turn("Duck_Head", Vector3((duck_help_direction.y * help - growth * 0.10 - win * 0.14 + loss * 0.16) * motion, duck_help_direction.x * help * motion, -growth * 0.06 * motion))
	duck_rig.turn("Duck_Beak", Vector3((help * 0.19 + growth * 0.12 + win * 0.15) * motion, 0, 0))
	var blink = 1.0
	if not reduced_motion and duck_flash <= 0 and duck_growth <= 0 and finale_age < 0:
		var phase = fmod(visual_clock + 1.1, 6.3)
		if phase < 0.16:
			blink = 1.0 - sin(phase / 0.16 * PI) * 0.94
	for part in ["Duck_Eye_L", "Duck_Eye_R"]:
		if duck_rig.parts.has(part):
			duck_rig.parts[part].scale.y = blink
			duck_rig.parts[part].position = duck_rig.rests[part].origin + Vector3(duck_help_direction.x * help * 0.007 * motion, 0, 0)
	if not reduced_motion:
		duck_key_angle += delta * (0.14 + help * 7.0 + growth * 4.0 + win * 1.5)
	duck_rig.turn("Key", Vector3(duck_key_angle, 0, 0))
	duck_rig.turn("Wing_L", Vector3(0, sin((0.8 - duck_flash) * TAU / 0.8) * help * 0.16 * motion, -active * 0.20))
	duck_rig.turn("Wing_R", Vector3(0, -sin((0.8 - duck_flash) * TAU / 0.8) * help * 0.16 * motion, active * 0.20))
	duck_rig.turn("Upgrade_1", Vector3(-help * 0.16 * motion, -help * 0.12 * motion, 0))

func animate_award(active: float) -> void:
	var won = finale_age >= 0 and finale_won
	var p = (1.0 if reduced_motion else clampf(finale_age / 1.05, 0, 1)) if finale_age >= 0 else 0.0
	var ease = p * p * (3.0 - 2.0 * p)
	award_cart.position = Vector3(-0.8, 1.035, 5.8).lerp(Vector3(1.7 if won else 0.9, 1.035, 6.35), ease)
	award_cart.rotation.y = -0.26 * ease
	var lift = 0.72 * ease if won else 0.0
	award_plinth.position.y = 0.815 + lift
	award_lift.visible = won
	award_collar.visible = won
	var stem = maxf(0.03, lift - 0.025)
	award_lift.scale.y = stem
	award_lift.position.y = stem / 2 - 0.01
	var hero_size = 1.0 + 0.65 * ease if won else 1.0
	award_plinth.scale = Vector3(hero_size, 1, hero_size)
	duck.scale = Vector3.ONE * hero_size * (1 + sin(duck_growth / 0.65 * PI) * (0.0 if reduced_motion else 0.07))
	duck.position.y = award_plinth.position.y + DUCK_CUSHION_TOP + DUCK_FOOT_DEPTH * duck.scale.y + (absf(sin(visual_clock * 12)) * 0.08 * active if not reduced_motion else 0.0)
	prize_light.position = award_cart.position + Vector3(-0.2, 2.0 + lift, 1.2)
	prize_light.light_energy = 1.2 + ease * 0.7 if won else 1.2
	var loss = finale_age >= 0 and not finale_won
	stage_key.light_energy = STAGE_LIGHT_ENERGY * (lerpf(1.0, 0.82, 1.0 if reduced_motion else clampf(finale_age / 0.8, 0, 1)) if loss else 1.0)

func animate_gun(delta: float = 0.0, snap: bool = false) -> void:
	var kick = recoil * recoil * (0.35 if reduced_motion else 1.0)
	var sway = 0.0 if reduced_motion else 1.0
	var reload_dip = sin(clampf(gun_reload / 0.32, 0, 1) * PI) * (0.4 if reduced_motion else 1.0)
	gun.position = WEAPON_HOME + Vector3(gun_aim.x * 0.045 * sway, (sin(visual_clock * 1.6) * 0.008 + gun_aim.y * 0.028) * sway - reload_dip * 0.15, kick * 0.22 + reload_dip * 0.12)
	# Converge the barrel (including its authored vertical offset) on the same
	# world point as the hitscan. The camera and target colliders never move.
	var local_focus = camera.to_local(gun_focus)
	var direction = local_focus - gun.position
	if direction.z < -0.1:
		var desired = Basis.looking_at(direction.normalized(), Vector3.UP).get_rotation_quaternion()
		var muzzle_offset = Basis(desired) * Vector3(0, 0.035 * WEAPON_SCALE, 0)
		desired = Basis.looking_at((direction - muzzle_offset).normalized(), Vector3.UP).get_rotation_quaternion()
		gun_follow = desired if snap or reduced_motion else gun_follow.slerp(desired, 1.0 - exp(-delta * 22.0))
	gun.quaternion = gun_follow * Quaternion.from_euler(Vector3(kick * 0.16 + reload_dip * 0.13, 0, -kick * 0.06))
	gun_rig.turn("Cylinder", Vector3(0, 0, -maxf(0, gun_step - 1 + minf(gun_cycle / 0.18, 1)) * TAU / 5))
	gun_rig.turn("Hammer", Vector3(-sin(clampf(gun_cycle / 0.22, 0, 1) * PI) * 0.45, 0, 0))
	gun_rig.turn("Trigger", Vector3(-exp(-gun_cycle * 24.0) * 0.24, 0, 0))
	gun_rig.turn("Index_Finger", Vector3(-exp(-gun_cycle * 24.0) * (0.025 if reduced_motion else 0.055), 0, 0))

func reload_weapon() -> void:
	gun_reload = 0

func reset_world() -> void:
	time = 0
	bell_cooldown = 0
	bell_mesh.reset()
	duck_flash = 0
	duck_growth = 0
	duck_key_angle = 0
	duck_help_direction = Vector2.ZERO
	duck.rotation = Vector3.ZERO
	duck_rig.reset()
	recoil = 0
	gun_cycle = 1
	gun_step = 0
	gun_reload = 1
	gun_follow = Quaternion.IDENTITY
	gun_focus = Vector3(0, 2.7, -5)
	gun_rig.reset()
	animate_gun(0, true)
	stage_age = 1.0
	finale_age = -1.0
	stage_show.reset_show()
	stage_lighting.reset_show(reduced_motion)
	animate_award(0)
	stage_rig.reset()
	for pad in carpet_pads:
		pad.age = 1.0
		pad.node.position.y = 1.70
		pad.node.scale = Vector3.ONE
	vfx.clear()
	for effect in effects:
		effect.node.queue_free()
	effects.clear()
	for target in targets:
		target.reset_target()

func begin_group() -> void:
	stage_show.next_group()
	stage_lighting.next_group(reduced_motion)
	# Previous-group score labels must not look like rewards from the new group.
	for effect in effects:
		effect.node.queue_free()
	effects.clear()
	for target in targets:
		target.carpet_used = false
		target.preparation_group = -1
		target.preparation_shot = -1

func activate_bell(group: int, shot: int, level: int) -> Array:
	if bell_cooldown > 0:
		return []
	var affected: Array = []
	for target in targets:
		if target.kind == "pirate" and target.alive and target.exposed <= 0:
			target.exposed = 3.0
			target.preparation_group = group
			target.preparation_shot = shot
			affected.append(target)
	if affected.is_empty():
		return []
	bell_cooldown = 3.2
	bell_mesh.ring_bell()
	stage_show.ring_bell()
	stage_lighting.ring_bell()
	if level > 0:
		duck_flash = 0.8
		var target = affected[0]
		var direction: Vector3 = target.global_position - duck.global_position
		duck_help_direction = Vector2(clampf(atan2(direction.x, absf(direction.z)), -0.38, 0.38), -clampf(atan2(direction.y, Vector2(direction.x, direction.z).length()), 0.08, 0.24))
		if level == 3:
			target.launch(group, shot)
		else:
			target.held = 0.8
			if level >= 2:
				target.exposed = maxf(target.exposed, 3.0)
		popup(target.global_position + Vector3(0, 0.8, 0), "鸭子弹射！" if level == 3 else "鸭子牵住 · 0.8 秒", MINT)
		vfx.duck_help(duck.global_position, target, level)
	for target in affected:
		target.sync_visuals()
	return affected

func popup(pos: Vector3, text: String, color: Color = CREAM, lifetime: float = 1.0) -> void:
	if effects.size() >= 16:
		effects.pop_front().node.queue_free()
	var node = label3(self, text, pos + Vector3(0, 0.80, 0.45), 34, color, 0.008)
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = true
	effects.append({"node": node, "life": lifetime, "kind": "popup"})

func score_popup(pos: Vector3, points: int, caption: String, aerial: bool = false) -> void:
	if effects.size() >= 16:
		effects.pop_front().node.queue_free()
	var node = Node3D.new()
	node.position = pos + Vector3(0, 0.82, 0.45)
	add_child(node)
	var number = label3(node, "+%d" % points, Vector3.ZERO, 52, MINT if aerial else CREAM, 0.009, world_number_font)
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.no_depth_test = true
	var subtitle = label3(node, caption, Vector3(0, -0.28, 0), 23, CREAM, 0.007)
	subtitle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	subtitle.no_depth_test = true
	effects.append({"node": node, "life": 0.95, "age": 0.0, "kind": "score"})

func react_to_shot(record: Dictionary, hit: Vector3) -> void:
	if not record.valid or record.target < 0 or reduced_motion or finale_age >= 0:
		return
	var available: Array = []
	var active = 0
	for target in targets:
		if target.alive and target.attention_age < target.ATTENTION_DURATION:
			active += 1
		if target.index != record.target and target.alive and not target.airborne and target.held <= 0 and target.attention_cooldown <= 0 and target.global_position.distance_to(hit) < 6.0:
			available.append(target)
	available.sort_custom(func(a, b): return a.global_position.distance_squared_to(hit) < b.global_position.distance_squared_to(hit))
	var strength = 1.0 if record.weak else (0.82 if record.destroyed else 0.65)
	for i in range(mini(maxi(0, 2 - active), available.size())):
		available[i].observe_shot(hit, strength, 0.04 + i * 0.06)

func shot_effect(hit: Vector3, spring_ammo: bool = false) -> void:
	gun_focus = hit
	gun_reload = 1
	recoil = 0
	animate_gun(0.0, true)
	vfx.shot(gun, hit, spring_ammo)
	recoil = 1.0
	gun_cycle = 0
	gun_step += 1
	animate_gun()

func set_duck_level(level: int) -> void:
	if level > current_duck_level:
		duck_growth = 0.65
		vfx.glyph(duck.global_position + Vector3(0, 0.2, 0.1), "halo", MINT, 0.65, 0.6)
	current_duck_level = level
	duck_label.text = "%d 级" % level if level > 0 else ""
	# The authored parts have real bearings/feet. Visibility changes immediately;
	# no per-upgrade temporary cylinders, detached bars, or late queue_free copy.
	for i in range(1, 4):
		var part = "Upgrade_%d" % i
		if duck_rig.parts.has(part):
			duck_rig.parts[part].visible = level >= i
