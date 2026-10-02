extends "res://tests/crew_performance_review.gd"
## Current lighting, normal game processing; no fixed-step movie.
func run() -> void:
 root.size=Vector2i(1440,900)
 game=load('res://main.tscn').instantiate()
 root.add_child(game)
 game.sound_on=false
 print('DISPLAY_REVIEW: ',JSON.stringify({'hz':DisplayServer.screen_get_refresh_rate(),'vsync':DisplayServer.window_get_vsync_mode(),'max_fps':Engine.max_fps}))
 for i in range(120):await process_frame
 game.start_round()
 game.toggle_pause()
 game.set_loadout(0)
 game.toggle_pause()
 await sample('four-crew-normal-idle',3.0,false)
 await crew_session(30.0)
 if not session_valid:return
 print('LIGHTING_PERFORMANCE_SCOPE: Native normal auto physics/process, Apple M5 Metal Forward+ 1440x900; real input, collision/cooldown and unchanged accounting. No concurrent owned native checks/captures/encoders. External environment not isolated, process intervals not physical FPS or GPU times. Immediately skips receipts/endings; no long human comfort, fair speedup, minimum-hardware or full-game certification.')
 quit()
