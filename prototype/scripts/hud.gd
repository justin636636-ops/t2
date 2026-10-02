extends CanvasLayer

const ShotFeedback = preload("res://scripts/shot_feedback.gd")
const ArtFonts = preload("res://scripts/art_fonts.gd")
const ScoreTicket = preload("res://scripts/score_ticket.gd")

const INK = Color("eadcc0")
const GOLD = Color("c7aa72")
const MUTED = Color("aca99e")
const MINT = Color("8cbea3")
const CORAL = Color("c7806e")
const NIGHT = Color(0.06, 0.08, 0.12, 0.96)
var game: Node3D
var root: Control
var overlay: Control
var modal: Panel
var modal_content: VBoxContainer
var score_label: Label
var timer_label: Label
var group_label: Label
var next_label: Label
var next_detail: Label
var preview_label: Label
var duck_label: Label
var hint_label: Label
var progress: ProgressBar
var hold_bar: ProgressBar
var slots: Array = []
var toast_label: Label
var toast_panel: Panel
var toast_age = 0.0
var toast_tint = MINT
var slot_pulses: Array[float] = []
var reload_age = 1.0
var target_label: Label
var crosshair: Control
var crosshair_label: Label
var hold_label: Label
var tests_label: Label
var mute_button: Button
var toast_time = 0.0
var equipment_label: Label
var ticket_styles: Dictionary = {}
var title_font: Font
var number_font: Font
var shot_feedback: Control
var modal_tween: Tween
var displayed_score = 0.0
var settings_visible = false
var settings_return: Callable
var modal_revision = 0
var modal_mode = "standard"
var dim: ColorRect
var score_reveal_remaining = 0.0
var score_ticket: Control
var modal_pages: Dictionary = {}
var modal_refs: Dictionary = {}
var modal_page_key = "welcome"
var modal_page_fresh = true
var cached_score_ticket: Control

func _ready() -> void:
	title_font = ArtFonts.get_font("title")
	number_font = ArtFonts.get_font("number")
	var font = ArtFonts.get_font()
	var theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", NIGHT)
	theme.set_stylebox("normal", "Button", style(Color("263139"), Color("8a7550"), 1, 3))
	theme.set_stylebox("hover", "Button", style(GOLD, GOLD, 1, 3))
	theme.set_stylebox("pressed", "Button", style(Color("8b774b"), GOLD, 1, 3))
	theme.set_stylebox("focus", "Button", style(Color(0, 0, 0, 0), INK, 2, 3))
	for name_ in ["slider", "grabber_area", "grabber_area_highlight"]:
		var slider_style = bar_style(Color("33423e") if name_ == "slider" else GOLD)
		slider_style.content_margin_top = 3
		slider_style.content_margin_bottom = 3
		theme.set_stylebox(name_, "HSlider", slider_style)
	theme.set_stylebox("focus", "HSlider", style(Color.TRANSPARENT, INK, 1, 3))
	theme.set_icon("grabber", "HSlider", load("res://assets/ui/knob.svg"))
	theme.set_icon("grabber_highlight", "HSlider", load("res://assets/ui/knob.svg"))
	theme.set_icon("checked", "CheckButton", load("res://assets/ui/toggle_on.svg"))
	theme.set_icon("unchecked", "CheckButton", load("res://assets/ui/toggle_off.svg"))
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)
	build()
	# Prepare the eight finite layouts during scene setup, before play begins.
	# These are presentation calls only; game records/state/score stay untouched.
	show_start()
	show_tutorial()
	show_pause()
	modal_page_key = "pause"
	# Locked and unlocked pause have different controls. Build the locked page
	# without fabricating a shot or changing the game's records.
	clear_modal("暂停营业", "时间与场景运动已暂停", 475)
	build_pause_content(false)
	show_score(game.preview(), 0, "timeout")
	show_end(true)
	show_end(false)
	show_settings(show_start)
	show_start()
	root.resized.connect(_on_resized)

func _on_resized() -> void:
	if is_instance_valid(overlay) and overlay.visible:
		fit_modal.call_deferred()

func style(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 3) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func bar_style(color: Color) -> StyleBoxFlat:
	var s = style(color, Color.TRANSPARENT, 0, 2)
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	return s

func panel(parent: Control, pos: Vector2, size_: Vector2, color: Color = NIGHT, border: Color = Color("65515e")) -> Panel:
	var p = Panel.new()
	p.position = pos
	p.size = size_
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", style(color, border, 1, 3))
	parent.add_child(p)
	return p

func label(parent: Control, text: String, pos: Vector2, size_: Vector2, font_size: int = 18, color: Color = INK) -> Label:
	var l = Label.new()
	l.text = text
	l.position = pos
	l.size = size_
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func button(parent: Control, text: String, pos: Vector2, size_: Vector2, action: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.position = pos
	b.size = size_
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func anchored(parent: Control, preset: int, offset: Vector2, size_: Vector2) -> Control:
	var c = Control.new()
	parent.add_child(c)
	c.set_anchors_and_offsets_preset(preset)
	if preset == Control.PRESET_BOTTOM_WIDE:
		c.offset_left = offset.x
		c.offset_right = -offset.x
		c.offset_top = offset.y
		c.offset_bottom = offset.y + size_.y
	else:
		c.position += offset
		c.size = size_
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func texture(parent: Control, name_: String, pos: Vector2, size_: Vector2) -> TextureRect:
	var t = TextureRect.new()
	t.texture = load("res://assets/ui/" + name_ + ".svg")
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = pos
	t.size = size_
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

func frame_style() -> StyleBoxTexture:
	var s = StyleBoxTexture.new()
	s.texture = load("res://assets/ui/frame.svg")
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		s.set_texture_margin(side, 22)
		s.set_content_margin(side, 18)
	return s

func ticket_style(active: bool) -> StyleBoxTexture:
	if not ticket_styles.has(active):
		var s = StyleBoxTexture.new()
		s.texture = load("res://assets/ui/ticket_active.svg" if active else "res://assets/ui/ticket.svg")
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			s.set_texture_margin(side, 13)
		ticket_styles[active] = s
	return ticket_styles[active]

func build() -> void:
	var vignette = texture(root, "vignette", Vector2.ZERO, Vector2(1440, 900))
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var chapter = anchored(root, Control.PRESET_TOP_LEFT, Vector2(30, 24), Vector2(310, 98))
	texture(chapter, "crown", Vector2(0, 4), Vector2(47, 47))
	label(chapter, "午夜游园", Vector2(57, 4), Vector2(240, 24), 14, GOLD)
	var chapter_title = label(chapter, "海盗船", Vector2(57, 27), Vector2(240, 45), 29)
	chapter_title.add_theme_font_override("font", title_font)
	label(chapter, "第一幕  /  营业中", Vector2(57, 69), Vector2(240, 24), 14, MUTED)
	var top_anchor = anchored(root, Control.PRESET_CENTER_TOP, Vector2(-235, 22), Vector2(470, 98))
	var top = panel(top_anchor, Vector2.ZERO, Vector2(470, 91))
	top.add_theme_stylebox_override("panel", frame_style())
	label(top, "累计得分", Vector2(24, 13), Vector2(180, 24), 14, GOLD)
	score_label = label(top, "0", Vector2(23, 35), Vector2(225, 45), 36)
	score_label.add_theme_font_override("font", number_font)
	label(top, "目标  1,800", Vector2(290, 19), Vector2(165, 32), 18, MUTED)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", bar_style(Color("393b3e")))
	progress.add_theme_stylebox_override("fill", bar_style(GOLD))
	top.add_child(progress)
	progress.position = Vector2(287, 61)
	progress.size = Vector2(155, 4)
	var clock = anchored(root, Control.PRESET_TOP_RIGHT, Vector2(-294, 24), Vector2(264, 98))
	label(clock, "剩余时间", Vector2(0, 1), Vector2(124, 22), 14, GOLD)
	timer_label = label(clock, "60.0", Vector2(0, 23), Vector2(155, 48), 34)
	timer_label.add_theme_font_override("font", number_font)
	group_label = label(clock, "第 1 / 4 组", Vector2(0, 73), Vector2(155, 24), 16, MUTED)
	button(clock, "暂停", Vector2(171, 0), Vector2(93, 36), game.toggle_pause)
	mute_button = button(clock, "音效 开", Vector2(171, 45), Vector2(93, 36), game.toggle_sound)
	tests_label = label(clock, "", Vector2(0, 102), Vector2(270, 20), 13, MUTED)
	var hint = anchored(root, Control.PRESET_BOTTOM_LEFT, Vector2(34, -245), Vector2(516, 48))
	var hint_bg = panel(hint, Vector2.ZERO, Vector2(516, 44), Color(0.06, 0.08, 0.12, 0.72), Color.TRANSPARENT)
	label(hint_bg, "◇", Vector2(12, 8), Vector2(28, 28), 19, GOLD)
	hint_label = label(hint_bg, "先用弹簧弹把前排怪物弹起来", Vector2(45, 7), Vector2(459, 30), 17)
	var toast_anchor = anchored(root, Control.PRESET_CENTER_BOTTOM, Vector2(-330, -198), Vector2(660, 40))
	toast_panel = panel(toast_anchor, Vector2.ZERO, Vector2(660, 40), Color(0.06, 0.08, 0.12, 0.94), Color("8a7550"))
	toast_label = label(toast_panel, "", Vector2(18, 0), Vector2(624, 40), 19, GOLD)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.hide()
	# Anchored bottom dock; containers own the three groups and the ticket row.
	var dock = HBoxContainer.new()
	root.add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dock.offset_left = 30
	dock.offset_right = -30
	dock.offset_top = -151
	dock.offset_bottom = -30
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_theme_constant_override("separation", 20)
	var prizes = Panel.new()
	prizes.custom_minimum_size = Vector2(337, 121)
	prizes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prizes.add_theme_stylebox_override("panel", frame_style())
	dock.add_child(prizes)
	label(prizes, "桌上奖品", Vector2(20, 11), Vector2(297, 24), 14, GOLD)
	texture(prizes, "duck", Vector2(16, 40), Vector2(47, 47))
	duck_label = label(prizes, "发条鸭 · 储能 0 / 3", Vector2(74, 41), Vector2(250, 25), 18)
	equipment_label = label(prizes, "地毯 · 靶纸 · 节拍 · 笑脸", Vector2(74, 75), Vector2(250, 25), 14, MUTED)
	var ticket_area = CenterContainer.new()
	ticket_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticket_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.add_child(ticket_area)
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	ticket_area.add_child(row)
	for i in range(5):
		var card = Panel.new()
		card.custom_minimum_size = Vector2(86, 121)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_stylebox_override("panel", ticket_style(i == 0))
		row.add_child(card)
		var number = label(card, "%02d" % (i + 1), Vector2(8, 4), Vector2(24, 20), 12, Color("7d6e51"))
		var icon = texture(card, "bullet", Vector2(27, 17), Vector2(33, 41))
		var ammo_label = label(card, "普通", Vector2(6, 57), Vector2(74, 26), 18, Color("343442"))
		ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var result = label(card, "待射", Vector2(4, 85), Vector2(78, 28), 13, Color("867655"))
		result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slots.append({"panel": card, "number": number, "ammo": ammo_label, "result": result, "icon": icon})
		slot_pulses.append(0.0)
	var next = Panel.new()
	next.custom_minimum_size = Vector2(360, 121)
	next.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next.add_theme_stylebox_override("panel", frame_style())
	dock.add_child(next)
	label(next, "下一发", Vector2(20, 10), Vector2(220, 22), 14, GOLD)
	next_label = label(next, "弹簧弹", Vector2(20, 32), Vector2(330, 37), 27, MINT)
	next_detail = label(next, "非致命 · 弹起无盾目标", Vector2(20, 70), Vector2(330, 22), 15)
	preview_label = label(next, "现在报分  0", Vector2(20, 92), Vector2(330, 18), 13, MUTED)
	var foot = anchored(root, Control.PRESET_BOTTOM_WIDE, Vector2(32, -24), Vector2(1376, 22))
	label(foot, "左键 射击    右键 聚焦    Tab 桌面    Esc 暂停", Vector2.ZERO, Vector2(760, 22), 13, MUTED)
	hold_label = label(foot, "长按 R 提前报分", Vector2(760, 0), Vector2(616, 22), 13, GOLD)
	hold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hold_bar = ProgressBar.new()
	hold_bar.show_percentage = false
	hold_bar.add_theme_stylebox_override("background", bar_style(Color("30383d")))
	hold_bar.add_theme_stylebox_override("fill", bar_style(GOLD))
	foot.add_child(hold_bar)
	hold_bar.position = Vector2(1010, -6)
	hold_bar.size = Vector2(364, 3)
	hold_bar.visible = false
	crosshair = Control.new()
	crosshair.size = Vector2(30, 30)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	shot_feedback = ShotFeedback.new()
	shot_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shot_feedback)
	for rect in [Rect2(0, 14, 7, 1), Rect2(23, 14, 7, 1), Rect2(14, 0, 1, 7), Rect2(14, 23, 1, 7), Rect2(14, 14, 2, 2)]:
		var r = ColorRect.new()
		r.position = rect.position
		r.size = rect.size
		r.color = INK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(r)
	crosshair_label = label(root, "", Vector2.ZERO, Vector2(360, 25), 14, MINT)
	crosshair_label.add_theme_color_override("font_outline_color", NIGHT)
	crosshair_label.add_theme_constant_override("outline_size", 3)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.035, 0.05, 0.09, 0.67)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	modal = panel(overlay, Vector2(420, 210), Vector2(600, 448))
	modal.add_theme_stylebox_override("panel", frame_style())
	modal_content = VBoxContainer.new()
	modal_content.position = Vector2(32, 28)
	modal_content.size = Vector2(536, 390)
	modal_content.add_theme_constant_override("separation", 12)
	modal.add_child(modal_content)
	modal_pages["welcome"] = modal_content
	overlay.visible = false

func clear_modal(title: String, subtitle: String, height: float = 448, mode: String = "standard") -> void:
	modal_revision += 1
	score_ticket = null
	score_reveal_remaining = 0.0
	modal.visible = true
	modal_mode = mode
	settings_visible = false
	if modal_tween and modal_tween.is_valid():
		modal_tween.kill()
	modal.modulate = Color(1, 1, 1, 1 if game.reduced_motion else 0)
	var width_ = 480.0 if mode == "welcome" else (440.0 if mode == "ending" else 600.0)
	modal.size.x = width_
	modal.position.x = 60 if mode == "welcome" else (48 if mode == "ending" else (root.size.x - width_) / 2)
	dim.color.a = 0.18 if mode == "welcome" else (0.22 if mode == "ending" else 0.67)
	show_gameplay_widgets(game.state not in [game.State.READY, game.State.END])
	if game.state == game.State.END:
		game.world.foreground.visible = true
		game.world.duck.visible = true
	for page in modal_pages.values():
		page.hide()
	if not modal_pages.has(modal_page_key):
		var page = VBoxContainer.new()
		page.position = Vector2(32, 28)
		page.add_theme_constant_override("separation", 12)
		modal.add_child(page)
		modal_pages[modal_page_key] = page
	modal_content = modal_pages[modal_page_key]
	modal_content.size.x = width_ - 64
	modal_content.show()
	modal_page_fresh = not modal_refs.has(modal_page_key)
	modal.size.y = height
	modal.position.y = (root.size.y - height) * 0.5
	modal_content.size.y = height - 54
	if modal_page_fresh:
		var heading = modal_line(title, 34, INK)
		heading.add_theme_font_override("font", title_font)
		if mode == "welcome":
			heading.add_theme_font_size_override("font_size", 60)
		modal_refs[modal_page_key] = {"heading": heading, "subtitle": modal_line(subtitle, 16, MUTED)}
	else:
		modal_refs[modal_page_key].heading.text = title
		modal_refs[modal_page_key].subtitle.text = subtitle
	overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fit_modal.call_deferred()

func fit_modal() -> void:
	var revision = modal_revision
	# Wrapped labels first need a layout pass at the final content width.
	await get_tree().process_frame
	if revision != modal_revision:
		return
	if modal_tween and modal_tween.is_valid():
		modal_tween.kill()
	var height = clampf(modal_content.get_combined_minimum_size().y + 58, 380, 820)
	modal.size.y = height
	modal.position.y = (root.size.y - height) * 0.5
	modal.position.x = 60 if modal_mode == "welcome" else (48 if modal_mode == "ending" else (root.size.x - modal.size.x) / 2)
	modal_content.size.y = height - 54
	var buttons: Array = []
	for child in modal_content.get_children():
		if child is BaseButton or child is HSlider:
			buttons.append(child)
	for i in range(buttons.size()):
		buttons[i].focus_neighbor_top = buttons[(i - 1 + buttons.size()) % buttons.size()].get_path()
		buttons[i].focus_neighbor_bottom = buttons[(i + 1) % buttons.size()].get_path()
	if score_reveal_remaining > 0:
		return
	if not buttons.is_empty() and overlay.visible:
		buttons[0].grab_focus()
	if not game.reduced_motion:
		modal.position.y += 14
		modal.modulate.a = 0
		modal_tween = create_tween().set_parallel(true)
		modal_tween.tween_property(modal, "position:y", (root.size.y - height) * 0.5, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		modal_tween.tween_property(modal, "modulate:a", 1.0, 0.14)
		if modal_mode == "score":
			modal_tween.tween_property(dim, "color:a", 0.67, 0.14)

func modal_line(text: String, font_size: int = 18, color: Color = INK) -> Label:
	var l = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	modal_content.add_child(l)
	return l

func modal_button(text: String, action: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size.y = 44
	b.pressed.connect(action)
	modal_content.add_child(b)
	return b

func show_start() -> void:
	modal_page_key = "welcome"
	clear_modal("怪物打靶夜", "午夜游园  /  第一幕 · 海盗船", 520, "welcome")
	if not modal_page_fresh:
		return
	modal_line("五发子弹，赢走今晚的大奖。", 22, GOLD)
	modal_line("准备、收割、培养。下一组见分晓。", 17, MUTED)
	modal_button("开场营业   →", game.start_round)
	modal_button("第一次来？看看玩法", show_tutorial)
	modal_button("声音与动态", func(): show_settings(show_start))

func show_tutorial() -> void:
	modal_page_key = "tutorial"
	clear_modal("一张靶票，五次机会", "把准备动作，变成下一发的高分表演。", 520)
	if not modal_page_fresh:
		return
	modal_line("① 准备与收割", 22, GOLD)
	modal_line("弹簧弹把怪物弹起，普通弹趁空中打靶心。\n错过追枪？地毯会接住目标，再弹一次。", 18)
	modal_line("② 投资下一组", 22, GOLD)
	modal_line("长按 R 交出真实余弹，储能到 3 后鸭子升级。\n下一组打右侧铃铛，它会牵住一个海盗。", 18)
	modal_line("4 组五发 · 60 秒 · 目标 1,800 分", 17, MINT)
	modal_button("开场营业   →", game.start_round)
	modal_button("返回标题", show_start)

func show_gameplay_widgets(visible_: bool) -> void:
	for child in root.get_children():
		if child is Control and child != overlay and child != root.get_child(0):
			child.visible = visible_
	game.world.gun.visible = visible_
	game.world.duck.visible = visible_
	game.world.foreground.visible = visible_

func show_pause() -> void:
	var unlocked = game.records.is_empty()
	modal_page_key = "configure" if unlocked else "pause"
	clear_modal("配置桌面" if unlocked else "暂停营业", "时间与场景运动已暂停", 572 if unlocked else 475)
	var refs: Dictionary = modal_refs[modal_page_key]
	if modal_page_fresh:
		build_pause_content(unlocked)
	refs.ammo.text = "当前装填：" + game.ammo_display()
	if unlocked:
		refs.carpet.text = "弹簧地毯：" + ("已装备" if game.world.carpet_enabled else "未装备") + "  ·  点击切换"
	refs.duck.text = "发条鸭：%d 级 · 累计储能 %d\n%s" % [game.duck_level, game.duck_energy, game.duck_description()]

func build_pause_content(unlocked: bool) -> void:
	var refs: Dictionary = modal_refs[modal_page_key]
	refs.ammo = modal_line("", 19, MINT)
	if unlocked:
		modal_line("每组第一枪前可调整。弹芯保留，每组补足五发。", 16, MUTED)
		modal_button("稳妥射击  ·  普通 / 普通 / 普通 / 普通 / 普通", func(): game.set_loadout(0))
		modal_button("先准备后收割  ·  弹簧 / 普通 / 普通 / 普通 / 普通", func(): game.set_loadout(1))
		modal_button("留中段准备  ·  普通 / 普通 / 弹簧 / 普通 / 普通", func(): game.set_loadout(2))
		refs.carpet = modal_button("", game.toggle_carpet)
	else:
		modal_line("本组已开枪，配置锁定。下一组再调整。", 17, CORAL)
	refs.duck = modal_line("", 18)
	modal_line("准备好后，继续你的五发表演。", 15, MUTED)
	modal_button("继续营业   Tab / Esc", game.toggle_pause)
	modal_button("重开本关", game.reset_round)
	modal_button("声音与动态", func(): show_settings(show_pause))

func show_score(result: Dictionary, gain: int, reason: String) -> void:
	modal_page_key = "score"
	clear_modal("本组报分", {"full": "五发已经完成", "early": "主动交出 %d 个未射弹位" % (5 - game.records.size()), "timeout": "时间耗尽，结算已完成的动作"}.get(reason, "本组结束"), 565, "score")
	var refs: Dictionary = modal_refs[modal_page_key]
	if modal_page_fresh:
		cached_score_ticket = ScoreTicket.new()
		modal_content.add_child(cached_score_ticket)
		refs.performances = modal_line("", 16, INK)
		refs.growth = modal_line("", 19, MINT)
		refs.caption = modal_line("", 15, MUTED)
		refs.continue_button = modal_button("", game.continue_group)
	score_ticket = cached_score_ticket
	score_ticket.configure(result, game.group_index, game.reduced_motion)
	refs.performances.text = " · ".join(result.performances) if not result.performances.is_empty() else "没有追加表演，命中底分保留。"
	refs.growth.text = "发条鸭储能 +%d → %d · %d 级" % [gain, game.duck_energy, game.duck_level] if gain > 0 else "发条鸭 · 储能 %d · %d 级" % [game.duck_energy, game.duck_level]
	refs.caption.text = "奖品成长将在下一组生效。" if gain > 0 else "本组得分已计入累计分数。"
	refs.continue_button.text = "查看结果   →" if game.round_finished() else "装填下一组   →   Space"
	# Accounting is already complete. Let the last physical reaction finish
	# before the card covers the stage; Space/Enter can skip this presentation.
	if reason == "full" and not game.reduced_motion and not game.records.is_empty():
		var last: Dictionary = game.records.back()
		if last.destroyed and last.target >= 0:
			score_reveal_remaining = game.world.targets[last.target].death_duration + 0.03
		elif last.display == "破盾 +5":
			score_reveal_remaining = 0.35
	if score_reveal_remaining > 0:
		modal.hide()
		dim.color.a = 0
		var owner = get_viewport().gui_get_focus_owner()
		if owner:
			owner.release_focus()

func show_end(won: bool) -> void:
	modal_page_key = "win" if won else "loss"
	clear_modal("今晚的大赢家" if won else "今晚还差一点", "大奖已赢下，漂亮的一轮表演。" if won else "离大奖还差 %d 分，下次换一种打法。" % maxi(0, 1800 - game.total_score), 520, "ending")
	var refs: Dictionary = modal_refs[modal_page_key]
	if modal_page_fresh:
		refs.score = modal_line("", 42, MINT if won else CORAL)
		modal_line("今晚的表演", 20, GOLD)
		refs.moments = modal_line("", 18)
		modal_line("下一轮，试试弹起后的靶心追击，\n或把更多余弹留给发条鸭。", 17, MUTED)
		modal_button("再营业一轮   →", game.reset_round)
		modal_button("声音与动态", func(): show_settings(func(): show_end(won)))
	refs.score.text = "%d / 1,800 分" % game.total_score
	var moments: Array[String] = []
	if game.saw_relay:
		moments.append("漂亮的准备接力")
	if game.saw_bounce:
		moments.append("抓住了地毯再弹的机会")
	if game.duck_level > 0:
		moments.append("发条鸭培养到 %d 级" % game.duck_level)
	if game.saw_duck:
		moments.append("和鸭子一起完成追击")
	refs.moments.text = "\n".join(moments) if not moments.is_empty() else "稳稳打好每一发，就是精彩表演的开始。"

func hide_modal() -> void:
	modal_revision += 1
	score_ticket = null
	score_reveal_remaining = 0.0
	modal.visible = true
	overlay.visible = false
	show_gameplay_widgets(true)
	settings_visible = false
	if modal_tween and modal_tween.is_valid():
		modal_tween.kill()
	modal.modulate = Color.WHITE

func show_settings(return_to: Callable) -> void:
	settings_return = return_to
	modal_page_key = "settings"
	clear_modal("声音与动态", "调整演出强度，不影响计分与命中规则。", 448)
	settings_visible = true
	var refs: Dictionary = modal_refs[modal_page_key]
	if modal_page_fresh:
		modal_line("音效音量", 19)
		refs.volume = HSlider.new()
		refs.volume.min_value = 0
		refs.volume.max_value = 100
		refs.volume.custom_minimum_size.y = 36
		refs.volume.value_changed.connect(func(value): game.set_audio_volume(value / 100))
		modal_content.add_child(refs.volume)
		refs.motion = CheckButton.new()
		refs.motion.text = "减少动态 · 降低摆动和粒子数量"
		refs.motion.custom_minimum_size.y = 48
		refs.motion.toggled.connect(game.set_reduced_motion)
		modal_content.add_child(refs.motion)
		modal_line("保留弹起、翻盖和成长等必要动作提示。", 15, MUTED)
		modal_button("返回   →   Esc", close_settings)
	refs.volume.set_value_no_signal(game.audio_volume * 100)
	refs.motion.set_pressed_no_signal(game.reduced_motion)
	refs.volume.grab_focus()

func close_settings() -> void:
	settings_visible = false
	if settings_return.is_valid():
		settings_return.call()

func on_shot(record: Dictionary, screen_position: Vector2) -> void:
	shot_feedback.show_result(screen_position, record, game.reduced_motion)
	if record.valid and toast_tint == CORAL:
		toast_time = 0.0
	var card: Control = slots[record.slot].panel
	card.pivot_offset = card.size / 2
	slot_pulses[record.slot] = 0.0 if game.reduced_motion else 0.22

func on_reload() -> void:
	toast_time = 0
	toast_age = 0
	toast_panel.hide()
	shot_feedback.age = 1
	shot_feedback.queue_redraw()
	reload_age = 1.0 if game.reduced_motion else 0.0
	for i in range(slots.size()):
		var card: Control = slots[i].panel
		slot_pulses[i] = 0.0
		card.scale = Vector2.ONE
		card.modulate.a = 1.0 if game.reduced_motion else 0.35

func toast(text: String, color: Color = MINT) -> void:
	toast_tint = color
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	var text_width = toast_label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	toast_panel.size.x = clampf(text_width + 52, 320, 660)
	toast_panel.position.x = (660 - toast_panel.size.x) * 0.5
	toast_label.size.x = toast_panel.size.x - 36
	toast_time = 2.2
	toast_age = 0

func update_hud(delta: float) -> void:
	if score_reveal_remaining > 0 and game.state == game.State.SCORE:
		score_reveal_remaining = 0.0 if game.reduced_motion else maxf(0, score_reveal_remaining - delta)
		if score_reveal_remaining <= 0:
			modal.modulate.a = 0.0 if not game.reduced_motion else 1.0
			modal.show()
			dim.color.a = 0.0 if not game.reduced_motion else 0.67
			fit_modal.call_deferred()
	var presentation_delta = delta if game.state != game.State.PAUSED else 0.0
	if is_instance_valid(score_ticket) and game.state == game.State.SCORE and modal.visible and overlay.visible:
		score_ticket.advance(presentation_delta, game.reduced_motion)
	shot_feedback.reduced_motion = game.reduced_motion
	shot_feedback.advance(presentation_delta)
	toast_time = maxf(0, toast_time - presentation_delta)
	toast_age += presentation_delta
	toast_panel.visible = toast_time > 0
	var arrival = clampf(toast_age / 0.14, 0, 1)
	toast_panel.position.y = 0.0 if game.reduced_motion else (1.0 - arrival) * 3.0
	toast_panel.modulate.a = 1.0 if game.reduced_motion else minf(arrival, toast_time / 0.2)
	reload_age += presentation_delta
	if game.total_score < displayed_score or game.reduced_motion:
		displayed_score = game.total_score
	else:
		displayed_score = move_toward(displayed_score, game.total_score, delta * maxf(900, (game.total_score - displayed_score) * 7))
	score_label.text = "%d" % roundi(displayed_score)
	timer_label.text = "%.1f s" % game.time_left
	timer_label.add_theme_color_override("font_color", CORAL if game.time_left < 10 else INK)
	group_label.text = "第 %d / 4 组" % game.group_index
	progress.value = displayed_score * 100.0 / 1800
	duck_label.text = "发条鸭 %d 级 · %d / %d" % [game.duck_level, game.duck_energy, mini(9, (game.duck_level + 1) * 3)]
	equipment_label.text = "地毯" + ("在位" if game.world.carpet_enabled else "卸下") + " · 靶纸 · 节拍 · 笑脸"
	var used = game.records.size()
	for i in range(5):
		var slot: Dictionary = slots[i]
		slot_pulses[i] = maxf(0, slot_pulses[i] - presentation_delta)
		var pulse = 0.0 if game.reduced_motion else sin(clampf(slot_pulses[i] / 0.22, 0, 1) * PI)
		slot.panel.scale = Vector2.ONE * (1.0 + 0.035 * pulse)
		slot.panel.modulate.a = 1.0 if game.reduced_motion else lerpf(0.35, 1.0, clampf((reload_age - i * 0.03) / 0.16, 0, 1))
		slot.ammo.text = "弹簧" if game.ammo[i] == "spring" else "普通"
		slot.result.text = game.records[i].get("display", "") if i < used else "待射"
		slot.icon.texture = load("res://assets/ui/spring.svg" if game.ammo[i] == "spring" else "res://assets/ui/bullet.svg")
		slot.icon.modulate.a = 0.45 if i < used else 1.0
		slot.result.add_theme_color_override("font_color", Color("5a7c6b") if i < used and game.records[i].valid else Color("86726e"))
		slot.panel.add_theme_stylebox_override("panel", ticket_style(i == used))
	if used < 5:
		next_label.text = "第 %d 发 · %s弹" % [used + 1, "弹簧" if game.ammo[used] == "spring" else "普通"]
		next_detail.text = "非致命 · 弹起无盾目标" if game.ammo[used] == "spring" else "直接破坏 · 靶心追加 15 分"
	else:
		next_label.text = "五发已完成"
		next_detail.text = "查看本组真实成果"
	if game.is_aiming() and not game.hover_text.is_empty():
		next_detail.text = game.hover_text
	preview_label.text = "现在报分  %d" % game.preview().score
	hold_bar.visible = game.hold_time > 0
	hold_bar.value = game.hold_time / 0.35 * 100
	var gain = game.growth_preview()
	hold_label.text = "长按 R 提前报分 · 交出 %d 发 · 储能 +%d" % [5 - used, gain] if used > 0 and used < 5 else "长按 R 提前报分"
	if game.state == game.State.SCORE:
		hold_label.text = "Space / Enter 继续"
	crosshair.visible = game.is_aiming()
	# Context belongs in the ammunition card, away from moving faces and weakpoints.
	crosshair_label.visible = false
	crosshair.position = game.aim - Vector2(15, 15)
	for r in crosshair.get_children():
		r.color = MINT if not game.hover_text.is_empty() else INK
	if game.state == game.State.SCORE:
		hint_label.text = "本组报分 · Space / Enter 继续"
	elif game.duck_level > 0 and not game.saw_duck:
		hint_label.text = "鸭子已升级，射击右侧铃铛让它帮忙"
	elif used == 0 and game.ammo[0] == "spring":
		hint_label.text = "先用弹簧弹把前排怪物弹起来"
	elif game.has_live_preparation():
		hint_label.text = "目标已弹起，用普通弹收割，或等地毯再弹"
	elif used >= 2 and game.duck_level == 0:
		hint_label.text = "长按 R 交出余弹；储能到 3，鸭子下组升级"
	else:
		hint_label.text = "打刻口靶心得精准；铃铛可翻开海盗遮挡"
