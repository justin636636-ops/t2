extends Node3D

const Rules = preload("res://scripts/rules.gd")
const World = preload("res://scripts/world.gd")
const Hud = preload("res://scripts/hud.gd")
enum State { READY, AIMING, PAUSED, SCORE, END }

var world: Node3D
var hud: CanvasLayer
var state = State.READY
var ammo: Array = ["spring", "normal", "normal", "normal", "normal"]
var core_ids: Array = ["spring-01", "normal-01", "normal-02", "normal-03", "normal-04"]
var equipment: Array = ["paper", "metronome", "smile"]
var records: Array = []
var group_index = 1
var time_left = Rules.ROUND_SECONDS
var total_score = 0
var duck_energy = 0
var duck_level = 0
var group_duck_level = 0
var duck_used = false
var hold_time = 0.0
var r_held = false
var cooldown = 0.0
var aim = Vector2(720, 450)
var hover_text = ""
var queued_shot = false
var queued_position = Vector2.ZERO
var focus = false
var sound_on = true
var sound_players: Array = []
var sound_index = 0
var settled_group = -1
var last_result: Dictionary = {}
var saw_relay = false
var saw_bounce = false
var saw_duck = false
var capture_elapsed = 0.0
var capture_written = false
var capture_path = ""
var reduced_motion = false
var audio_volume = 0.8
var audio_cache: Dictionary = {}

func _ready() -> void:
	world = World.new()
	add_child(world)
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	world.carpet_bounced.connect(on_carpet_bounced)
	for i in range(4):
		var player = AudioStreamPlayer.new()
		add_child(player)
		sound_players.append(player)
	for kind in ["shot", "hit", "spring", "score", "shield", "bell", "duck", "precision"]:
		audio_cache[kind] = load("res://assets/audio/" + kind + ".wav")
	load_preferences()
	hud.show_start()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		if arg == "--autostart":
			start_round()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.AIMING and hud != null and "--review" not in OS.get_cmdline_user_args():
		toggle_pause()

func _input(event: InputEvent) -> void:
	# Tab must reach pause/config before Control's built-in focus traversal.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE, KEY_ENTER] and state == State.SCORE and not hud.settings_visible:
			continue_group()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_ESCAPE and hud.settings_visible:
			hud.close_settings()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode in [KEY_TAB, KEY_ESCAPE] and state in [State.AIMING, State.PAUSED] and not hud.settings_visible:
			toggle_pause()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		aim = event.position
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			focus = false
	if event is InputEventKey and not event.pressed and event.physical_keycode == KEY_R:
		r_held = false
		hold_time = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE, KEY_ENTER:
				if state == State.READY:
					start_round()
				elif state == State.SCORE:
					continue_group()
				get_viewport().set_input_as_handled()
			KEY_R:
				if state == State.AIMING and not records.is_empty():
					r_held = true
	if event is InputEventMouseButton and event.pressed and state == State.AIMING:
		if event.button_index == MOUSE_BUTTON_LEFT:
			queue_shot(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			focus = true

func queue_shot(screen_position: Vector2) -> void:
	if state != State.AIMING or cooldown > 0 or queued_shot or records.size() >= 5:
		return
	# Desk/HUD clicks never spend ammunition.
	if screen_position.y < 130 or screen_position.y > 690:
		return
	queued_shot = true
	queued_position = screen_position

func _physics_process(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	if state == State.AIMING:
		time_left = maxf(0, time_left - delta)
		if time_left <= 0:
			queued_shot = false
			settle("timeout")
		else:
			world.update_world(delta, true, group_index)
			for target in world.targets:
				if target.carpet_used:
					saw_bounce = true
			if queued_shot:
				queued_shot = false
				resolve_shot(queued_position)
			if state == State.AIMING and r_held:
				hold_time += delta
				if hold_time >= Rules.HOLD_SECONDS:
					settle("early")
			if state == State.AIMING:
				update_hover()
	else:
		world.update_world(delta, false, group_index, state != State.PAUSED)

func _process(delta: float) -> void:
	var half_view = get_viewport().get_visible_rect().size / 2
	world.gun_aim = (aim - half_view) / half_view
	world.camera.fov = move_toward(world.camera.fov, 47.0 if focus and state == State.AIMING else 57.0, delta * 65)
	hud.update_hud(delta)
	if not capture_path.is_empty() and not capture_written:
		capture_elapsed += delta
		if capture_elapsed > 2:
			capture_written = true
			capture_frame.call_deferred()

func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var result = image.save_png(capture_path)
	print("CAPTURE: ", capture_path, " result=", result)

func raycast(screen_position: Vector2) -> Dictionary:
	var cam = world.camera
	var origin = cam.project_ray_origin(screen_position)
	var end = origin + cam.project_ray_normal(screen_position) * 60
	var query = PhysicsRayQueryParameters3D.create(origin, end, 3)
	return get_world_3d().direct_space_state.intersect_ray(query)

func update_hover() -> void:
	hover_text = ""
	# A stable fallback keeps the viewmodel aimed at the stage even between
	# targets. Valid hits use their exact depth for muzzle convergence.
	var view_size = get_viewport().get_visible_rect().size
	var stage_aim = Vector2(clampf(aim.x, 24, view_size.x - 24), clampf(aim.y, 130, 690))
	world.gun_focus = world.camera.project_ray_origin(stage_aim) + world.camera.project_ray_normal(stage_aim) * 16.0
	if aim.y < 130 or aim.y > 690:
		return
	var hit = raycast(aim)
	if hit.is_empty():
		return
	world.gun_focus = hit.position
	var collider: Object = hit.collider
	if collider.has_meta("mechanism"):
		hover_text = "铃铛冷却中" if world.bell_cooldown > 0 else "射击翻盖 · 机关 +5"
	elif collider.has_meta("target"):
		var target: Node3D = collider.get_meta("target")
		var part: String = collider.get_meta("part")
		if ammo[records.size()] == "spring":
			hover_text = "护盾挡住准备弹" if part == "shield" else ("已在空中，不会重复弹起" if target.airborne else "弹起目标 · 基础分 0")
		elif part == "shield":
			hover_text = "破盾 +5 · 下一枪可收割"
		elif part == "weak":
			hover_text = "空中弱点！" if target.airborne else "弱点 +15"
		else:
			hover_text = "气球怪 +20" if target.kind == "balloon" else "木牌海盗 +30"

func resolve_shot(screen_position: Vector2) -> void:
	if state != State.AIMING or records.size() >= 5:
		return
	var slot = records.size()
	var hit = raycast(screen_position)
	var record = {"slot": slot, "core_id": core_ids[slot], "ammo": ammo[slot], "base": 0, "valid": false, "destroyed": false, "weak": false, "air": false, "relay": false, "direct_kills": 0, "display": "空枪", "target": -1, "source_shot": -1, "group": group_index}
	var end = world.camera.project_ray_origin(screen_position) + world.camera.project_ray_normal(screen_position) * 40
	if not hit.is_empty():
		end = hit.position
		var collider: Object = hit.collider
		if collider.has_meta("mechanism"):
			var level = group_duck_level if not duck_used else 0
			var affected = world.activate_bell(group_index, slot, level)
			if not affected.is_empty():
				record.valid = true
				record.base = 5
				record.display = "机关 +5"
				world.score_popup(hit.position, 5, "翻盖")
				play_sound("bell")
				if level > 0:
					duck_used = true
					play_sound("duck")
					saw_duck = true
					hud.toast("鸭子出手 · 追击海盗")
			else:
				record.display = "未响应"
				hud.toast("铃铛冷却或没有可翻盖的海盗", hud.CORAL)
		elif collider.has_meta("target"):
			var target: Node3D = collider.get_meta("target")
			var part: String = collider.get_meta("part")
			record.target = target.index
			record.generation = target.generation
			if ammo[slot] == "spring":
				if part == "shield":
					record.display = "被盾挡住"
					hud.toast("弹簧弹不伤害护盾，试试前排无盾怪物", hud.CORAL)
				elif target.launch(group_index, slot):
					record.valid = true
					record.display = "弹起 ↑"
					play_sound("spring")
				else:
					record.display = "无新变化"
					hud.toast("目标已弹起；准备弹不重复制造来源", hud.CORAL)
			elif part == "shield":
				record.valid = true
				record.base = 5
				record.display = "破盾 +5"
				target.break_shield()
				play_sound("shield")
				world.score_popup(target.global_position, 5, "破盾")
			else:
				record.valid = true
				record.destroyed = true
				record.weak = part == "weak"
				record.air = target.airborne
				record.relay = target.preparation_group == group_index and target.preparation_shot >= 0 and target.preparation_shot < slot
				record.source_shot = target.preparation_shot if record.relay else -1
				record.direct_kills = 1
				record.base = (20 if target.kind == "balloon" else 30) + (15 if record.weak else 0)
				record.display = ("空中靶心" if record.air else "弱点") if record.weak else ("空中击破" if record.air else "击破")
				world.score_popup(target.global_position, record.base, record.display, record.air)
				target.destroy(hit.position, record.weak)
				if record.relay:
					saw_relay = true
					hud.toast("准备接力！基础 +25 · 倍率 +1")
				play_sound("hit")
				if record.weak:
					play_sound("precision")
		if not record.destroyed and record.display != "破盾 +5" and not (record.valid and record.ammo == "spring" and record.target >= 0):
			world.vfx.impact(hit.position, false, true)
	world.react_to_shot(record, end)
	records.append(record)
	hud.on_shot(record, screen_position)
	cooldown = 0.25
	world.shot_effect(end, ammo[slot] == "spring")
	play_sound("shot")
	if records.size() == 5:
		# All implemented ammunition is instantaneous hitscan. Cosmetic tracers
		# are never pending damage, so no artificial projectile wait is needed.
		settle("full")

func settle(reason: String) -> void:
	if state != State.AIMING or settled_group == group_index:
		return
	settled_group = group_index
	state = State.SCORE
	clear_inputs()
	last_result = Rules.evaluate(records, equipment)
	total_score += last_result.score
	var gain = Rules.growth_gain(records, reason)
	duck_energy = mini(9, duck_energy + gain)
	duck_level = Rules.duck_level(duck_energy)
	world.set_duck_level(duck_level)
	hud.show_score(last_result, gain, reason)
	play_sound("score")
	print("GROUP ", group_index, " score=", last_result.score, " C=", last_result.c, " M=", last_result.m, " energy=", duck_energy, " reason=", reason)

func round_finished() -> bool:
	return total_score >= Rules.SCORE_TARGET or group_index >= Rules.MAX_GROUPS or time_left <= 0

func continue_group() -> void:
	if state != State.SCORE:
		return
	if round_finished():
		state = State.END
		world.finish_stage(total_score >= Rules.SCORE_TARGET)
		hud.show_end(total_score >= Rules.SCORE_TARGET)
		return
	group_index += 1
	records = []
	group_duck_level = duck_level
	duck_used = false
	world.begin_group()
	world.reload_weapon()
	hud.on_reload()
	clear_inputs()
	state = State.AIMING
	hud.hide_modal()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func start_round() -> void:
	if state != State.READY:
		return
	state = State.AIMING
	world.open_stage()
	world.reload_weapon()
	hud.on_reload()
	hud.hide_modal()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	clear_inputs()
	play_sound("score")

func reset_round() -> void:
	state = State.READY
	records = []
	group_index = 1
	time_left = Rules.ROUND_SECONDS
	total_score = 0
	duck_energy = 0
	duck_level = 0
	group_duck_level = 0
	duck_used = false
	settled_group = -1
	saw_relay = false
	saw_bounce = false
	saw_duck = false
	cooldown = 0
	world.reset_world()
	world.set_duck_level(0)
	hud.on_reload()
	clear_inputs()
	hud.show_start()

func toggle_pause() -> void:
	if state == State.AIMING:
		state = State.PAUSED
		clear_inputs()
		hud.show_pause()
	elif state == State.PAUSED:
		state = State.AIMING
		clear_inputs()
		hud.hide_modal()
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func set_loadout(preset: int) -> void:
	if state != State.PAUSED or not records.is_empty():
		return
	ammo = ["normal", "normal", "normal", "normal", "normal"]
	core_ids = ["normal-01", "normal-02", "normal-03", "normal-04", "normal-05"]
	if preset == 1:
		ammo[0] = "spring"
		core_ids = ["spring-01", "normal-01", "normal-02", "normal-03", "normal-04"]
	elif preset == 2:
		ammo[2] = "spring"
		core_ids = ["normal-01", "normal-02", "spring-01", "normal-03", "normal-04"]
	hud.show_pause()

func toggle_carpet() -> void:
	if state != State.PAUSED or not records.is_empty():
		return
	world.carpet_enabled = not world.carpet_enabled
	world.carpet.visible = world.carpet_enabled
	hud.show_pause()

func clear_inputs() -> void:
	r_held = false
	hold_time = 0
	queued_shot = false
	focus = false

func preview() -> Dictionary:
	return Rules.evaluate(records, equipment)

func growth_preview() -> int:
	return Rules.growth_gain(records, "early")

func on_carpet_bounced() -> void:
	play_sound("spring")
	hud.toast("地毯回弹 · 追击空中靶心")

func is_aiming() -> bool:
	return state == State.AIMING

func ammo_display() -> String:
	var names: Array = []
	for core in ammo:
		names.append("弹簧" if core == "spring" else "普通")
	return " / ".join(names)

func duck_description() -> String:
	return ["交出真实余弹，到 3 储能学会牵住。", "本组首次有效铃铛：牵住一个海盗 0.8 秒。", "牵住时翻开遮挡，后续普通弹可打原弱点。", "首次有效铃铛：翻盖后弹起一个海盗。"] [duck_level]

func has_live_preparation() -> bool:
	for target in world.targets:
		if target.alive and target.airborne and target.preparation_group == group_index:
			return true
	return false

func toggle_sound() -> void:
	sound_on = not sound_on
	hud.mute_button.text = "音效 开" if sound_on else "音效 关"
	if not sound_on:
		for player in sound_players:
			player.stop()

func play_sound(kind: String) -> void:
	if not sound_on or audio_volume <= 0 or DisplayServer.get_name() == "headless":
		return
	var player: AudioStreamPlayer = sound_players[sound_index]
	player.stream = audio_cache.get(kind, audio_cache.shot)
	player.volume_db = linear_to_db(maxf(0.0001, audio_volume))
	player.pitch_scale = 1.0 if kind in ["score", "duck", "precision"] else randf_range(0.96, 1.04)
	player.play()
	sound_index = (sound_index + 1) % sound_players.size()

func set_audio_volume(value: float) -> void:
	audio_volume = clampf(value, 0, 1)
	for player in sound_players:
		player.volume_db = linear_to_db(maxf(0.0001, audio_volume))
		if audio_volume <= 0:
			player.stop()
	save_preferences()

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	world.reduced_motion = enabled
	world.vfx.reduced_motion = enabled
	save_preferences()

func load_preferences() -> void:
	if DisplayServer.get_name() == "headless" or "--review" in OS.get_cmdline_user_args():
		return
	var config = ConfigFile.new()
	if config.load("user://presentation.cfg") == OK:
		set_audio_volume(config.get_value("presentation", "volume", 0.8))
		set_reduced_motion(config.get_value("presentation", "reduced_motion", false))

func save_preferences() -> void:
	if DisplayServer.get_name() == "headless" or "--review" in OS.get_cmdline_user_args():
		return
	var config = ConfigFile.new()
	config.set_value("presentation", "volume", audio_volume)
	config.set_value("presentation", "reduced_motion", reduced_motion)
	config.save("user://presentation.cfg")
