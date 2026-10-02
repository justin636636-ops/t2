extends Node3D

const ToyRig = preload("res://scripts/toy_rig.gd")
const CREW_MODELS = ["pirate", "pirate_navigator", "pirate_gunner", "pirate_firstmate"]
const SHIELD_HINGE = Vector3(0, -0.44, -0.015)
const SHIELD_CLOSED = Vector3(0, 0, 0.32)
const WeakpointArt = preload("res://scripts/weakpoint_art.gd")

var index = 0
var kind = "balloon"
var world: Node3D
var base_position = Vector3.ZERO
var alive = true
var generation = 0
var respawn = 0.0
var airborne = false
var lift = 0.0
var velocity = 0.0
var held = 0.0
var exposed = 0.0
var shield_broken = false
var preparation_group = -1
var preparation_shot = -1
var carpet_used = false
var body_visual: Node3D
var body_hit: StaticBody3D
var weak_hit: StaticBody3D
var shield_hit: StaticBody3D
var shield_visual: Node3D
var air_marker: Label3D
var tether: MeshInstance3D
var rig = ToyRig.new()
var death_age = -1.0
var death_duration = 0.44
var death_air = false
var death_weak = false
var death_side = 1.0
var death_pose = Transform3D.IDENTITY
var appear_age = 1.0
var spring_age = 1.0
var landing_age = 1.0
var flight_last_pose: Dictionary = {}
var flight_hand_start = Vector2.ZERO
var shield_open = 0.0
var cover_was_open = false
var cover_reaction_age = 1.0
var shield_break_age = -1.0
var visual_clock = 0.0
var weak_visual: Node3D
var material_warmup = 0.12
# Bounded attention cues pose facial/accessory pivots only.
var attention_age = 1.0
var attention_cooldown = 0.0
var attention_direction = Vector2.ZERO
var attention_strength = 0.0
const ATTENTION_DURATION = 0.64

func observe_shot(point: Vector3, strength: float, delay: float) -> bool:
	if not alive or airborne or held > 0 or attention_cooldown > 0 or world.reduced_motion:
		return false
	var offset = point - global_position
	attention_direction = Vector2(clampf(offset.x / 2.5, -1, 1), clampf(offset.y / 2.0, -0.7, 1))
	attention_age = -delay
	attention_strength = strength
	attention_cooldown = 1.05
	return true

func clear_attention() -> void:
	attention_age = 1.0
	attention_strength = 0.0


func _ready() -> void:
	position = base_position
	build_target()

func hitbox(size: Vector3, pos: Vector3, part: String) -> StaticBody3D:
	var result = world.collider(self, size, pos, 1)
	result.set_meta("target", self)
	result.set_meta("part", part)
	return result

func build_target() -> void:
	body_visual = Node3D.new()
	add_child(body_visual)
	if kind == "balloon":
		world.model(["monster_coral", "monster_mint", "monster_lilac", "monster_honey", "monster_rose"][index % 5], body_visual)
	else:
		world.model(CREW_MODELS[(index - 5) % 4], body_visual)
		shield_visual = Node3D.new()
		shield_visual.position = SHIELD_CLOSED
		add_child(shield_visual)
		world.model("shield", shield_visual)
		shield_hit = hitbox(Vector3(0.89, 0.89, 0.16), Vector3(0, 0, 0.38), "shield")
	rig.collect(body_visual)
	rig.fade(0.001)
	body_hit = hitbox(Vector3(1.22, 1.45 if kind == "balloon" else 1.35, 0.29), Vector3(0, 0 if kind == "balloon" else 0.05, 0), "body")
	weak_hit = hitbox(Vector3(0.38, 0.38, 0.09), Vector3(0, 0, 0.21), "weak")
	weak_visual = Node3D.new()
	body_visual.add_child(weak_visual)
	WeakpointArt.build(weak_visual, world)
	air_marker = world.label3(self, "↑", Vector3(0, 1.27, 0.12), 46, world.MINT, 0.011)
	air_marker.visible = false
	tether = world.mesh(self, world.vfx.meshes.coil, Vector3(0, -0.9, 0), Color("9e7849"))
	tether.scale.y = 0.38
	sync_visuals()

func reset_target() -> void:
	alive = true
	clear_attention()
	attention_cooldown = 0.0
	generation += 1
	respawn = 0
	airborne = false
	lift = 0
	velocity = 0
	held = 0
	exposed = 0
	shield_broken = false
	preparation_group = -1
	preparation_shot = -1
	carpet_used = false
	death_age = -1
	death_air = false
	death_weak = false
	death_pose = Transform3D.IDENTITY
	appear_age = 0
	spring_age = 1
	landing_age = 1
	flight_last_pose.clear()
	flight_hand_start = Vector2.ZERO
	shield_break_age = -1
	cover_was_open = false
	cover_reaction_age = 1.0
	shield_open = 0
	rig.reset()
	material_warmup = 0
	body_visual.transform = Transform3D.IDENTITY
	if shield_visual:
		shield_visual.position = SHIELD_CLOSED
		shield_visual.rotation = Vector3.ZERO
		shield_visual.scale = Vector3.ONE
	position = base_position
	rotation = Vector3.ZERO
	sync_visuals()

func advance(delta: float, clock: float, _group: int, carpet_on: bool) -> void:
	if not alive:
		respawn -= delta
		if respawn <= 0:
			reset_target()
		return
	exposed = maxf(0, exposed - delta)
	held = maxf(0, held - delta)
	if airborne:
		velocity -= 11.0 * delta
		lift += velocity * delta
		if lift <= 0:
			# Record the real contact for a short cosmetic recovery, including a rebound.
			landing_age = 0
			lift = 0
			if carpet_on and kind == "balloon" and absf(position.x) <= 7.25 and not carpet_used:
				carpet_used = true
				velocity = 5.8
				spring_age = 0
				world.carpet_rebound(global_position)
			else:
				airborne = false
				velocity = 0
				if exposed <= 0:
					preparation_group = -1
					preparation_shot = -1
		position.y = base_position.y + lift
	elif held <= 0:
		var destination = base_position.x + sin(clock * 0.6 + index * 1.8) * 0.55
		position.x = move_toward(position.x, destination, delta * 1.5)
		position.y = base_position.y + sin(clock * 1.2 + index) * 0.05
	if not airborne and exposed <= 0 and held <= 0:
		preparation_group = -1
		preparation_shot = -1
	sync_visuals()

func launch(group: int, shot: int) -> bool:
	if not alive or airborne or is_shielded():
		return false
	airborne = true
	lift = 0.02
	velocity = 6.4
	spring_age = 0
	landing_age = 1
	flight_last_pose.clear()
	flight_hand_start = Vector2(rig.parts.Hand_L.rotation.z, rig.parts.Hand_R.rotation.z)
	world.vfx.spring(Vector3(global_position.x, base_position.y - 0.82, global_position.z), false)
	preparation_group = group
	preparation_shot = shot
	sync_visuals()
	return true

func is_shielded() -> bool:
	return kind == "pirate" and not shield_broken and exposed <= 0

func destroy(hit_position: Vector3 = Vector3.INF, weak: bool = false) -> void:
	if not alive:
		return
	var impact_position = global_position if hit_position == Vector3.INF else hit_position
	death_air = airborne
	death_weak = weak
	death_side = -1.0 if to_local(impact_position).x < -0.04 else (1.0 if to_local(impact_position).x > 0.04 else (-1.0 if index % 2 else 1.0))
	death_duration = 0.52 if death_air else (0.46 if kind == "pirate" else 0.44)
	death_pose = body_visual.transform
	world.vfx.destroy_target(impact_position, kind, index, weak, death_air)
	alive = false
	death_age = 0
	respawn = 2.5
	sync_visuals()

func break_shield() -> void:
	shield_broken = true
	shield_break_age = 0
	cover_reaction_age = 0.0
	world.vfx.shield(global_position + Vector3(0, 0, 0.38))
	sync_visuals()

func animate(delta: float, clock: float) -> void:
	visual_clock = clock
	var cover_cue = 0.0
	if kind == "pirate":
		var wants_open = not is_shielded() and not shield_broken and alive
		if wants_open and not cover_was_open:
			cover_reaction_age = 0.0
		cover_was_open = wants_open
		cover_reaction_age = minf(1.0, cover_reaction_age + delta)
		if (wants_open or shield_broken) and world.finale_age < 0:
			cover_cue = sin(clampf(cover_reaction_age / 0.55, 0, 1) * PI)
	attention_age = minf(1.0, attention_age + delta)
	attention_cooldown = maxf(0.0, attention_cooldown - delta)
	if not alive or airborne or held > 0 or world.reduced_motion or world.finale_age >= 0:
		clear_attention()
	var attention = 0.0
	if attention_age >= 0 and attention_age < ATTENTION_DURATION:
		var attack = clampf(attention_age / 0.10, 0, 1)
		var release = clampf((ATTENTION_DURATION - attention_age) / 0.36, 0, 1)
		attention = attack * attack * (3 - 2 * attack) * release * release * (3 - 2 * release) * attention_strength
	material_warmup = maxf(0, material_warmup - delta)
	appear_age += delta
	spring_age += delta
	landing_age += delta
	var phase = clock * 1.9 + index * 1.37
	var motion = 0.0 if world.reduced_motion else 1.0
	var blink_clock = fmod(clock + index * 0.73, 3.7 + index * 0.11)
	var eye_open = 1.0 - sin(clampf(blink_clock / 0.16, 0, 1) * PI) if blink_clock < 0.16 else 1.0
	rig.eyes(1.0 if world.reduced_motion else eye_open)
	if airborne and not world.reduced_motion:
		rig.eyes(1.10)
	elif cover_cue > 0 and not world.reduced_motion:
		rig.eyes(1.0 + cover_cue * 0.08)
	var surprise = 1.0 if airborne else maxf(0.5 if held > 0 else 0.0, cover_cue * 0.35)
	rig.brows((0.045 * surprise + sin(phase * 0.7) * 0.008) * motion, (0.14 * surprise + sin(phase * 0.65) * 0.045) * motion)
	rig.gaze(Vector2(sin(phase * 0.5) * 0.7, 0.7 if airborne else cos(phase * 0.6) * 0.35) * motion)
	rig.mouth(1.0 + surprise * 0.28 * motion)
	var crest_motion = (sin(phase * 1.3) * 0.035 + surprise * 0.12) * motion
	rig.turn("Crest_L", Vector3(0, 0, -crest_motion))
	rig.turn("Crest_R", Vector3(0, 0, crest_motion))
	rig.turn("Antenna", Vector3(0, 0, sin(phase * 1.4) * (0.06 + surprise * 0.1) * motion))
	var arms = sin(phase) * 0.065 * motion
	# Short individual performances leave quiet gaps between gestures.
	# These clocks only pose decorative parts; rail motion and colliders stay put.
	var character = index % 5
	var gesture_time = fmod(clock + index * 1.9, [6.2, 4.7, 7.1, 5.4, 8.3][character])
	if kind == "pirate":
		gesture_time = fmod(clock + (index - 5) * 1.6, [6.8, 7.4, 6.1, 8.2][(index - 5) % 4])
	var gesture = pow(sin(gesture_time / 1.2 * PI), 2) * motion if gesture_time < 1.2 else 0.0
	gesture *= 1.0 - attention
	if airborne or held > 0:
		gesture = 0.0
	var left_pose = 0.0
	var right_pose = 0.0
	if kind == "balloon":
		match character:
			0:
				right_pose = gesture * (0.29 + sin(clock * 9) * 0.10)
				if not airborne:
					rig.mouth(1.0 + gesture * 0.12)
			1:
				left_pose = gesture * (0.18 + sin(clock * 11) * 0.08)
				right_pose = left_pose
				rig.turn("Crest_L", Vector3(0, 0, -(crest_motion + gesture * 0.16)))
				rig.turn("Crest_R", Vector3(0, 0, crest_motion + gesture * 0.16))
			2:
				left_pose = gesture * 0.19
				right_pose = gesture * 0.19
				if not airborne:
					rig.brows((0.008 * sin(phase * 0.7) + gesture * 0.018) * motion, 0.015 * motion)
			3:
				left_pose = gesture * (0.22 + sin(clock * 8) * 0.06)
				right_pose = gesture * (0.22 - sin(clock * 8) * 0.06)
				rig.turn("Antenna", Vector3(0, 0, (sin(phase * 1.4) * (0.06 + surprise * 0.1) + sin(clock * 12) * gesture * 0.13) * motion))
			4:
				left_pose = gesture * (0.12 + sin(clock * 6) * 0.04)
				if not airborne and held <= 0:
					rig.gaze(Vector2(lerpf(sin(phase * 0.5) * 0.45, -0.8, gesture), -gesture * 0.45) * motion)
					rig.mouth(1.0 - gesture * 0.15)
	elif kind == "pirate" and not airborne and held <= 0 and exposed <= 0:
		# Short role-specific habits leave long quiet gaps. All are visual pivots.
		match (index - 5) % 4:
			0:
				right_pose = gesture * 0.24
				rig.brows(gesture * 0.012 * motion, -gesture * 0.035 * motion)
			1:
				right_pose = gesture * 0.20
				rig.gaze(Vector2(gesture * 0.4, -gesture * 0.5) * motion)
			2:
				left_pose = gesture * 0.24
				rig.mouth(1.0 + gesture * 0.15)
			3:
				right_pose = gesture * 0.15
				left_pose = gesture * 0.10
	if attention > 0:
		rig.gaze(Vector2(sin(phase * 0.5) * 0.7, cos(phase * 0.6) * 0.35).lerp(attention_direction, attention))
		rig.brows(0.035 * attention, 0.11 * attention)
		rig.eyes(1.0 + 0.06 * attention)
		rig.mouth(1.0 + attention * (0.22 if character != 4 else -0.12))
		match character:
			0: right_pose += 0.25 * attention
			1:
				left_pose += 0.19 * attention
				right_pose += 0.19 * attention
				rig.turn("Crest_L", Vector3(0, 0, -crest_motion - 0.16 * attention))
				rig.turn("Crest_R", Vector3(0, 0, crest_motion + 0.16 * attention))
			2:
				left_pose += 0.13 * attention
				right_pose += 0.13 * attention
			3:
				left_pose += 0.21 * attention
				rig.turn("Antenna", Vector3(0, 0, -attention_direction.x * 0.16 * attention))
			4: left_pose += 0.14 * attention
	if world.finale_age >= 0 and alive and not airborne and held <= 0:
		# One staggered flourish, then a quiet sustained pose; no endless cheering.
		var local_age = maxf(0, world.finale_age - index * 0.055)
		var arrival = clampf(local_age / 0.26, 0, 1)
		var flourish = pow(sin(clampf(local_age / 1.05, 0, 1) * PI), 2) * motion
		gesture = 0.0
		if world.finale_won:
			left_pose = (0.09 * arrival + flourish * [0.16, 0.27, 0.19, 0.23, 0.11][character]) * motion
			right_pose = (0.09 * arrival + flourish * [0.31, 0.27, 0.19, 0.14, 0.22][character]) * motion
			rig.gaze(Vector2(0.25, -0.35) * arrival * motion)
			rig.mouth(1.0 + (0.12 * arrival + 0.16 * flourish) * motion)
			rig.brows(0.016 * arrival * motion, 0.035 * motion)
		else:
			left_pose = -0.08 * arrival * motion
			right_pose = -0.08 * arrival * motion
			rig.gaze(Vector2(0, -0.7) * arrival * motion)
			rig.mouth(1.0 - 0.12 * arrival * motion)
			rig.brows(-0.012 * arrival * motion, -0.10 * arrival * motion)
	var lift_arms = (0.20 if held > 0 else 0.0) * motion
	rig.turn("Hand_L", Vector3(0, 0, -arms - lift_arms - left_pose))
	rig.turn("Hand_R", Vector3(0, 0, arms + lift_arms + right_pose))
	rig.turn("Hat", Vector3((sin(phase * 0.6) * 0.025 + (gesture * 0.10 if kind == "pirate" and index == 5 and not airborne and held <= 0 and exposed <= 0 else 0.0)), 0, sin(phase) * 0.035) * motion)
	if alive and motion > 0:
		pose_flight()
	if alive:
		rig.fade(0.001 if material_warmup > 0 else 0.0)
		var spring_pulse = sin(clampf(spring_age / 0.30, 0, 1) * TAU) * exp(-spring_age * 10) * 0.22
		var arrival = 1.0 + sin(clampf(appear_age / 0.4, 0, 1) * PI) * exp(-appear_age * 6) * 0.10
		body_visual.scale = Vector3(1.0 - spring_pulse * 0.55 * motion, 1 + (arrival - 1 + sin(phase) * 0.009 + spring_pulse) * motion, 1)
		var landing_pulse = sin(clampf(landing_age / 0.26, 0, 1) * TAU) * exp(-landing_age * 12) * motion
		body_visual.scale.x += landing_pulse * 0.045
		body_visual.scale.y -= landing_pulse * 0.065
		if kind == "pirate":
			body_visual.scale = Vector3.ONE
		body_visual.rotation.z = (sin(phase) * 0.014 + (clampf(velocity * 0.008, -0.04, 0.04) if airborne else 0.0)) * motion
		if kind == "balloon" and not airborne:
			match character:
				0: body_visual.rotation.z += gesture * 0.018
				1: body_visual.scale.x += gesture * 0.016
				2: body_visual.rotation.z = sin(phase * 0.35) * 0.022 * motion
				3: body_visual.scale.y += gesture * 0.012
				4: body_visual.rotation.z -= gesture * 0.026
		body_visual.position = Vector3.ZERO
		weak_visual.visible = true
	elif death_age >= 0:
		death_age += delta
		animate_retirement(motion)
	if shield_visual:
		if shield_break_age >= 0:
			shield_break_age += delta
			var p = clampf(shield_break_age / 0.32, 0, 1)
			shield_visual.position = Vector3(p * 0.30, -p * p * 0.75, 0.32 + p * 0.40)
			shield_visual.rotation = Vector3(p * 1.7, p * 0.8, p * 0.55)
			shield_visual.scale = Vector3.ONE * (1 - p * 0.45)
			shield_visual.visible = alive and p < 1
		else:
			shield_open = move_toward(shield_open, 0.0 if is_shielded() else 1.0, delta * 8)
			var cover_basis = Basis.from_euler(Vector3(shield_open * PI * 0.6, 0, 0))
			var center = SHIELD_CLOSED + SHIELD_HINGE - cover_basis * SHIELD_HINGE
			# Match the board's decorative pose so the visible bearing and axle
			# remain attached. Pirate boards stay rigid, unlike balloon shells.
			shield_visual.transform = body_visual.transform * Transform3D(cover_basis, center)
			shield_visual.visible = alive

func pose_flight() -> void:
	# Ballistics provide the phase. Only decorative pivots change: the root,
	# hit volumes and visible scoring centre keep their existing trajectory.
	if not airborne:
		var tail = 1.0 - smoothstep(0.0, 0.28, landing_age)
		if tail > 0:
			for part in flight_last_pose:
				rig.parts[part].transform = rig.parts[part].transform.interpolate_with(flight_last_pose[part], tail)
		else:
			flight_last_pose.clear()
		return
	var ascent = clampf(velocity / 6.4, 0, 1)
	var descent = clampf(-velocity / 6.4, 0, 1)
	var apex = 1.0 - smoothstep(0.0, 2.2, absf(velocity))
	var pop = sin(clampf(spring_age / 0.18, 0, 1) * PI) * exp(-spring_age * 8)
	var character = index % 5
	var left = 0.28 + ascent * 0.20 + descent * 0.12
	var right = left
	var gaze_x = 0.0
	var crest = 0.10 + ascent * 0.10 - descent * 0.16
	if kind == "balloon":
		match character:
			0:
				left *= 0.65
				right += apex * 0.14
				gaze_x = -0.25 * ascent
			1:
				left += apex * 0.10
				right = left
				crest += pop * 0.12
			2:
				left = 0.30 + descent * 0.18
				right = left
				crest *= 0.60
			3:
				left += apex * 0.16
				right *= 0.72
				gaze_x = 0.22 * apex
			4:
				left = 0.22 + descent * 0.22
				right = 0.32 + ascent * 0.12
				crest = 0.10 - descent * 0.24
				gaze_x = -0.30 * apex
	else:
		# The captain's rigid board keeps a restrained brace and lagging hat.
		left *= 0.70
		right *= 0.80
		rig.turn("Hat", Vector3(-ascent * 0.10 + descent * 0.065, 0, pop * 0.045))
	var takeoff = smoothstep(0.0, 0.10, spring_age)
	rig.turn("Hand_L", Vector3(0, 0, lerpf(flight_hand_start.x, -left - pop * 0.06, takeoff)))
	rig.turn("Hand_R", Vector3(0, 0, lerpf(flight_hand_start.y, right + pop * 0.06, takeoff)))
	rig.eyes(1.06 + apex * 0.065 - descent * 0.015)
	rig.gaze(Vector2(gaze_x, ascent * 0.65 + apex * 0.15 - descent * 0.52))
	rig.brows(0.037 + apex * 0.016 + pop * 0.012, 0.10 + descent * 0.045)
	rig.mouth(1.12 + apex * (0.18 if character == 4 else 0.28) + descent * 0.10)
	rig.turn("Crest_L", Vector3(0, 0, -crest))
	rig.turn("Crest_R", Vector3(0, 0, crest))
	rig.turn("Antenna", Vector3(0, 0, sin(spring_age * 19) * exp(-spring_age * 3.5) * 0.16 + ascent * 0.10 - descent * 0.07))
	for part in ["Eye_L", "Eye_R", "Pupil_L", "Pupil_R", "Brow_L", "Brow_R", "Mouth", "Hand_L", "Hand_R", "Crest_L", "Crest_R", "Antenna", "Hat"]:
		if rig.parts.has(part):
			flight_last_pose[part] = rig.parts[part].transform

func animate_retirement(motion: float) -> void:
	var p = clampf(death_age / death_duration, 0, 1)
	var shock = sin(clampf(death_age / 0.16, 0, 1) * PI)
	var fall = clampf((p - 0.15) / 0.85, 0, 1)
	var turn = death_side * fall
	var pose_rotation = Vector3(fall * 0.65, 0, turn * 0.32)
	var pose_position = Vector3(turn * 0.18, -fall * fall * 1.75, -fall * 0.24)
	var pose_scale = Vector3(1 + shock * 0.12, 1 - shock * 0.14, 1) * (1 - fall * 0.32)
	if kind == "pirate":
		# Flat wooden targets fold backwards rather than squash like upholstery.
		pose_rotation = Vector3(-fall * 1.45, turn * 0.12, turn * 0.14)
		var hinge = Vector3(0, -0.85, 0)
		pose_position = hinge - Basis.from_euler(pose_rotation) * hinge + Vector3(turn * 0.05, -fall * 0.18, 0)
		pose_scale = Vector3.ONE
		rig.turn("Hat", Vector3(-shock * 0.22, 0, death_side * shock * 0.16) * motion)
	else:
		match index % 5:
			0: pose_rotation.z += turn * 0.28
			1: pose_position.x += sin(p * TAU * 2) * 0.06 * (1 - p)
			2: pose_rotation.y += turn * 0.65
			3: rig.turn("Antenna", Vector3(0, 0, sin(p * TAU * 3) * 0.38 * (1 - p)) * motion)
			4:
				rig.turn("Crest_L", Vector3(0, 0, fall * 0.48) * motion)
				rig.turn("Crest_R", Vector3(0, 0, -fall * 0.48) * motion)
	if death_air:
		pose_position.y += sin(p * PI) * 0.20
		pose_rotation.z += turn * 0.60
		# Airborne paper toys contract into the existing flecks. Grounded ones
		# retire behind the stage lip instead of becoming a dark translucent face.
		pose_scale *= 1.0 - fall * fall * 0.94
	if death_weak:
		pose_scale.x += shock * 0.06
	body_visual.transform = death_pose
	body_visual.position += pose_position * motion
	body_visual.rotation += pose_rotation * motion
	body_visual.scale *= Vector3.ONE.lerp(pose_scale, motion)
	rig.eyes(1.0 + shock * 0.18 * motion)
	rig.gaze(Vector2(death_side, 0.85) * shock * motion)
	rig.brows(shock * 0.055 * motion, shock * 0.24 * motion)
	rig.mouth(1.0 + shock * 0.55 * motion)
	rig.turn("Hand_L", Vector3(0, 0, -(shock * 0.58 + fall * 0.18)) * motion)
	rig.turn("Hand_R", Vector3(0, 0, (shock * 0.58 + fall * 0.18)) * motion)
	rig.fade(maxf(0, (p - 0.86) / 0.14))
	weak_visual.visible = p < 0.12
	body_visual.visible = p < 1

func sync_visuals() -> void:
	body_visual.visible = alive or (death_age >= 0 and death_age < death_duration)
	tether.visible = alive and not airborne
	body_hit.collision_layer = 1 if alive else 0
	weak_hit.collision_layer = 1 if alive else 0
	air_marker.visible = alive and airborne
	if shield_visual:
		shield_visual.visible = alive and (not shield_broken or shield_break_age < 0.32)
		shield_hit.collision_layer = 1 if alive and is_shielded() else 0
