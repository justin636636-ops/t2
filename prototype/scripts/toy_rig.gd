extends RefCounted
## Decorative animation only. Target roots own all hitboxes and ballistic motion.

var parts: Dictionary = {}
var rests: Dictionary = {}
var meshes: Array[GeometryInstance3D] = []

func collect(root: Node) -> void:
	if root.name in ["Eye_L", "Eye_R", "Pupil_L", "Pupil_R", "Brow_L", "Brow_R", "Hand_L", "Hand_R", "Hat", "Wing_L", "Wing_R", "Key", "Duck_Head", "Duck_Beak", "Duck_Eye_L", "Duck_Eye_R", "Upgrade_1", "Upgrade_2", "Upgrade_3", "Cylinder", "Hammer", "Trigger", "Index_Finger", "Mouth", "Crest_L", "Crest_R", "Antenna", "Curtain_L", "Curtain_R", "Sail", "Pennant"]:
		parts[str(root.name)] = root
		rests[str(root.name)] = root.transform
	if root is GeometryInstance3D:
		meshes.append(root)
	for child in root.get_children():
		collect(child)

func turn(part: String, angle: Vector3) -> void:
	if parts.has(part):
		parts[part].rotation = angle

func eyes(openness: float) -> void:
	for name_ in ["Eye_L", "Eye_R"]:
		if parts.has(name_):
			parts[name_].scale.y = maxf(0.05, openness)

func gaze(direction: Vector2) -> void:
	for name_ in ["Pupil_L", "Pupil_R"]:
		if parts.has(name_):
			parts[name_].position = rests[name_].origin + Vector3(clampf(direction.x, -1, 1) * 0.032, clampf(direction.y, -1, 1) * 0.022, 0)

func brows(height: float, tilt: float) -> void:
	for name_ in ["Brow_L", "Brow_R"]:
		if parts.has(name_):
			parts[name_].position = rests[name_].origin + Vector3(0, height, 0)
			parts[name_].rotation.z = tilt * (-1 if name_ == "Brow_L" else 1)

func mouth(openness: float) -> void:
	if parts.has("Mouth"):
		parts.Mouth.scale.y = clampf(openness, 0.5, 1.8)

func fade(value: float) -> void:
	for mesh in meshes:
		mesh.transparency = clampf(value, 0, 1)

func reset() -> void:
	for name_ in parts:
		parts[name_].transform = rests[name_]
	fade(0)
