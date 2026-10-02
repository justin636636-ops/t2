extends RefCounted
## Two cached material batches keep the original bullseye geometry and normals.

static var cream_mesh: ArrayMesh
static var coral_mesh: ArrayMesh

static func build(parent: Node3D, world: Node3D) -> void:
	if cream_mesh == null:
		var face = Basis(Vector3.RIGHT, PI / 2)
		var outer = TorusMesh.new()
		outer.inner_radius = 0.175
		outer.outer_radius = 0.22
		outer.rings = 32
		outer.ring_segments = 8
		var center = CylinderMesh.new()
		center.top_radius = 0.065
		center.bottom_radius = 0.065
		center.height = 0.025
		center.radial_segments = 24
		var tick = BoxMesh.new()
		tick.size = Vector3(0.04, 0.04, 0.045)
		var sections: Array = [
			[outer, Transform3D(face, Vector3(0, 0, 0.21))],
			[center, Transform3D(face, Vector3(0, 0, 0.24))]]
		for point in [Vector3(-0.27, 0, 0.22), Vector3(0.27, 0, 0.22), Vector3(0, 0.27, 0.22), Vector3(0, -0.27, 0.22)]:
			sections.append([tick, Transform3D(Basis.IDENTITY, point)])
		cream_mesh = combine(sections)
		var middle = TorusMesh.new()
		middle.inner_radius = 0.109
		middle.outer_radius = 0.137
		middle.rings = 32
		middle.ring_segments = 8
		coral_mesh = combine([[middle, Transform3D(face, Vector3(0, 0, 0.23))]])
	world.mesh(parent, cream_mesh, Vector3.ZERO, Color("eedcae"))
	world.mesh(parent, coral_mesh, Vector3.ZERO, Color("b36450"))

static func combine(sections: Array) -> ArrayMesh:
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	for section in sections:
		var arrays: Array = section[0].get_mesh_arrays()
		var pose: Transform3D = section[1]
		var offset = vertices.size()
		for vertex in arrays[Mesh.ARRAY_VERTEX]:
			vertices.append(pose * vertex)
		for normal in arrays[Mesh.ARRAY_NORMAL]:
			normals.append((pose.basis * normal).normalized())
		for index in arrays[Mesh.ARRAY_INDEX]:
			indices.append(offset + index)
	var data = []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = vertices
	data[Mesh.ARRAY_NORMAL] = normals
	data[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	return mesh
