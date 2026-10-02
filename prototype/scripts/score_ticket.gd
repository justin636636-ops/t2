extends Control
## A cosmetic receipt of the settled Rules result. It never changes accounting.

const ArtFonts = preload("res://scripts/art_fonts.gd")
const PAPER = Color("e8dbbb")
const INK = Color("354b46")
const FADED = Color("645d48")
const RED = Color("924536")
const STEP_INTERVAL = 0.15
var result: Dictionary
var rows: Array = []
var age = 0.0
var stamped_count = 0
var completed = false
var reduced = false
var heading: Label
var score: Label
var caption: Label
var seal: Control
var accounted: Label
var unit: Label
var row_cache: Array = []

class ReceiptSeal extends Control:
	func _draw() -> void:
		var ink = RED
		draw_rect(Rect2(4, 4, 126, 58), ink, false, 2.0)
		draw_rect(Rect2(9, 9, 116, 48), ink, false, 1.0)
		var font = ArtFonts.get_font("title")
		var text = "已入账"
		var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 25).x
		draw_string(font, Vector2((134 - width) / 2, 43), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 25, ink)
		# Tiny breaks in the rule give the ink an uneven physical impression.
		for rect in [Rect2(22, 3, 4, 3), Rect2(107, 60, 6, 3), Rect2(8, 23, 3, 3)]:
			draw_rect(rect, PAPER)

func text_label(text: String, font_size: int, color: Color = INK, numeric: bool = false) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", ArtFonts.get_font("number" if numeric else "body"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func configure(value: Dictionary, group: int, reduce_motion: bool) -> void:
	result = value.duplicate(true)
	reduced = reduce_motion
	age = 0.0
	stamped_count = 0
	completed = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 146 + result.steps.size() * 32)
	if heading == null:
		heading = text_label("", 15, FADED)
		heading.position = Vector2(22, 12)
		accounted = text_label("结算已完成", 14, RED)
		accounted.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		accounted.position = Vector2(-110, 13)
		caption = text_label("本组所得  /  向下取整", 14, FADED)
		score = text_label("", 56, INK, true)
		score.size = Vector2(330, 67)
		unit = text_label("分", 18, FADED)
		seal = ReceiptSeal.new()
		seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seal.size = Vector2(134, 66)
		seal.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		seal.position = Vector2(-168, -81)
		seal.pivot_offset = seal.size / 2
		seal.rotation = -0.075
		add_child(seal)
		resized.connect(queue_redraw)
	heading.text = "午夜游园  /  第 %02d 组靶票" % group
	rows.clear()
	for cached in row_cache:
		cached.node.hide()
	var previous = {"c": 0, "m": 1.0}
	for i in range(result.steps.size()):
		var step: Dictionary = result.steps[i]
		var changed = i == 0 or step.c != previous.c or not is_equal_approx(step.m, previous.m)
		var detail = "命中底分" if i == 0 else ("无追加" if i == 1 else "未触发")
		if i > 0 and changed:
			var parts: Array[String] = []
			if step.c != previous.c:
				parts.append("+%d" % (step.c - previous.c))
			if not is_equal_approx(step.m, previous.m):
				parts.append("×%.1f" % (step.m / previous.m) if step.label == "笑脸弹簧" else "倍率 +%.1f" % (step.m - previous.m))
			detail = " · ".join(parts)
		if i >= row_cache.size():
			var row = Control.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
			row.offset_left = 20
			row.offset_right = -20
			row.offset_top = 46 + i * 32
			row.offset_bottom = 76 + i * 32
			add_child(row)
			var labels: Array = []
			for entry in [[16, INK, 26, 153], [15, FADED, 186, 140], [19, INK, 327, 160]]:
				var item = text_label("", entry[0], entry[1])
				remove_child(item)
				row.add_child(item)
				item.position = Vector2(entry[2], 1)
				item.size = Vector2(entry[3], 28)
				if entry[2] == 327:
					item.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				labels.append(item)
			var mark = text_label("", 12, FADED)
			remove_child(mark)
			row.add_child(mark)
			mark.position = Vector2(0, 5)
			row_cache.append({"node": row, "mark": mark, "labels": labels, "changed": changed})
		var cached: Dictionary = row_cache[i]
		cached.node.show()
		cached.changed = changed
		cached.labels[0].text = step.label
		cached.labels[1].text = detail
		cached.labels[2].text = "%d × %.1f" % [step.c, step.m]
		rows.append(cached)
		previous = step
	caption.position = Vector2(24, custom_minimum_size.y - 91)
	score.text = str(result.score)
	score.position = Vector2(23, custom_minimum_size.y - 81)
	unit.position = Vector2(35 + score.get_theme_font("font").get_string_size(score.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x, custom_minimum_size.y - 40)
	advance(0.0, reduced)

func advance(delta: float, reduce_motion: bool) -> void:
	if completed:
		return
	reduced = reduce_motion
	age += delta
	stamped_count = rows.size() if reduced else clampi(int(floor((age - 0.12) / STEP_INTERVAL)) + 1, 0, rows.size())
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		var landed = i < stamped_count
		row.mark.text = "✓" if landed else "%02d" % (i + 1)
		row.mark.add_theme_color_override("font_color", RED if landed else FADED)
		var impact = maxf(0, 1 - (age - 0.12 - i * STEP_INTERVAL) / 0.12) if landed and not reduced else 0.0
		row.node.pivot_offset = Vector2(15, 16)
		row.node.scale = Vector2.ONE * (1 + impact * 0.018)
	completed = reduced or age >= 0.12 + rows.size() * STEP_INTERVAL + 0.12
	var seal_impact = maxf(0, 1 - (age - 0.12 - rows.size() * STEP_INTERVAL) / 0.12)
	# The final score and accounting status are readable from the first frame.
	# Only the physical ink impression arrives at the end of the short sequence.
	seal.visible = reduced or stamped_count == rows.size()
	seal.scale = Vector2.ONE if reduced else Vector2.ONE * (1 + seal_impact * 0.10)
	seal.modulate.a = 1.0 if reduced else clampf(1 - seal_impact, 0, 1)
	queue_redraw()

func _draw() -> void:
	if size.x < 1:
		return
	var w = size.x
	var h = size.y
	var edge = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 38), Vector2(w - 6, 44), Vector2(w, 50), Vector2(w, h - 50), Vector2(w - 6, h - 44), Vector2(w, h - 38), Vector2(w, h), Vector2(0, h), Vector2(0, h - 38), Vector2(6, h - 44), Vector2(0, h - 50), Vector2(0, 50), Vector2(6, 44), Vector2(0, 38)])
	var shadow = edge.duplicate()
	for i in range(shadow.size()):
		shadow[i] += Vector2(3, 4)
	draw_colored_polygon(shadow, Color(0.015, 0.024, 0.023, 0.4))
	draw_colored_polygon(edge, PAPER)
	draw_rect(Rect2(11, 7, w - 22, h - 14), Color("b6a982"), false, 1.0)
	draw_line(Vector2(21, 39), Vector2(w - 21, 39), Color("b6a982"), 1.0)
	for y in range(60, int(h - 108), 32):
		draw_line(Vector2(42, y + 16), Vector2(w - 22, y + 16), Color(0.4, 0.4, 0.3, 0.12), 1.0)
	for x in range(20, int(w - 20), 8):
		draw_line(Vector2(x, h - 101), Vector2(x + 3, h - 101), Color("9c9378"), 1.0)
	for i in range(stamped_count):
		draw_circle(Vector2(29, 61 + i * 32), 11, Color(0.63, 0.31, 0.25, 0.07))
