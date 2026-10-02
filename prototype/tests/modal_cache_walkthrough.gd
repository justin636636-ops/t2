extends "res://tests/feedback_walkthrough.gd"
## Actual visible buttons/keyboard, current data and bounded retained presentation.
func screenshot(name_: String) -> void:
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v22-modal-" + name_ + ".png"))
func click(control: Control) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(12)
func find_button(text: String) -> Button:
	for child in game.hud.modal_content.get_children():
		if child is Button and text in child.text:return child
	return null
func active_page() -> bool:
	return game.hud.modal_pages.values().filter(func(page):return page.visible).size() == 1
func valid_callbacks() -> bool:
	for page in game.hud.modal_pages.values():
		for child in page.get_children():
			if child is CheckButton:
				if child.toggled.get_connections().size() != 1:return false
			elif child is Button and child.pressed.get_connections().size() != 1:return false
	return true
func real_win() -> void:
	await begin(0)
	await shoot(game.world.bell.global_position)
	await frames(22)
	for i in range(5,9):
		await shoot(game.world.targets[i].weak_hit.global_position)
		if i<8:await frames(22)
	await frames(90)
func run() -> void:
	window_review = "--window-review" in OS.get_cmdline_user_args()
	root.size = Vector2i(1440,900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await frames(40)
	var hud = game.hud
	var welcome_id = hud.modal_content.get_instance_id()
	check(active_page() and root.gui_get_focus_owner() == find_button("开场营业"), "welcome has only one visible page and its actual play button receives focus")
	await click(find_button("第一次来"))
	check(hud.modal_page_key == "tutorial" and game.state == game.State.READY, "real tutorial click changes only the presentation page")
	await click(find_button("返回标题"))
	check(hud.modal_content.get_instance_id() == welcome_id and hud.modal_refs.welcome.heading.get_theme_font_size("font_size") == 60, "returning to retained welcome keeps its original heading and live play action")
	await click(find_button("声音与动态"))
	var settings_id = hud.modal_content.get_instance_id()
	check(hud.settings_visible and root.gui_get_focus_owner() is HSlider and is_equal_approx(hud.modal_refs.settings.volume.value,game.audio_volume*100), "actual settings open uses current volume and slider focus")
	await keyboard(KEY_ESCAPE)
	check(hud.modal_page_key == "welcome" and hud.modal_content.get_instance_id() == welcome_id, "settings Escape returns to the current welcome owner")
	await click(find_button("开场营业"))
	await frames(25)
	await keyboard(KEY_TAB)
	var configure_id = hud.modal_content.get_instance_id()
	await click(find_button("稳妥射击"))
	check(game.ammo == ["normal","normal","normal","normal","normal"] and hud.modal_content.get_instance_id() == configure_id and active_page(), "real loadout click updates one retained configuration page without spending a shot")
	await click(find_button("留中段准备"))
	check(game.ammo[2] == "spring" and "弹簧" in hud.modal_refs.configure.ammo.text, "cached ammo summary reflects the actual newly selected third spring")
	await click(find_button("弹簧地毯"))
	check(not game.world.carpet_enabled and "未装备" in hud.modal_refs.configure.carpet.text, "the existing carpet action updates its retained status button")
	await click(find_button("声音与动态"))
	check(hud.modal_content.get_instance_id() == settings_id and root.gui_get_focus_owner() is HSlider, "configuration reuses settings with live slider focus")
	await keyboard(KEY_RIGHT)
	check(is_equal_approx(game.audio_volume*100,hud.modal_refs.settings.volume.value), "real slider keyboard input still changes the authoritative volume once")
	await click(hud.modal_refs.settings.motion)
	check(game.reduced_motion == hud.modal_refs.settings.motion.button_pressed, "real retained motion toggle updates the game preference")
	await keyboard(KEY_ESCAPE)
	check(hud.modal_page_key == "configure" and hud.modal_content.get_instance_id() == configure_id and "未装备" in hud.modal_refs.configure.carpet.text, "reused settings return to current configuration rather than the earlier welcome callback")
	await click(find_button("弹簧地毯"))
	await click(find_button("稳妥射击"))
	await keyboard(KEY_ESCAPE)
	await shoot(game.world.targets[0].weak_hit.global_position)
	await keyboard(KEY_TAB)
	check(hud.modal_page_key == "pause" and find_button("稳妥射击") == null and game.records.size() == 1, "a real shot switches to the separate locked pause page with no retained loadout buttons")
	await click(find_button("声音与动态"))
	await keyboard(KEY_ESCAPE)
	check(hud.modal_page_key == "pause" and game.state == game.State.PAUSED and active_page(), "settings preserve the locked pause return path")
	game.set_reduced_motion(false)
	await real_win()
	var ticket_id = hud.score_ticket.get_instance_id()
	check(game.total_score == 4605 and hud.score_ticket.score.text == "4605" and hud.score_ticket.completed, "actual five-shot harvest fully stamps its truthful score before reuse")
	await keyboard(KEY_ENTER)
	await frames(80)
	check(hud.modal_page_key == "win" and root.gui_get_focus_owner() == find_button("再营业"), "actual winner page takes focus and retains the native restart action")
	await click(find_button("声音与动态"))
	await keyboard(KEY_ESCAPE)
	check(hud.modal_page_key == "win" and "4605" in hud.modal_refs.win.score.text and not game.world.gun.visible, "reused settings return to the current winning card without showing combat widgets")
	await click(find_button("再营业"))
	check(game.state == game.State.READY and hud.score_ticket == null and hud.modal_content.get_instance_id() == welcome_id, "actual cached restart clears the receipt owner and returns the same welcome")
	await begin(0)
	await shoot(game.world.targets[0].weak_hit.global_position)
	var event=InputEventKey.new()
	event.keycode=KEY_R
	event.physical_keycode=KEY_R
	event.pressed=true
	Input.parse_input_event(event)
	await frames(24)
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await frames(2)
	check(hud.score_ticket.get_instance_id() == ticket_id and hud.score_ticket.score.text == "116" and not hud.score_ticket.completed and hud.score_ticket.stamped_count < 5, "new actual early receipt reuses paper but resets old score, marks and finished animation")
	await frames(70)
	await keyboard(KEY_SPACE)
	await shoot(Vector3(-7.1,5.5,-4))
	await frames(22)
	event.pressed=true
	Input.parse_input_event(event)
	await frames(24)
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	await frames(60)
	check(hud.score_ticket.score.text == "0" and hud.score_ticket.rows[1].labels[1].text == "无追加" and hud.score_ticket.rows[4].labels[1].text == "未触发", "real miss receipt replaces previous positive details without stale ink")
	for group in range(3,5):
		await keyboard(KEY_SPACE)
		await shoot(Vector3(-7.1,5.5,-4))
		await frames(22)
		event.pressed=true
		Input.parse_input_event(event)
		await frames(24)
		event=event.duplicate()
		event.pressed=false
		Input.parse_input_event(event)
		await frames(60)
	await keyboard(KEY_SPACE)
	await frames(80)
	check(game.state==game.State.END and not game.world.finale_won and hud.modal_page_key=="loss" and "116" in hud.modal_refs.loss.score.text, "three real miss groups after the early harvest produce the current 116-point failure card")
	await click(find_button("声音与动态"))
	await keyboard(KEY_ESCAPE)
	check(hud.modal_page_key=="loss" and "1684" in hud.modal_refs.loss.subtitle.text and active_page(), "settings return to the current losing owner rather than a retained win callback")
	screenshot("loss")
	var node_count=hud.modal.find_children("*","Control",true,false).size()
	var page_count=hud.modal_pages.size()
	for i in range(30):
		game.reset_round()
		game.start_round()
		game.toggle_pause()
		game.set_loadout(i%3)
		hud.show_settings(hud.show_pause)
		hud.close_settings()
		game.toggle_pause()
		await frames(1)
	check(hud.modal_pages.size()==page_count and page_count==8 and hud.modal.find_children("*","Control",true,false).size()==node_count, "thirty repeated real reset/config/settings transitions keep the eight-page node population bounded")
	check(valid_callbacks() and hud.cached_score_ticket.row_cache.size()==5 and hud.cached_score_ticket.resized.get_connections().size()==1, "retained buttons and receipt resize each keep one live callback and five authored rows")
	game.toggle_pause()
	if window_review:
		for size_ in [Vector2i(1152,720),Vector2i(1920,1080)]:
			root.size=size_
			await frames(20)
			var buttons=hud.modal_content.get_children().filter(func(child):return child is Button)
			check(root.get_visible_rect().encloses(hud.modal.get_global_rect()) and buttons.all(func(button):return hud.modal.get_global_rect().encloses(button.get_global_rect())), "retained native configuration fits all live buttons at width "+str(size_.x))
			screenshot("configuration-"+str(size_.x))
		root.size=Vector2i(1440,900)
		await frames(12)
	print("MODAL CACHE REVIEW: ",JSON.stringify({"passed":passed,"failed":failed,"window_review":window_review,"pages":hud.modal_pages.size(),"cached_control_count":node_count,"actual_outcomes":outcomes,"paper_rows":hud.cached_score_ticket.row_cache.size(),"live_callbacks_valid":valid_callbacks()}))
	await frames(24)
	for player in game.sound_players:
		player.stop()
		player.stream=null
	await frames(3)
	quit.call_deferred(1 if failed else 0)
