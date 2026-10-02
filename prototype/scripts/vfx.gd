extends Node3D
## Bounded cosmetic effects. No collision, damage, score, or wall-clock timers.

const MAX_EFFECTS = 48
const COLORS = [Color("eadcc0"), Color("8cbea3"), Color("c7806e"), Color("c7aa72")]
const TARGET_COLORS = [Color("bf655a"), Color("65ae9a"), Color("9a83ae"), Color("c39a52"), Color("c48895")]
const CREW_COLORS = [Color("79424a"), Color("3e6860"), Color("997649"), Color("455d72")]
var effects: Array = []
var camera: Camera3D
var rng = RandomNumberGenerator.new()
var textures: Dictionary = {}
var meshes: Dictionary = {}
var reduced_motion = false
var paper_material: StandardMaterial3D
var ray_material: StandardMaterial3D
var spring_material: StandardMaterial3D
var spark_material: StandardMaterial3D
var ribbon_material: StandardMaterial3D

func _ready() -> void:
	rng.seed = 301002
	meshes.paper = folded_paper_mesh()
	meshes.chip = painted_chip_mesh()
	paper_material = StandardMaterial3D.new()
	paper_material.vertex_color_use_as_albedo = true
	paper_material.roughness = 0.65
	paper_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ray_material = StandardMaterial3D.new()
	ray_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ray_material.albedo_color = Color("e7bd79")
	var ray_mesh = CylinderMesh.new()
	ray_mesh.top_radius = 0.008
	ray_mesh.bottom_radius = 0.004
	ray_mesh.height = 1
	ray_mesh.radial_segments = 6
	meshes.ray = ray_mesh
	spring_material = StandardMaterial3D.new()
	spring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spring_material.albedo_color = Color("a8dec0")
	meshes.spring_ray = coil_mesh(0.040, 0.004, 12)
	meshes.coil = coil_mesh(0.085, 0.013, 5)
	var spark = QuadMesh.new()
	spark.size = Vector2(0.028, 0.12)
	meshes.spark = spark
	spark_material = StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo = true
	spark_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ribbon = QuadMesh.new()
	ribbon.size = Vector2(0.045, 1.0)
	meshes.ribbon = ribbon
	ribbon_material = StandardMaterial3D.new()
	ribbon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ribbon_material.vertex_color_use_as_albedo = true
	ribbon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ribbon_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for name_ in ["burst", "halo", "smoke", "star", "impact-paper", "impact-metal"]:
		textures[name_] = load("res://assets/vfx/" + name_ + ".svg")
	# Submit these shader variants during the title page, before the first shot.
	glyph(Vector3(0, 3, -2.9), "burst", Color(1, 1, 1, 0.001), 0.12, 0.002)
	debris(Vector3(0, 3, -2.9), "paper", 1, 0)
	for part in effects.back().particles:
		part.size = 0.001
	effects.back().duration = 0.12
	# The help path uses the same shared material and fixed segment mesh at runtime.
	var warm_ribbon = MultiMeshInstance3D.new()
	warm_ribbon.multimesh = MultiMesh.new()
	warm_ribbon.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	warm_ribbon.multimesh.use_colors = true
	warm_ribbon.multimesh.mesh = meshes.ribbon
	warm_ribbon.multimesh.instance_count = 1
	warm_ribbon.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.001), Vector3(0, 3, -2.9)))
	warm_ribbon.multimesh.set_instance_color(0, Color(1, 1, 1, 0.001))
	warm_ribbon.material_override = ribbon_material
	warm_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_effect(warm_ribbon, 0.12, "warm")

	var warm_ray = MeshInstance3D.new()
	warm_ray.mesh = meshes.ray
	warm_ray.material_override = ray_material
	warm_ray.position = Vector3(0, 3, -2.7)
	warm_ray.scale = Vector3.ONE * 0.001
	warm_ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_effect(warm_ray, 0.12, "ray")
	var warm_coil = MeshInstance3D.new()
	warm_coil.mesh = meshes.spring_ray
	warm_coil.material_override = spring_material
	warm_coil.position = Vector3(0, 3, -2.7)
	warm_coil.scale = Vector3.ONE * 0.001
	warm_coil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_effect(warm_coil, 0.12, "ray")
	spark_fan(Vector3(0, 3, -2.9), false, false)
	effects.back().node.scale = Vector3.ONE * 0.001
	effects.back().duration = 0.12

func folded_paper_mesh() -> ArrayMesh:
	# Irregular cut ends and a rolled fold catch the existing stage light.
	# Vertex tint marks worn cut ends, reused by all emitter palettes.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(6):
		var u = float(i) / 6
		var v = float(i + 1) / 6
		var a = Vector3(-0.043, (u - 0.5) * 0.17, sin(u * PI) * 0.025)
		var b = Vector3(0.043, (u - 0.5) * 0.17 + 0.014, sin(u * PI) * 0.025)
		var c = Vector3(-0.043, (v - 0.5) * 0.17, sin(v * PI) * 0.025)
		var d = Vector3(0.043, (v - 0.5) * 0.17 + 0.014, sin(v * PI) * 0.025)
		for p in [a, c, b, b, c, d]:
			st.set_color(Color(0.72, 0.72, 0.72) if i == 0 or i == 5 else Color.WHITE)
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()

func painted_chip_mesh() -> ArrayMesh:
	# A bevelled, irregular painted-wood flake, not the pointed stock prism.
	var outline = PackedVector2Array([Vector2(-0.045, -0.07), Vector2(0.022, -0.08), Vector2(0.054, -0.016), Vector2(0.028, 0.079), Vector2(-0.021, 0.065), Vector2(-0.056, 0.008)])
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(outline.size()):
		var a = outline[i]
		var b = outline[(i + 1) % outline.size()]
		var inner_a = Vector3(a.x * 0.78, a.y * 0.78, 0.017)
		var inner_b = Vector3(b.x * 0.78, b.y * 0.78, 0.017)
		var outer_a = Vector3(a.x, a.y, 0)
		var outer_b = Vector3(b.x, b.y, 0)
		for p in [Vector3(0, 0, 0.017), inner_b, inner_a]:
			st.set_color(Color.WHITE)
			st.add_vertex(p)
		for p in [inner_a, inner_b, outer_a, outer_a, inner_b, outer_b]:
			st.set_color(Color(0.68, 0.68, 0.68))
			st.add_vertex(p)
		for p in [Vector3(0, 0, -0.009), outer_a, outer_b]:
			st.set_color(Color(0.48, 0.42, 0.33))
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()

func coil_mesh(radius: float, thickness: float, turns: int) -> ArrayMesh:
	# A reusable helical tube. Y is its unit-length axis, endpoints at +/-0.5.
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var indices = PackedInt32Array()
	var steps = turns * 18
	var sides = 6
	for i in range(steps + 1):
		var u = float(i) / steps
		var angle = u * turns * TAU
		var center = Vector3(cos(angle) * radius, u - 0.5, sin(angle) * radius)
		var radial = Vector3(cos(angle), 0, sin(angle))
		var tangent = Vector3(-sin(angle) * radius * turns * TAU, 1, cos(angle) * radius * turns * TAU).normalized()
		var cross_axis = tangent.cross(radial).normalized()
		for j in range(sides):
			var normal = radial * cos(float(j) / sides * TAU) + cross_axis * sin(float(j) / sides * TAU)
			vertices.append(center + normal * thickness)
			normals.append(normal)
			if i < steps:
				var a = i * sides + j
				var b = i * sides + (j + 1) % sides
				indices.append_array(PackedInt32Array([a, b, a + sides, b, b + sides, a + sides]))
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh_ = ArrayMesh.new()
	mesh_.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh_

func add_effect(node: Node3D, duration: float, kind: String, data: Dictionary = {}) -> void:
	if effects.size() >= MAX_EFFECTS:
		var oldest = effects.pop_front()
		oldest.node.queue_free()
	if not node.is_inside_tree():
		add_child(node)
	data.merge({"node": node, "age": 0.0, "duration": duration, "kind": kind}, true)
	effects.append(data)

func clear() -> void:
	for effect in effects:
		effect.node.queue_free()
	effects.clear()

func glyph(pos: Vector3, asset: String, color: Color, duration: float, size_: float, spin: float = 0.0, drift: Vector3 = Vector3.ZERO) -> void:
	var sprite = Sprite3D.new()
	sprite.texture = textures[asset]
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.pixel_size = 0.006
	sprite.modulate = color
	sprite.position = pos + Vector3(0, 0, 0.12)
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.scale = Vector3.ONE * size_
	add_effect(sprite, duration, "glyph", {"asset": asset, "size": size_, "spin": spin, "drift": drift, "origin": sprite.position, "alpha": color.a})

func debris(pos: Vector3, material_kind: String = "paper", count: int = 18, impulse: float = 1.0, palette: Array = []) -> void:
	var system = MultiMeshInstance3D.new()
	var instances = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = meshes[material_kind]
	instances.instance_count = 6 if reduced_motion else count
	system.multimesh = instances
	system.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	system.material_override = paper_material
	system.position = pos
	var particles: Array = []
	for i in range(instances.instance_count):
		var color: Color = COLORS[i % COLORS.size()]
		if not palette.is_empty():
			color = palette[i % palette.size()]
		if material_kind == "chip" and palette.is_empty():
			color = Color("ba975c") if i % 2 == 0 else Color("76553b")
		instances.set_instance_color(i, color)
		var size_ = rng.randf_range(0.65, 1.3)
		var rotation_ = Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI))
		var angle = i * 2.39996
		var origin = Vector3(sin(angle), cos(angle), 0) * (0.13 if reduced_motion else 0.025)
		var velocity = Vector3(sin(angle) * rng.randf_range(0.8, 1.7), cos(angle) * rng.randf_range(0.7, 1.3) + 1.1, rng.randf_range(0.3, 0.8)) * impulse
		particles.append({"p": origin, "v": velocity, "rotation": rotation_, "spin": Vector3(rng.randf_range(-5, 5), rng.randf_range(-5, 5), rng.randf_range(-5, 5)), "size": size_, "phase": rng.randf_range(0, TAU)})
		instances.set_instance_transform(i, Transform3D(Basis.from_euler(rotation_).scaled(Vector3.ONE * size_), origin))
	add_effect(system, 0.26 if reduced_motion else 0.95, "debris", {"particles": particles, "paper": material_kind == "paper"})

func impact(pos: Vector3, strong: bool = false, metal: bool = false) -> void:
	glyph(pos, "impact-metal" if metal else "impact-paper", Color("f6deb1") if metal else COLORS[0], 0.12, 0.34 if strong else 0.22, rng.randf_range(-0.3, 0.3))
	if not reduced_motion:
		spark_fan(pos, strong, metal)
	if strong:
		glyph(pos, "halo", Color("c7aa72") if metal else COLORS[1], 0.30, 0.38)

func spark_fan(pos: Vector3, strong: bool, metal: bool) -> void:
	var system = MultiMeshInstance3D.new()
	var instances = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = meshes.spark
	instances.instance_count = 6 if metal else (8 if strong else 4)
	system.multimesh = instances
	system.material_override = spark_material
	system.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var facing = camera.global_basis if camera else Basis.IDENTITY
	system.position = pos + facing.z * 0.08
	system.basis = facing
	var phase = rng.randf_range(0, TAU)
	for i in range(instances.instance_count):
		instances.set_instance_color(i, Color("ffe0a0") if metal or strong else Color("eadcc0"))
		var angle = phase + i * TAU / instances.instance_count
		var direction = Vector3(sin(angle), cos(angle), 0)
		instances.set_instance_transform(i, Transform3D(Basis(Vector3.FORWARD, angle), direction * 0.16))
	add_effect(system, 0.23 if strong else 0.16, "sparks", {"phase": phase, "strong": strong})

func destroy_target(pos: Vector3, kind: String, index: int, weak: bool = false, aerial: bool = false) -> void:
	var palette = [TARGET_COLORS[index % 5], Color("eadcc0"), Color("c7aa72")]
	if kind == "pirate":
		palette = [CREW_COLORS[(index - 5) % 4], Color("dbcca8"), Color("b29965")]
	debris(pos, "paper" if kind == "balloon" else "chip", 20 if weak else 14, 1.15 if aerial else 0.85, palette)
	impact(pos, weak, kind == "pirate")
	if aerial and weak:
		glyph(pos, "halo", Color("a8dec0"), 0.38, 0.58)
	var stars = (4 if weak else 2) if not reduced_motion else 1
	for i in range(stars):
		var angle = i * TAU / stars + index
		glyph(pos + Vector3(cos(angle) * 0.34, sin(angle) * 0.34, 0.2), "star", palette[i % palette.size()], 0.42, 0.16 if weak else 0.10, cos(angle) * 0.7, Vector3(cos(angle) * 0.8, sin(angle) * 0.8 + 0.4, 0))

func shield(pos: Vector3) -> void:
	debris(pos, "chip", 12, 0.9, [Color("425f59"), Color("b29965"), Color("76553b")])
	impact(pos, true, true)

func spring(pos: Vector3, carpet: bool) -> void:
	var coil = MeshInstance3D.new()
	coil.mesh = meshes.coil
	coil.material_override = spring_material
	coil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coil.position = pos
	coil.scale.y = 0.23
	add_effect(coil, 0.48, "coil", {"origin": pos, "carpet": carpet})
	glyph(pos, "halo", COLORS[1], 0.40, 0.6 if carpet else 0.42)
	if not reduced_motion:
		for side in [-1, 1]:
			glyph(pos + Vector3(side * 0.3, 0.1, 0), "star", COLORS[1], 0.32, 0.12, side * 0.7, Vector3(side * 0.4, 1.2, 0))

func shot(gun: Node3D, hit: Vector3, spring_ammo: bool = false) -> void:
	var muzzle = gun.to_global(Vector3(0, 0.035, -1.07))
	if spring_ammo:
		glyph(muzzle, "halo", Color("a8dec0"), 0.11, 0.16)
	else:
		glyph(muzzle, "burst", Color("ffe0a0"), 0.055, 0.24, rng.randf_range(-1, 1))
	if not reduced_motion and not spring_ammo:
		glyph(muzzle, "smoke", Color(1, 1, 1, 0.40), 0.30, 0.28, 0.1, Vector3(0, 0.4, 0))
	var ray = MeshInstance3D.new()
	ray.mesh = meshes.spring_ray if spring_ammo else meshes.ray
	ray.scale.y = muzzle.distance_to(hit)
	ray.material_override = spring_material if spring_ammo else ray_material
	ray.position = (muzzle + hit) / 2
	ray.quaternion = Quaternion(Vector3.UP, (hit - muzzle).normalized())
	ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_effect(ray, 0.09 if spring_ammo else 0.045, "ray", {"spring_ammo": spring_ammo})

func duck_help(start: Vector3, target: Node3D, level: int) -> void:
	glyph(start + Vector3(0, 0.4, 0), "halo", COLORS[1], 0.45, 0.42)
	var ribbon = MultiMeshInstance3D.new()
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var segments = MultiMesh.new()
	segments.transform_format = MultiMesh.TRANSFORM_3D
	segments.use_colors = true
	segments.mesh = meshes.ribbon
	segments.instance_count = 24
	ribbon.multimesh = segments
	ribbon.material_override = ribbon_material
	add_effect(ribbon, 0.8, "ribbon", {"start": start, "target": target, "level": level})
	update_ribbon(effects.back(), 0.0)

func update_ribbon(e: Dictionary, p: float) -> void:
	if not is_instance_valid(e.target):
		e.node.hide()
		return
	# Reveal the causal path from duck to the live target in 0.18 seconds.
	# A fixed mesh/material is shared; no ImmediateMesh allocations per frame.
	var finish: Vector3 = e.target.global_position + Vector3(0, 0.80, 0.1)
	var revealed = 1.0 if reduced_motion else lerpf(1.0 / 24.0, 1.0, smoothstep(0.0, 0.225, p))
	var opacity = (1.0 - smoothstep(0.65, 1.0, p)) * 0.62
	var facing = camera.global_basis.z if camera else Vector3.BACK
	for j in range(e.node.multimesh.instance_count):
		var u = float(j) / e.node.multimesh.instance_count
		var v = float(j + 1) / e.node.multimesh.instance_count
		var a: Vector3 = e.start.lerp(finish, u) + Vector3(0, sin(u * PI) * 1.2, 0)
		var b: Vector3 = e.start.lerp(finish, v) + Vector3(0, sin(v * PI) * 1.2, 0)
		var y_axis = (b - a).normalized()
		var x_axis = y_axis.cross(facing).normalized()
		var z_axis = x_axis.cross(y_axis).normalized()
		var visible_ = v <= revealed
		var width = 0.45 + sin((u + v) * 0.5 * PI) * 0.55
		var basis = Basis(x_axis * (width if visible_ else 0.001), y_axis * a.distance_to(b) * 0.94, z_axis)
		e.node.multimesh.set_instance_transform(j, Transform3D(basis, (a + b) * 0.5))
		var color = Color("ddc99a") if j % 6 == 5 else Color("8cbea3")
		color.a = opacity if visible_ else 0.0
		e.node.multimesh.set_instance_color(j, color)

func celebrate(won: bool) -> void:
	if not won:
		return
	for i in range(5 if not reduced_motion else 1):
		debris(Vector3(-4 + i * 2, 6.2, -1.5), "paper", 16, 1.15)

func advance(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		var e: Dictionary = effects[i]
		e.age += delta
		var p = clampf(e.age / e.duration, 0, 1)
		if p >= 1:
			e.node.queue_free()
			effects.remove_at(i)
			continue
		match e.kind:
			"coil":
				var height = 0.23 if reduced_motion else 0.23 + sin(p * PI) * (0.50 if e.carpet else 0.32)
				e.node.scale.y = height
				e.node.position.y = e.origin.y + (height - 0.23) * 0.5
				e.node.scale.x = 1.0 if reduced_motion else 1.0 - p * p
				e.node.scale.z = 1.0 if reduced_motion else 1.0 - p * p
			"glyph":
				e.node.visible = not (reduced_motion and e.asset == "smoke")
				var scale_ = (0.7 + p * 1.4) if e.asset in ["halo", "smoke"] else (1.0 + p * 0.5)
				if reduced_motion:
					scale_ = 1.0
				e.node.scale = Vector3.ONE * e.size * scale_
				e.node.position = e.origin + e.drift * e.age * (0.0 if reduced_motion else 1.0)
				e.node.rotation.z = e.spin * p * (0.0 if reduced_motion else 1.0)
				e.node.modulate.a = e.alpha * (1 - p * p)
			"sparks":
				if reduced_motion:
					e.node.visible = false
					continue
				for j in range(e.node.multimesh.instance_count):
					var angle = e.phase + j * TAU / e.node.multimesh.instance_count
					var direction = Vector3(sin(angle), cos(angle), 0)
					var radius = 0.16 + (1 - pow(1 - p, 2)) * (0.33 if e.strong else 0.20)
					var scale_ = Vector3(1, 1.0 + sin(p * PI) * 0.7, 1) * (1 - p * p)
					e.node.multimesh.set_instance_transform(j, Transform3D(Basis(Vector3.FORWARD, angle).scaled(scale_), direction * radius))
			"debris":
				for j in range(e.particles.size()):
					var part: Dictionary = e.particles[j]
					if not reduced_motion:
						part.v.y -= delta * (3.8 if e.paper else 6.0)
						part.v *= maxf(0, 1 - delta * (1.6 if e.paper else 0.65))
						part.p += part.v * delta
						part.rotation += part.spin * delta * (1.0 - p * 0.7)
					var size_ = part.size * (1 - smoothstep(0.55, 1.0, p))
					var flutter = Vector3.ZERO
					if e.paper and not reduced_motion:
						flutter = Vector3(sin(e.age * 11 + part.phase) - sin(part.phase), 0, sin(e.age * 7 + part.phase) - sin(part.phase)) * 0.025
					e.node.multimesh.set_instance_transform(j, Transform3D(Basis.from_euler(part.rotation).scaled(Vector3.ONE * size_), part.p + flutter))
			"ribbon":
				update_ribbon(e, p)
