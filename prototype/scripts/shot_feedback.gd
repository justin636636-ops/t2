extends Control
## Cosmetic confirmation at the resolved cursor. Shape carries the outcome.

var age = 1.0
var duration = 0.24
var tint = Color("eadcc0")
var strong = false
var spring = false
var mode = "miss"
var reduced_motion = false

func show_result(screen_position: Vector2, record: Dictionary, reduced: bool = false) -> void:
	position = screen_position
	age = 0
	reduced_motion = reduced
	strong = record.get("weak", false) and record.valid
	spring = record.ammo == "spring" and record.valid and record.target >= 0
	if not record.valid:
		mode = "blocked" if record.target >= 0 or record.display == "未响应" else "miss"
	elif record.target < 0:
		mode = "mechanism"
	elif spring:
		mode = "prepare"
	elif not record.destroyed:
		mode = "shield"
	else:
		mode = "precision" if strong else "body"
	tint = Color("8cbea3") if spring else (Color("c7aa72") if mode in ["precision", "mechanism", "shield"] else Color("eadcc0"))
	if mode == "miss":
		tint = Color("aca99e")
	elif mode == "blocked":
		tint = Color("c7806e")
	duration = 0.16 if mode == "miss" else (0.29 if strong else 0.24)
	queue_redraw()

func advance(delta: float) -> void:
	if age >= duration:
		return
	age += delta
	queue_redraw()

func stroke(a: Vector2, b: Vector2, color: Color, width_: float = 2) -> void:
	# A quiet dark under-stroke keeps the mark visible on pale targets and sails.
	draw_line(a, b, Color(0.06, 0.08, 0.12, color.a * 0.8), width_ + 2, true)
	draw_line(a, b, color, width_, true)

func _draw() -> void:
	if age >= duration:
		return
	var p = clampf(age / duration, 0, 1)
	var color = Color(tint, 1 - p * p)
	var spread = 0.0 if reduced_motion else (1.0 - pow(1.0 - p, 3)) * 5.0
	var radius = 10.0 + spread
	match mode:
		"miss":
			for side in [-1, 1]:
				stroke(Vector2(side * (radius + 2), 0), Vector2(side * (radius + 7), 0), Color(color, color.a * 0.7), 1.5)
		"blocked":
			for side in [-1, 1]:
				stroke(Vector2(side * radius, -5), Vector2(side * radius, 5), color)
				stroke(Vector2(side * radius, 0), Vector2(side * (radius - 4), 0), color)
		"prepare":
			stroke(Vector2(-6, -radius + 4), Vector2(0, -radius - 3), color)
			stroke(Vector2(0, -radius - 3), Vector2(6, -radius + 4), color)
			stroke(Vector2(0, -radius + 2), Vector2(0, -radius + 8), color)
		"mechanism":
			for side in [-1, 1]:
				var angle = 0.0 if side > 0 else PI
				draw_arc(Vector2.ZERO, radius + 2, angle - 0.7, angle + 0.7, 12, Color(0.06, 0.08, 0.12, color.a), 4, true)
				draw_arc(Vector2.ZERO, radius + 2, angle - 0.7, angle + 0.7, 12, color, 2, true)
			stroke(Vector2(-3, -radius - 6), Vector2(3, -radius - 6), color)
		"shield":
			for side in [-1, 1]:
				stroke(Vector2(side * (radius + 3), -6), Vector2(side * radius, -2), color)
				stroke(Vector2(side * radius, 2), Vector2(side * (radius + 4), 7), color)
		"body", "precision":
			for x in [-1, 1]:
				for y in [-1, 1]:
					stroke(Vector2(x, y) * radius, Vector2(x, y) * (radius + 5), color)
			if strong:
				for i in range(4):
					var a = Vector2(sin(i * PI / 2), cos(i * PI / 2)) * (radius + 11)
					var b = Vector2(sin((i + 1) * PI / 2), cos((i + 1) * PI / 2)) * (radius + 11)
					stroke(a.lerp(b, 0.18), a.lerp(b, 0.82), Color(color, color.a * 0.72), 1.5)
