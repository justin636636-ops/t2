extends "res://tests/performance_review.gd"
## Normal game processing with real native input, never movie/fixed-step ticks.
func wait_wall(seconds: float) -> void:
 var until=Time.get_ticks_usec()+int(seconds*1000000)
 while Time.get_ticks_usec()<until: await process_frame
func input_key(code: int, held: float=0.0) -> void:
 var event=InputEventKey.new()
 event.keycode=code
 event.physical_keycode=code
 event.pressed=true
 Input.parse_input_event(event)
 if held>0: await wait_wall(held)
 event=event.duplicate()
 event.pressed=false
 Input.parse_input_event(event)
 await wait_wall(.10)
func actual_shot(point: Vector3) -> void:
 var event=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_LEFT
 event.position=game.world.camera.unproject_position(point)
 event.pressed=true
 Input.parse_input_event(event)
 event=event.duplicate()
 event.pressed=false
 Input.parse_input_event(event)
 await wait_wall(.28)
func run() -> void:
 root.size=Vector2i(1440,900)
 game=load('res://main.tscn').instantiate()
 root.add_child(game)
 game.sound_on=false
 print('DISPLAY_REVIEW: ',JSON.stringify({'hz':DisplayServer.screen_get_refresh_rate(),'vsync':DisplayServer.window_get_vsync_mode(),'max_fps':Engine.max_fps}))
 await wait_wall(2.0)
 game.start_round()
 game.toggle_pause()
 game.set_loadout(0)
 game.toggle_pause()
 await wait_wall(.60)
 var actual_growth: Array=[]
 for group in range(3):
  await actual_shot(game.world.targets[group].weak_hit.global_position)
  await input_key(KEY_R,.40)
  if game.state!=game.State.SCORE:
   push_error('Native performance preparation failed the real early return')
   quit(1)
   return
  actual_growth.append({'energy':game.duck_energy,'level':game.duck_level,'returned':5-game.records.size()})
  await input_key(KEY_SPACE)
  await wait_wall(.70)
 if game.group_index!=4 or game.group_duck_level!=3 or game.duck_energy!=9:
  push_error('Native performance preparation failed the real level-three growth')
  quit(1)
  return
 await sample('level-three-moving-stage',2.0,false)
 await actual_shot(game.world.bell.global_position)
 if not game.duck_used or not game.records.back().valid:
  push_error('Native performance preparation failed the actual level-three bell')
  quit(1)
  return
 await sample('level-three-real-bell-assistance',1.2,false)
 for index in range(5,9): await actual_shot(game.world.targets[index].weak_hit.global_position)
 if game.state!=game.State.SCORE or game.total_score<1800:
  print('VFX_HELP_PERFORMANCE_DIAGNOSTIC: ',JSON.stringify({'state':game.state,'records':game.records,'total':game.total_score,'group':game.group_index,'energy':game.duck_energy,'time_left':game.time_left}))
  push_error('Native performance preparation failed the actual pirate harvest')
  quit(1)
  return
 await input_key(KEY_SPACE)
 await sample('level-three-raised-award',2.0,false)
 print('DUCK_PERFORMANCE_SCOPE: ',JSON.stringify({'real_growth':actual_growth,'energy':game.duck_energy,'level':game.duck_level,'real_win_score':game.total_score,'actual_last_group_records':game.records,'normal_game_processing':true,'scope':'Native 1440x900 Apple M5; highest-tier gameplay and award short process-frame interval samples, no concurrent owned capture/check/encoder; external environment not isolated. Not physical FPS, GPU timing, fair historical comparison or minimum hardware certification.'}))
 quit()
