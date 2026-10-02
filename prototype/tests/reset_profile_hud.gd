extends "res://scripts/hud.gd"
var modal_cpu = {}
func measured(kind: String, began: int) -> void:
	if not modal_cpu.has(kind):modal_cpu[kind] = []
	modal_cpu[kind].append(float(Time.get_ticks_usec() - began) / 1000.0)
func clear_modal(title: String, subtitle: String, height: float = 448, mode: String = "standard") -> void:
	var began = Time.get_ticks_usec()
	super.clear_modal(title, subtitle, height, mode)
	measured("clear_modal", began)
func show_start() -> void:
	var began = Time.get_ticks_usec()
	super.show_start()
	measured("show_start", began)
func show_pause() -> void:
	var began = Time.get_ticks_usec()
	super.show_pause()
	measured("show_pause", began)
func show_score(result: Dictionary, gain: int, reason: String) -> void:
	var began = Time.get_ticks_usec()
	super.show_score(result, gain, reason)
	measured("show_score", began)
func show_end(won: bool) -> void:
	var began = Time.get_ticks_usec()
	super.show_end(won)
	measured("show_end", began)
