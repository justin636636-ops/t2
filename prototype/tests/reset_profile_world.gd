extends "res://scripts/world.gd"
var reset_cpu: Array = []
func reset_world() -> void:
	var began = Time.get_ticks_usec()
	super.reset_world()
	reset_cpu.append(float(Time.get_ticks_usec() - began) / 1000.0)
