extends "res://tests/vfx_help_performance_review.gd"
## Add observation around the original normal-loop input, no acceptance overrides.
var diagnostic_clicks: Array = []
func actual_shot(point: Vector3) -> void:
	var before = {"requested_world":str(point),"screen":str(game.world.camera.unproject_position(point)),"state":game.state,"cooldown":game.cooldown,"queued":game.queued_shot,"count":game.records.size(),"tick_usec":Time.get_ticks_usec()}
	await super.actual_shot(point)
	var result = {"before":before,"state_after":game.state,"count_after":game.records.size(),"cooldown_after":game.cooldown,"records_after":game.records.duplicate(true)}
	diagnostic_clicks.append(result)
	print("HARVEST_INPUT_OBSERVATION: ",JSON.stringify(result))
