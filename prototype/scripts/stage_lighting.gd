extends Node3D
## Existing lamps, physical fixtures and painted sea on one pausable show clock.
## Stable front key/fill during aiming; no extra light, camera, collider or delay.
const CAST_COLORS = [Color("7196a2"), Color("6b9f9d"), Color("8893ad"), Color("9892aa")]
const ArtBatch = preload("res://scripts/attraction_art.gd")
var fill: OmniLight3D
var rim: OmniLight3D
var bell: OmniLight3D
var frame_lamps: Array[OmniLight3D] = []
var backdrop: Node3D
var air: Node3D
var lens_material: ShaderMaterial
var pieces: Array[MeshInstance3D] = []
var mode = "idle"
var age = 1.0
var group_age = 1.0
var bell_age = 1.0
var clock = 0.0
var group_number = 1
var from_tint = CAST_COLORS[0]
var look_tint = CAST_COLORS[0]
var cue_gain = 1.0

func _ready() -> void:
	# Reuse the established static mesh assembler without adding its scene.
	var batch = ArtBatch.new()
	for side in [-1, 1]:
		var pose = Transform3D(Basis.from_euler(Vector3(0.48, side * 0.24, 0)), Vector3(side * 6.9, 6.24, -3.96))
		var body = CylinderMesh.new()
		body.top_radius = 0.175
		body.bottom_radius = 0.175
		body.height = 0.36
		body.radial_segments = 20
		var forward = Basis(Vector3.RIGHT, PI * 0.5)
		batch.append_mesh(body, pose * Transform3D(forward, Vector3.ZERO), "iron")
		for z in [-0.12, 0.04, 0.17]:
			var rim_mesh = TorusMesh.new()
			rim_mesh.inner_radius = 0.167
			rim_mesh.outer_radius = 0.194
			rim_mesh.rings = 20
			rim_mesh.ring_segments = 6
			batch.append_mesh(rim_mesh, pose * Transform3D(forward, Vector3(0, 0, z)), "brass")
		var lens = CylinderMesh.new()
		lens.top_radius = 0.158
		lens.bottom_radius = 0.158
		lens.height = 0.013
		lens.radial_segments = 32
		batch.append_mesh(lens, pose * Transform3D(forward, Vector3(0, 0, 0.182)), "lens")
		for direction in [-1, 1]:
			var wing = BoxMesh.new()
			wing.size = Vector3(0.075, 0.23, 0.16)
			batch.append_mesh(wing, pose * Transform3D(Basis(Vector3.UP, direction * 0.35), Vector3(direction * 0.21, 0, 0.19)), "iron")
			batch.line(Vector3(side * 6.9 + direction * 0.25, 6.35, -4.10), Vector3(side * 6.9 + direction * 0.25, 6.62, -4.10), 0.024, "iron")
		batch.line(Vector3(side * 6.9 - 0.25, 6.62, -4.10), Vector3(side * 6.9 + 0.25, 6.62, -4.10), 0.024, "iron")
		batch.line(Vector3(side * 6.9, 6.62, -4.10), Vector3(side * 6.9, 6.86, -4.18), 0.021, "iron")
	for name_ in batch.groups:
		var data: Dictionary = batch.groups[name_]
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data.vertices
		arrays[Mesh.ARRAY_NORMAL] = data.normals
		arrays[Mesh.ARRAY_TEX_UV] = data.uvs
		arrays[Mesh.ARRAY_INDEX] = data.indices
		var mesh_ = ArrayMesh.new()
		mesh_.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var item = MeshInstance3D.new()
		item.name = "TheatreFixture_" + name_
		item.mesh = mesh_
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if name_ == "lens":
			lens_material = ShaderMaterial.new()
			lens_material.shader = preload("res://assets/shaders/theatre_lens.gdshader")
			item.material_override = lens_material
		else:
			var material = StandardMaterial3D.new()
			material.albedo_color = Color("283238") if name_ == "iron" else Color("b29965")
			material.metallic = 0.4 if name_ == "iron" else 0.58
			material.roughness = 0.68 if name_ == "iron" else 0.52
			item.material_override = material
		add_child(item)
		pieces.append(item)
	batch.free()

func open(reduced: bool = false) -> void:
	reset_show(reduced)
	mode = "opening"
	age = 0.0
	advance(0, reduced)

func next_group(reduced: bool = false) -> void:
	from_tint = look_tint
	group_number = mini(group_number + 1, 4)
	group_age = 0.0
	advance(0, reduced)

func ring_bell() -> void:
	bell_age = 0.0

func finish(won: bool, reduced: bool = false) -> void:
	from_tint = look_tint
	mode = "win" if won else "loss"
	age = 0.0
	bell_age = 1.0
	group_age = 1.0
	advance(0, reduced)

func reset_show(reduced: bool = false) -> void:
	mode = "idle"
	age = 1.0
	group_age = 1.0
	bell_age = 1.0
	clock = 0.0
	group_number = 1
	from_tint = CAST_COLORS[0]
	look_tint = CAST_COLORS[0]
	advance(0, reduced)

func advance(delta: float, reduced: bool) -> void:
	clock += delta
	age += delta
	group_age = minf(1.0, group_age + delta)
	bell_age = minf(1.0, bell_age + delta)
	var blend = 1.0 if reduced else smoothstep(0.0, 0.85, group_age)
	look_tint = from_tint.lerp(CAST_COLORS[group_number - 1], blend)
	cue_gain = 1.0
	var frame_gain = 1.0
	if mode == "opening":
		cue_gain = 1.0 if reduced else lerpf(0.76, 1.0, smoothstep(0.0, 1.05, age))
	elif mode in ["win", "loss"]:
		var end_blend = 1.0 if reduced else smoothstep(0.0, 1.2, age)
		look_tint = from_tint.lerp(Color("bbab8c") if mode == "win" else Color("708397"), end_blend)
		cue_gain = lerpf(1.0, 1.12 if mode == "win" else 0.80, end_blend)
		frame_gain = lerpf(1.0, 1.16 if mode == "win" else 0.85, end_blend)
	elif group_age < 0.85 and not reduced:
		cue_gain = 1.0 + sin(group_age / 0.85 * PI) * 0.045
	var bell_pulse = 0.0 if bell_age >= 0.65 or reduced else sin(bell_age / 0.65 * PI) * 0.14
	if fill:
		fill.light_color = Color("c4d4de")
		fill.light_energy = 1.25
	if rim:
		rim.light_color = look_tint
		rim.light_energy = 3.6 * cue_gain
	if bell:
		bell.light_energy = 1.5 * (1.0 + bell_pulse)
	for lamp in frame_lamps:
		lamp.light_energy = 1.2 * frame_gain
	if lens_material:
		lens_material.set_shader_parameter("power", 0.80 * frame_gain)
	if backdrop:
		backdrop.set_show_look(look_tint, cue_gain, 0.0 if reduced else clock, not reduced)
	if air:
		air.beam_material.set_shader_parameter("tint", Color("ebcfaa").lerp(look_tint, 0.12))
