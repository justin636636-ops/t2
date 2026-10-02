extends Node3D
## A painted, curved theatre set. Entirely behind the shooting lanes, no physics.

var pieces: Array[MeshInstance3D] = []
var painted_materials: Array[ShaderMaterial] = []

func set_show_look(tint: Color, gain: float, clock: float, motion: bool) -> void:
	for material in painted_materials:
		material.set_shader_parameter("show_tint", tint)
		material.set_shader_parameter("show_gain", gain)
		material.set_shader_parameter("sea_clock", clock)
		material.set_shader_parameter("sea_motion", 1.0 if motion else 0.0)

func add_piece(mesh_: Mesh, material: Material, label_: String) -> MeshInstance3D:
	var piece = MeshInstance3D.new()
	piece.name = label_
	piece.mesh = mesh_
	piece.material_override = material
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(piece)
	pieces.append(piece)
	return piece

func finish(color: Color, roughness_: float = 0.9) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness_
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func surface(points: PackedVector3Array, indices: PackedInt32Array, normals: PackedVector3Array, uvs: PackedVector2Array) -> ArrayMesh:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh_ = ArrayMesh.new()
	mesh_.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh_

func _ready() -> void:
	var points = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	for i in range(65):
		var u = i / 64.0
		var x = lerpf(-13.2, 13.2, u)
		var z = -12.6 + pow(x / 13.2, 2) * 1.8
		for y in [1.62, 8.0]:
			points.append(Vector3(x, y, z))
			normals.append(Vector3(-x * 3.6 / (13.2 * 13.2), 0, 1).normalized())
			uvs.append(Vector2(u, (y - 1.62) / 6.38))
		if i < 64:
			var a = i * 2
			indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
	var painted = ShaderMaterial.new()
	painted.shader = preload("res://assets/shaders/painted_backdrop.gdshader")
	painted.set_shader_parameter("harbour_paint", preload("res://assets/backdrops/harbour-night-v21.png"))
	painted.set_shader_parameter("use_harbour_paint", true)
	painted_materials.append(painted)
	add_piece(surface(points, indices, normals, uvs), painted, "CurvedPaintedNight")
	# Three opaque cut-outs give the sea real parallax and shadow-free readable edges.
	for layer in range(3):
		points = PackedVector3Array()
		normals = PackedVector3Array()
		uvs = PackedVector2Array()
		indices = PackedInt32Array()
		for i in range(97):
			var x = lerpf(-12.5, 12.5, i / 96.0)
			var crest = 3.25 - layer * 0.30 + sin(x * 0.86 + layer * 1.9) * 0.22 + sin(x * 1.72 + layer) * 0.065
			for y in [1.62, crest]:
				points.append(Vector3(x, y, -10.55 + layer * 0.34))
				normals.append(Vector3.BACK)
				uvs.append(Vector2(i / 96.0, y))
			if i < 96:
				var a = i * 2
				indices.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))
		var sea = ShaderMaterial.new()
		sea.shader = preload("res://assets/shaders/painted_backdrop.gdshader")
		sea.set_shader_parameter("sea_layer", float(layer + 1))
		painted_materials.append(sea)
		add_piece(surface(points, indices, normals, uvs), sea, "SeaCutout%d" % layer)
	# A crescent cut from gilt board; not a glowing UI symbol or a gameplay target.
	points = PackedVector3Array()
	normals = PackedVector3Array()
	uvs = PackedVector2Array()
	indices = PackedInt32Array()
	for i in range(49):
		var t = i / 48.0
		var angle = lerpf(-PI * 0.5, PI * 0.5, t)
		var outer = Vector2(-cos(angle), sin(angle)) * 0.82
		var inner = Vector2(-cos(angle) * 0.39, sin(angle) * 0.82)
		for p in [outer, inner]:
			points.append(Vector3(p.x - 4.7, p.y + 5.8, -11.93))
			normals.append(Vector3.BACK)
			uvs.append(p)
		if i < 48:
			var a = i * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var gilt = finish(Color("b89566"), 0.72)
	gilt.emission_enabled = true
	gilt.emission = Color("b89566")
	gilt.emission_energy_multiplier = 0.22
	add_piece(surface(points, indices, normals, uvs), gilt, "GiltCrescent")
