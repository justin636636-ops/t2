extends Node3D
## Practical bulb cues; every state advances on the world's pausable clock.
## No TIME uniform, timers, colliders, score or gameplay delays.

const BULB_COUNT = 29
var bulbs: MultiMeshInstance3D
var wires: MultiMeshInstance3D
var mode = "idle"
var age = 0.0
var bell_age = 1.0
var group_age = 1.0
var levels: Array[float] = []

func _ready() -> void:
	bulbs = MultiMeshInstance3D.new()
	bulbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material = ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/practical_bulb.gdshader")
	bulbs.material_override = material
	var shape = SphereMesh.new()
	shape.radius = 0.056
	shape.height = 0.112
	shape.radial_segments = 20
	shape.rings = 10
	bulbs.multimesh = batch(shape, true)
	add_child(bulbs)
	wires = MultiMeshInstance3D.new()
	wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wire_material = StandardMaterial3D.new()
	wire_material.albedo_color = Color("2b2427")
	wires.material_override = wire_material
	var cord = CylinderMesh.new()
	cord.top_radius = 0.011
	cord.bottom_radius = 0.011
	cord.height = 0.2
	cord.radial_segments = 8
	wires.multimesh = batch(cord, false)
	add_child(wires)
	for i in range(BULB_COUNT):
		var pos = Vector3(-8.6 + i * 0.614, 6.58 - 0.10 * sin(i / 28.0 * PI), -4.12)
		bulbs.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(1, 1.2, 1)), pos))
		wires.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.1, 0)))
		levels.append(0.9)
	advance(0, false)

func batch(mesh_: Mesh, custom: bool) -> MultiMesh:
	var instances = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = custom
	instances.mesh = mesh_
	instances.instance_count = BULB_COUNT
	return instances

func open() -> void:
	mode = "opening"
	age = 0
	bell_age = 1
	group_age = 1

func next_group() -> void:
	group_age = 0

func ring_bell() -> void:
	bell_age = 0

func finish(won: bool) -> void:
	mode = "win" if won else "loss"
	age = 0
	bell_age = 1
	group_age = 1

func reset_show() -> void:
	mode = "idle"
	age = 0
	bell_age = 1
	group_age = 1
	advance(0, false)

func advance(delta: float, reduced: bool) -> void:
	age += delta
	bell_age = minf(1.0, bell_age + delta)
	group_age = minf(1.0, group_age + delta)
	for i in range(BULB_COUNT):
		var u = float(i) / (BULB_COUNT - 1)
		var brightness = 0.9
		if mode == "opening" and age < 1 and not reduced:
			var distance_from_center = absf(u - 0.5) * 2
			brightness = 0.72 + exp(-pow((distance_from_center - age) / 0.20, 2)) * sin(age * PI) * 0.38
		elif mode == "win":
			brightness = 1.07
			if not reduced and age < 1.6:
				var wave = clampf(age / 1.6, 0, 1)
				brightness += exp(-pow((absf(u - 0.5) * 2 - wave) / 0.23, 2)) * sin(wave * PI) * 0.16
		elif mode == "loss":
			brightness = 0.62 if reduced else lerpf(0.9, 0.62, clampf(age / 0.8, 0, 1))
		if group_age < 0.6 and not reduced and mode not in ["win", "loss"]:
			# Paired ends close toward the middle once, away from the target lanes.
			var p = group_age / 0.6
			brightness += exp(-pow((absf(u - 0.5) * 2 - (1 - p)) / 0.24, 2)) * sin(p * PI) * 0.13
		if bell_age < 0.75:
			brightness += 0.18 if reduced else exp(-pow((u - (1.0 - bell_age / 0.75)) / 0.13, 2)) * sin(bell_age / 0.75 * PI) * 0.32
		levels[i] = brightness
		bulbs.multimesh.set_instance_custom_data(i, Color(brightness, 0, 0, 1))
