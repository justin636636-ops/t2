extends Node3D
## Authored attraction lettering, gilded flourishes and quiet park/harbour dressing.
## Static opaque geometry, assembled once in material batches. No physics or clocks.

const ArtFonts = preload("res://scripts/art_fonts.gd")
var groups: Dictionary = {}
var pieces: Array[MeshInstance3D] = []
var letter_bounds: Array[AABB] = []
var lettering_triangles = 0

const PALETTE = {
	"ink": Color("19292d"), "paint": Color("294643"),
	"gilt": Color("b99561"), "letter": Color("ead9ae"),
	"iron": Color("293536"), "glass": Color("c39960"),
	"harbour": Color("203236"), "harbour_roof": Color("293e40")
}

func append_mesh(geometry: Mesh, transform_: Transform3D, finish_: String) -> void:
	if not groups.has(finish_):
		groups[finish_] = {"vertices": PackedVector3Array(), "normals": PackedVector3Array(), "uvs": PackedVector2Array(), "indices": PackedInt32Array()}
	var batch: Dictionary = groups[finish_]
	var arrays = geometry.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var first: int = batch.vertices.size()
	var normal_basis = transform_.basis.inverse().transposed()
	for i in range(vertices.size()):
		batch.vertices.append(transform_ * vertices[i])
		batch.normals.append((normal_basis * normals[i]).normalized())
		batch.uvs.append(uvs[i] if i < uvs.size() else Vector2.ZERO)
	if indices.is_empty():
		for i in range(vertices.size()):
			batch.indices.append(first + i)
	else:
		for i in indices:
			batch.indices.append(first + i)

func box(pos: Vector3, size_: Vector3, finish_: String) -> void:
	var geometry = BoxMesh.new()
	geometry.size = size_
	append_mesh(geometry, Transform3D(Basis.IDENTITY, pos), finish_)

func cylinder(pos: Vector3, radius: float, height: float, finish_: String, top: float = -1) -> void:
	var geometry = CylinderMesh.new()
	geometry.bottom_radius = radius
	geometry.top_radius = radius if top < 0 else top
	geometry.height = height
	geometry.radial_segments = 12
	append_mesh(geometry, Transform3D(Basis.IDENTITY, pos), finish_)

func line(a: Vector3, b: Vector3, radius: float, finish_: String) -> void:
	var geometry = CylinderMesh.new()
	geometry.bottom_radius = radius
	geometry.top_radius = radius
	geometry.height = a.distance_to(b)
	geometry.radial_segments = 8
	append_mesh(geometry, Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())), (a + b) * 0.5), finish_)

func polygon(points: PackedVector2Array, pos: Vector3, depth: float, finish_: String) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles = Geometry2D.triangulate_polygon(points)
	for i in range(0, triangles.size(), 3):
		var a = points[triangles[i]]
		var b = points[triangles[i + 1]]
		var c = points[triangles[i + 2]]
		if (b - a).cross(c - a) > 0:
			var swap = b
			b = c
			c = swap
		for face in [-1, 1]:
			for p in ([a, b, c] if face > 0 else [a, c, b]):
				st.set_normal(Vector3(0, 0, face))
				st.set_uv(p)
				st.add_vertex(Vector3(p.x, p.y, depth * face * 0.5))
	for i in range(points.size()):
		var a = points[i]
		var b = points[(i + 1) % points.size()]
		var normal = Vector3(b.y - a.y, a.x - b.x, 0).normalized()
		var p0 = Vector3(a.x, a.y, -depth * 0.5)
		var p1 = Vector3(a.x, a.y, depth * 0.5)
		var p2 = Vector3(b.x, b.y, -depth * 0.5)
		var p3 = Vector3(b.x, b.y, depth * 0.5)
		for p in [p0, p1, p2, p1, p3, p2]:
			st.set_normal(normal)
			st.set_uv(Vector2(p.x, p.y))
			st.add_vertex(p)
	append_mesh(st.commit(), Transform3D(Basis.IDENTITY, pos), finish_)

func disc(pos: Vector3, radius: float, finish_: String, scale_: Vector2 = Vector2.ONE) -> void:
	var outline = PackedVector2Array()
	for i in range(24):
		var angle = i / 24.0 * TAU
		outline.append(Vector2(cos(angle), sin(angle)) * radius * scale_)
	polygon(outline, pos, 0.035, finish_)

func plaque(scale_: Vector2, pos: Vector3, finish_: String) -> void:
	var outline = PackedVector2Array([
		Vector2(-3.8, -0.22), Vector2(-3.6, -0.42), Vector2(-1.3, -0.40),
		Vector2(0, -0.47), Vector2(1.3, -0.40), Vector2(3.6, -0.42),
		Vector2(3.8, -0.22), Vector2(3.72, 0.25), Vector2(2.5, 0.43),
		Vector2(0, 0.49), Vector2(-2.5, 0.43), Vector2(-3.72, 0.25)
	])
	for i in range(outline.size()):
		outline[i] *= scale_
	polygon(outline, pos, 0.055, finish_)

func marquee() -> void:
	plaque(Vector2.ONE, Vector3(0, 7.21, -4.13), "gilt")
	plaque(Vector2(0.98, 0.88), Vector3(0, 7.21, -4.09), "paint")
	var word = "怪物打靶夜"
	for i in range(word.length()):
		var text = TextMesh.new()
		text.font = ArtFonts.get_font("title")
		text.font_size = 60
		text.pixel_size = 0.015
		text.curve_step = 0.7
		text.depth = 0.045
		text.text = word[i]
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var y = 7.24 + [0.0, 0.03, 0.05, 0.03, 0.0][i]
		var basis = Basis(Vector3.BACK, deg_to_rad([-3.0, 1.5, 0.0, -1.5, 3.0][i])).scaled(Vector3(1.1, 0.9, 1))
		var pos = Vector3((i - 2) * 1.20, y, -3.98)
		append_mesh(text, Transform3D(basis, pos), "letter")
		append_mesh(text, Transform3D(basis, pos + Vector3(0.02, -0.035, -0.065)), "ink")
		letter_bounds.append(Transform3D(basis, pos) * text.get_aabb())
		lettering_triangles += text.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() / 3
	# Two small engraved monster masks tie the attraction to its cast.
	for side in [-1, 1]:
		var x = side * 5.18
		var outline = PackedVector2Array()
		for i in range(32):
			var angle = i / 32.0 * TAU
			outline.append(Vector2(cos(angle) * (0.27 + 0.04 * sin(angle)), sin(angle) * 0.33))
		polygon(outline, Vector3(x, 7.19, -4.08), 0.05, "gilt")
		for eye in [-1, 1]:
			disc(Vector3(x + eye * 0.105, 7.24, -4.035), 0.056, "ink", Vector2(0.76, 1.0))
			polygon(PackedVector2Array([Vector2(-0.04, 0), Vector2(0.09 * eye, 0.16), Vector2(0.04, 0)]), Vector3(x + eye * 0.18, 7.44, -4.07), 0.04, "gilt")
		line(Vector3(x - 0.08, 7.04, -4.03), Vector3(x + 0.08, 7.04, -4.03), 0.017, "ink")
		for section in [[3.95, 4.72], [5.60, 7.55]]:
			for i in range(14):
				var u = i / 14.0
				var v = (i + 1) / 14.0
				var a = Vector3(side * lerpf(section[0], section[1], u), 7.18 + sin(u * PI) * 0.06, -4.06)
				var b = Vector3(side * lerpf(section[0], section[1], v), 7.18 + sin(v * PI) * 0.06, -4.06)
				line(a, b, 0.019, "gilt")
				line(a + Vector3(0, -0.07, 0), b + Vector3(0, -0.07, 0), 0.009, "gilt")

func lanterns() -> void:
	# The posts sit outside the booth and firing lanes. Small opaque warm panes.
	for side in [-1, 1]:
		var x = side * 13.3
		var z = -7.0
		cylinder(Vector3(x, 0.13, z), 0.27, 0.26, "iron")
		cylinder(Vector3(x, 0.42, z), 0.13, 0.44, "iron", 0.07)
		cylinder(Vector3(x, 2.65, z), 0.052, 4.3, "iron")
		for y in [0.65, 4.55]:
			cylinder(Vector3(x, y, z), 0.076, 0.075, "gilt")
		var tip = Vector3(x - side * 0.52, 5.13, z)
		var previous = Vector3(x, 4.7, z)
		for i in range(13):
			var t = i / 12.0
			var current = Vector3(x - side * 0.52 * t, 4.7 + sin(t * PI * 0.5) * 0.43, z)
			if i > 0:
				line(previous, current, 0.045, "iron")
			previous = current
		line(tip, tip - Vector3(0, 0.19, 0), 0.018, "gilt")
		var centre = tip - Vector3(0, 0.50, 0)
		box(centre, Vector3(0.32, 0.46, 0.29), "glass")
		for dx in [-0.185, 0.185]:
			for dz in [-0.17, 0.17]:
				box(centre + Vector3(dx, 0, dz), Vector3(0.036, 0.55, 0.036), "iron")
		for y in [-0.265, 0.265]:
			box(centre + Vector3(0, y, 0), Vector3(0.43, 0.07, 0.39), "iron")
		cylinder(centre + Vector3(0, 0.37, 0), 0.33, 0.22, "iron", 0.075)
		cylinder(centre + Vector3(0, -0.37, 0), 0.06, 0.14, "gilt", 0.015)

func harbour() -> void:
	# Thin scenic boards behind every pirate/balloon collision, never target props.
	var z = -11.45
	polygon(PackedVector2Array([Vector2(-1.55, 0), Vector2(-1.55, 0.22), Vector2(-1.02, 0.42), Vector2(-0.64, 0.30), Vector2(-0.31, 0.50), Vector2(0.07, 0.37), Vector2(0.70, 0.57), Vector2(1.53, 0.19), Vector2(1.53, 0)]), Vector3(-6.5, 3.16, z), 0.07, "harbour")
	polygon(PackedVector2Array([Vector2(-0.28, 0), Vector2(0.28, 0), Vector2(0.19, 1.30), Vector2(-0.19, 1.30)]), Vector3(-8.0, 3.43, z + 0.05), 0.08, "harbour_roof")
	box(Vector3(-8.0, 4.76, z + 0.08), Vector3(0.59, 0.12, 0.11), "harbour")
	box(Vector3(-8.0, 4.99, z + 0.10), Vector3(0.38, 0.36, 0.09), "harbour_roof")
	polygon(PackedVector2Array([Vector2(-0.33, 0), Vector2(0, 0.28), Vector2(0.33, 0)]), Vector3(-8.0, 5.15, z + 0.11), 0.08, "harbour")
	box(Vector3(-8.0, 4.99, z + 0.16), Vector3(0.12, 0.16, 0.025), "harbour_roof")

	for x in [5.25, 6.2, 7.18]:
		box(Vector3(x, 3.54, z), Vector3(0.89, 0.75, 0.085), "harbour")
		polygon(PackedVector2Array([Vector2(-0.56, 0), Vector2(-0.12, 0.40), Vector2(0.09, 0.40), Vector2(0.56, 0)]), Vector3(x, 3.9, z + 0.07), 0.06, "harbour_roof")
		for y in [3.5, 3.72]:
			box(Vector3(x + 0.21, y, z + 0.09), Vector3(0.09, 0.13, 0.015), "harbour_roof")
	line(Vector3(7.9, 3.25, z), Vector3(7.9, 5.30, z), 0.033, "harbour")
	polygon(PackedVector2Array([Vector2(0, 0), Vector2(-0.52, -0.18), Vector2(0, -0.33)]), Vector3(7.9, 5.30, z + 0.03), 0.04, "harbour_roof")

func apron_engraving() -> void:
	# Replace the visual repetition of two star panels with chapter-specific inlays.
	for x in [-4.0, 4.0]:
		disc(Vector3(x, 0.86, -0.89), 0.36, "gilt", Vector2(1.2, 1))
		disc(Vector3(x, 0.86, -0.86), 0.34, "ink", Vector2(1.2, 1))
	var centre = Vector3(-4, 0.88, -0.83)
	line(centre + Vector3(0, 0.22, 0), centre + Vector3(0, -0.22, 0), 0.019, "gilt")
	line(centre + Vector3(-0.13, 0.09, 0), centre + Vector3(0.13, 0.09, 0), 0.017, "gilt")
	for side in [-1, 1]:
		var previous = centre + Vector3(0, -0.23, 0)
		for i in range(12):
			var t = (i + 1) / 12.0
			var point = centre + Vector3(side * 0.25 * t, -0.23 + t * t * 0.17, 0)
			line(previous, point, 0.018, "gilt")
			previous = point
		polygon(PackedVector2Array([Vector2(-0.06, 0), Vector2(0, 0.08), Vector2(0.06, 0)]), previous, 0.03, "gilt")
	centre = Vector3(4, 0.9, -0.83)
	polygon(PackedVector2Array([Vector2(-0.32, -0.11), Vector2(-0.22, -0.25), Vector2(0.23, -0.25), Vector2(0.32, -0.11)]), centre, 0.035, "gilt")
	line(centre + Vector3(0, -0.10, 0), centre + Vector3(0, 0.29, 0), 0.017, "gilt")
	polygon(PackedVector2Array([Vector2(-0.04, 0.26), Vector2(-0.26, -0.07), Vector2(-0.04, -0.07)]), centre, 0.03, "gilt")
	polygon(PackedVector2Array([Vector2(0.04, 0.20), Vector2(0.04, -0.07), Vector2(0.22, -0.07)]), centre, 0.03, "gilt")

func finish_batches() -> void:
	for key in groups:
		var batch: Dictionary = groups[key]
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = batch.vertices
		arrays[Mesh.ARRAY_NORMAL] = batch.normals
		arrays[Mesh.ARRAY_TEX_UV] = batch.uvs
		arrays[Mesh.ARRAY_INDEX] = batch.indices
		var geometry = ArrayMesh.new()
		geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material = StandardMaterial3D.new()
		material.albedo_color = PALETTE[key]
		material.roughness = 0.78
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		if key in ["harbour", "harbour_roof"]:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if key in ["gilt", "letter"]:
			material.metallic = 0.28
			material.roughness = 0.55
		if key == "glass":
			material.emission_enabled = true
			material.emission = PALETTE[key]
			material.emission_energy_multiplier = 0.45
		var piece = MeshInstance3D.new()
		piece.name = key.to_pascal_case()
		piece.mesh = geometry
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(piece)
		pieces.append(piece)
	groups.clear()

func _ready() -> void:
	marquee()
	lanterns()
	# The complete hand-painted harbour now lives on the curved cyclorama.
	# Keep the foreground attraction lettering, lanterns and carved apron.
	apron_engraving()
	finish_batches()
