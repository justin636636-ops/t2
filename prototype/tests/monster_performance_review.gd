extends "res://tests/crew_performance_review.gd"
func monster_session(seconds: float) -> void:
 var intervals: Array=[]
 var spikes: Array=[]
 var end_at=Time.get_ticks_usec()+int(seconds*1000000)
 var last=Time.get_ticks_usec()
 var next_shot=last+100000
 var shots_sent=0
 var rounds: Array=[]
 var max_draws=0
 var first_memory=int(Performance.get_monitor(Performance.MEMORY_STATIC))
 var max_effects=0
 while Time.get_ticks_usec()<end_at:
  await process_frame
  var now=Time.get_ticks_usec()
  var interval=float(now-last)/1000
  intervals.append(interval)
  if interval>16.7:spikes.append({'frame_ms':interval,'completed_rounds':rounds.size(),'shot_in_group':game.records.size()})
  last=now
  max_draws=maxi(max_draws,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
  max_effects=maxi(max_effects,game.world.vfx.effects.size())
  if game.state==game.State.SCORE:
   var records=game.records.duplicate(true)
   var valid=records.size()==5
   for slot in range(records.size()):valid=valid and records[slot].destroyed and records[slot].weak and records[slot].base==35 and records[slot].target==slot
   if not valid or game.total_score!=3780:
    session_valid=false
    push_error('Native long crew session did not produce the intended real five-monster weakpoint result')
    quit(1)
    return
   rounds.append({'score':game.total_score,'shots':records.size(),'valid':valid})
   game.continue_group()
  if game.state==game.State.END:fresh_round()
  if game.state==game.State.AIMING and now>=next_shot:
   var slot=game.records.size()
   var point: Vector3=game.world.targets[slot].weak_hit.global_position
   var event=InputEventMouseButton.new()
   event.button_index=MOUSE_BUTTON_LEFT
   event.position=game.world.camera.unproject_position(point)
   event.pressed=true
   Input.parse_input_event(event)
   event=event.duplicate()
   event.pressed=false
   Input.parse_input_event(event)
   shots_sent+=1
   next_shot=now+290000
 var total=0.0
 for value in intervals:total+=value
 intervals.sort()
 print('MONSTER_LONG_SAMPLE: ',JSON.stringify({'seconds':seconds,'frames':intervals.size(),'mean_ms':total/intervals.size(),'p95_ms':intervals[int(intervals.size()*.95)],'max_ms':intervals.back(),'max_draw_calls':max_draws,'actual_clicks_sent':shots_sent,'completed_real_rounds':rounds.size(),'completed_rounds':rounds,'final_unsettled_records':game.records,'max_cosmetic_effects':max_effects,'memory_static_start_bytes':first_memory,'memory_static_end_bytes':int(Performance.get_monitor(Performance.MEMORY_STATIC)),'spikes_over_16_7_ms':spikes}))
func run() -> void:
 root.size=Vector2i(1440,900)
 game=load('res://main.tscn').instantiate()
 root.add_child(game)
 game.sound_on=false
 print('DISPLAY_REVIEW: ',JSON.stringify({'hz':DisplayServer.screen_get_refresh_rate(),'vsync':DisplayServer.window_get_vsync_mode(),'max_fps':Engine.max_fps}))
 for i in range(120):await process_frame
 fresh_round()
 await monster_session(30.0)
 if not session_valid:return
 print('MONSTER_LONG_SCOPE: Normal native auto physics/process, actual five-monster weakpoint input/collision/cooldown and 3780 accounting. Audio off, no concurrent owned native checks/captures/encoders; external environment not isolated. Skips receipts/endings, process intervals not physical FPS/GPU times; no fair crew-loop comparison, minimum-hardware or human comfort certification.')
 quit()
