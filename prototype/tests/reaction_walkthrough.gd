extends SceneTree
## A native review of different materials, hit locations and character poses.
## Each shot is real input; no target state, ammunition or score is overridden.

var game: Node3D
var review_aim = Vector2(720, 450)
var reviewed: Array = []

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		game.aim = review_aim
		game._physics_process(1.0 / 60.0)
		game._process(1.0 / 60.0)
		await RenderingServer.frame_post_draw

func shoot(target: Node3D, offset: Vector3) -> void:
	var position = target.global_position + offset
	review_aim = game.world.camera.unproject_position(position)
	var motion = InputEventMouseMotion.new()
	motion.position = review_aim
	Input.parse_input_event(motion)
	await frames(1)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = game.world.camera.unproject_position(target.global_position + offset)
	review_aim = event.position
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func harvest(index: int, weak: bool, air: bool) -> void:
	var target = game.world.targets[index]
	await shoot(target, Vector3(0 if weak else 0.44, 0, 0.24))
	var record: Dictionary = game.records.back()
	if not record.destroyed or record.target != index or record.weak != weak or record.air != air:
		push_error("Reaction capture did not match its intended real shot: " + JSON.stringify(record))
		quit(1)
		return
	reviewed.append(record.duplicate())
	await frames(4)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v06-reaction-%02d.png" % index))
	await frames(38)

func run() -> void:
	root.size = Vector2i(1440, 900)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await frames(60)
	game.start_round()
	# Use the real pre-shot loadout menu so four kills leave the fifth slot
	# available. The report overlay must not hide the fourth actor's reaction.
	game.toggle_pause()
	game.set_loadout(0)
	game.toggle_pause()
	await frames(70)
	# Observe a full cycle of the five quiet/gesture intervals before shooting.
	# Rail motion and countdown continue through the actual game updates.
	for i in range(3):
		await frames(160)
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/v06-idle-%02d.png" % i))
	await harvest(0, true, false)
	await harvest(1, false, false)
	await harvest(2, true, false)
	await harvest(3, false, false)
	await frames(60)
	# Restart through the game's existing action and configure its default
	# spring-first loadout; neither outcomes nor the five-shot limit change.
	game.reset_round()
	await frames(30)
	game.start_round()
	game.toggle_pause()
	game.set_loadout(1)
	game.toggle_pause()
	await frames(45)
	await shoot(game.world.targets[4], Vector3(0, 0, 0.24))
	await frames(18)
	await harvest(4, false, true)
	await shoot(game.world.bell, Vector3.ZERO)
	await frames(18)
	await harvest(5, true, false)
	await frames(80)
	print("REACTION REVIEW: ", JSON.stringify(reviewed))
	game.queue_free()
	await process_frame
	quit()
