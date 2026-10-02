extends Node3D
## Bounded decoration outside the target lanes, on the world's presentation clock.

const MOTE_COUNT = 32
var dust: MultiMeshInstance3D
var origins: Array[Vector3] = []
var sizes: Array[float] = []
var phases: Array[float] = []
var beam_material: ShaderMaterial
var dust_material: ShaderMaterial

func _ready() -> void:
	var shader = preload("res://assets/shaders/stage_air.gdshader")
	beam_material = ShaderMaterial.new()
	beam_material.shader = shader
	beam_material.set_shader_parameter("opacity", 0.018)
	for side in [-1, 1]:
		var beam = MeshInstance3D.new()
		beam.mesh = beam_mesh(side)
		beam.material_override = beam_material
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
	dust_material = ShaderMaterial.new()
	dust_material.shader = shader
	dust_material.set_shader_parameter("mote", true)
	dust_material.set_shader_parameter("opacity", 0.26)
	dust = MultiMeshInstance3D.new()
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.material_override = dust_material
	var instances = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	var quad = QuadMesh.new()
	quad.size = Vector2.ONE
	instances.mesh = quad
	instances.instance_count = MOTE_COUNT
	dust.multimesh = instances
	add_child(dust)
	var rng = RandomNumberGenerator.new()
	rng.seed = 301005
	for i in range(MOTE_COUNT):
		var point: Vector3
		if i < 20:
			var side = -1 if i % 2 else 1
			point = Vector3(side * rng.randf_range(7.8, 8.4), rng.randf_range(2.0, 6.0), -6.8)
		else:
			point = Vector3(rng.randf_range(-5.8, 5.8), rng.randf_range(5.7, 6.4), -8.0)
		origins.append(point)
		sizes.append(rng.randf_range(0.035, 0.060))
		phases.append(rng.randf_range(0, TAU))
		instances.set_instance_custom_data(i, Color(phases[i] / TAU, 0, 0, 1))
	advance(0, false)

func beam_mesh(side: int) -> ArrayMesh:
	var top = Vector3(side * 8.0, 6.2, -7.2)
	var bottom = Vector3(side * 7.2, 1.65, -7.4)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([top + Vector3(-0.07, 0, 0), top + Vector3(0.07, 0, 0), bottom + Vector3(0.75, 0, 0), bottom + Vector3(-0.75, 0, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func advance(clock: float, reduced: bool) -> void:
	beam_material.set_shader_parameter("air_clock", 0.0 if reduced else clock)
	dust_material.set_shader_parameter("air_clock", 0.0 if reduced else clock)
	dust.visible = not reduced
	if reduced:
		return
	for i in range(MOTE_COUNT):
		var phase = phases[i]
		var drift = Vector3(sin(clock * 0.30 + phase) * 0.10, sin(clock * 0.22 + phase) * 0.16, 0)
		dust.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * sizes[i]), origins[i] + drift))
