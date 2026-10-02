extends Node3D
## Authored hollow bronze bell and connected yoke. Cosmetic, no hit shapes.
const Batch = preload("res://scripts/attraction_art.gd")
var swing: Node3D
var clapper: Node3D
var pieces: Array[MeshInstance3D] = []
var age = 1.0
var swing_angle = 0.0
const PIVOT = Vector3(0, 0.38, 0)

func lathe(profile: PackedVector2Array) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	const SEGMENTS = 48
	for j in range(profile.size()):
		var tangent = profile[mini(j + 1, profile.size() - 1)] - profile[maxi(j - 1, 0)]
		var normal = Vector2(-tangent.y, tangent.x).normalized()
		for i in range(SEGMENTS + 1):
			var theta = i * TAU / SEGMENTS
			var radial = Vector3(cos(theta), 0, sin(theta))
			vertices.append(radial * profile[j].x + Vector3.UP * profile[j].y)
			normals.append(radial * normal.x + Vector3.UP * normal.y)
			uvs.append(Vector2(float(i) / SEGMENTS, float(j) / (profile.size() - 1)))
	for j in range(profile.size() - 1):
		for i in range(SEGMENTS):
			var a = j * (SEGMENTS + 1) + i
			var b = a + 1
			var c = a + SEGMENTS + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, c + 1]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func bead(batch: Node3D, point: Vector3, radius: float, finish: String) -> void:
	var shape = SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2
	shape.radial_segments = 12
	shape.rings = 6
	batch.append_mesh(shape, Transform3D(Basis.IDENTITY, point), finish)

func continuous_arch() -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()
	for j in range(49):
		var angle = j * PI / 48.0
		var centre = Vector3(cos(angle) * 0.57, 0.2 + sin(angle) * 0.48, -0.18)
		var normal = Vector3(cos(angle) / 0.57, sin(angle) / 0.48, 0).normalized()
		for i in range(9):
			var section = i * TAU / 8.0
			var radial = normal * cos(section) + Vector3.BACK * sin(section)
			vertices.append(centre + radial * 0.045)
			normals.append(radial)
			uvs.append(Vector2(float(j)/48,float(i)/8))
	for j in range(48):
		for i in range(8):
			var a = j * 9 + i
			var b = a + 1
			var c = a + 9
			indices.append_array(PackedInt32Array([a,b,c,b,c+1,c]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func ring(batch: Node3D, point: Vector3, radius: float, tube: float, finish: String, basis: Basis = Basis.IDENTITY) -> void:
	var shape = TorusMesh.new()
	shape.inner_radius = radius - tube
	shape.outer_radius = radius + tube
	shape.rings = 40
	shape.ring_segments = 6
	batch.append_mesh(shape, Transform3D(basis, point), finish)

func assemble(batch: Node3D, parent: Node3D) -> void:
	for key in batch.groups:
		var data: Dictionary = batch.groups[key]
		var arrays = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data.vertices
		arrays[Mesh.ARRAY_NORMAL] = data.normals
		arrays[Mesh.ARRAY_TEX_UV] = data.uvs
		arrays[Mesh.ARRAY_INDEX] = data.indices
		var item = MeshInstance3D.new()
		item.name = "Bell_" + key
		item.mesh = ArrayMesh.new()
		item.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material = ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/crafted_surface.gdshader")
		material.set_shader_parameter("tint", Color("bda06b") if key == "bronze" else Color("345b54") if key == "paint" else Color("283337"))
		material.set_shader_parameter("base_roughness", 0.43 if key == "bronze" else 0.72)
		material.set_shader_parameter("metalness", 0.65 if key == "bronze" else 0.28)
		material.set_shader_parameter("finish_mode", 2.0)
		item.material_override = material
		parent.add_child(item)
		pieces.append(item)
	batch.free()

func _ready() -> void:
	var frame = Batch.new()
	# The painted stand supports the yoke; bearing caps share the same true axle.
	frame.cylinder(Vector3(0, -1.75, -0.18), 0.095, 1.50, "paint")
	frame.cylinder(Vector3(0, -2.54, -0.18), 0.34, 0.11, "paint", 0.29)
	ring(frame, Vector3(0, -2.49, -0.18), 0.29, 0.012, "bronze")
	frame.box(Vector3(0, -0.94, -0.18), Vector3(1.25, 0.14, 0.19), "paint")
	for side in [-1, 1]:
		frame.box(Vector3(side * 0.57, -0.35, -0.18), Vector3(0.11, 1.11, 0.13), "paint")
		frame.line(Vector3(side * 0.57, 0.38, -0.18), Vector3(side * 0.12, 0.38, 0), 0.036, "iron")
		bead(frame, Vector3(side * 0.57, 0.38, -0.11), 0.064, "bronze")
		bead(frame, Vector3(side * 0.57, -0.84, -0.06), 0.037, "bronze")
	# A continuous arch, with a small crown finial; kept below the original label.
	frame.append_mesh(continuous_arch(), Transform3D.IDENTITY, "paint")
	bead(frame, Vector3(0, 0.73, -0.18), 0.043, "bronze")
	assemble(frame, self)
	swing = Node3D.new()
	swing.name = "BellCrownPivot"
	swing.position = PIVOT
	add_child(swing)
	var body = Batch.new()
	# Closed cross-section travels down the outside, across the lip and up inside.
	# The mouth remains hollow, with a real thickness and rolled rim.
	var profile = PackedVector2Array([
		Vector2(0.0, 0.34), Vector2(0.075, 0.34), Vector2(0.135, 0.32),
		Vector2(0.18, 0.285), Vector2(0.20, 0.24), Vector2(0.215, 0.17),
		Vector2(0.235, 0.075), Vector2(0.27, -0.03), Vector2(0.325, -0.135),
		Vector2(0.385, -0.225), Vector2(0.435, -0.27), Vector2(0.455, -0.30),
		Vector2(0.453, -0.325), Vector2(0.43, -0.345), Vector2(0.401, -0.34),
		Vector2(0.388, -0.305), Vector2(0.36, -0.235), Vector2(0.305, -0.15),
		Vector2(0.252, -0.045), Vector2(0.215, 0.075), Vector2(0.196, 0.17),
		Vector2(0.18, 0.235), Vector2(0.14, 0.275), Vector2(0.07, 0.292), Vector2(0, 0.292)
	])
	body.append_mesh(lathe(profile), Transform3D(Basis.IDENTITY, -PIVOT), "bronze")
	ring(body, Vector3(0, 0.205, 0) - PIVOT, 0.211, 0.009, "iron")
	ring(body, Vector3(0, -0.23, 0) - PIVOT, 0.391, 0.008, "iron")
	body.box(Vector3(0, 0.37, 0) - PIVOT, Vector3(0.28, 0.09, 0.10), "iron")
	# Six quiet cast lobes distinguish the metal silhouette without emission.
	for i in range(6):
		var angle = i * TAU / 6
		bead(body, Vector3(cos(angle) * 0.252, -0.02, sin(angle) * 0.252) - PIVOT, 0.018, "bronze")
	assemble(body, swing)
	clapper = Node3D.new()
	clapper.name = "BellClapperPivot"
	clapper.position = -PIVOT + Vector3(0, 0.26, 0)
	swing.add_child(clapper)
	var tongue = Batch.new()
	tongue.line(Vector3.ZERO, Vector3(0, -0.65, 0), 0.018, "iron")
	bead(tongue, Vector3(0, -0.66, 0), 0.085, "bronze")
	assemble(tongue, clapper)
	advance(0, false)

func ring_bell() -> void:
	age = 0.0

func reset() -> void:
	age = 1.0
	advance(0, false)

func advance(delta: float, reduced: bool) -> void:
	age = minf(1.0, age + delta)
	var envelope = pow(maxf(0, 1 - age / 0.72), 2)
	swing_angle = 0.0 if reduced else sin(age * 24) * 0.20 * envelope
	swing.rotation.z = swing_angle
	clapper.rotation.z = 0.0 if reduced else -sin(age * 24 + 0.6) * 0.28 * envelope
