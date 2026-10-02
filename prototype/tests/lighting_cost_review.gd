extends "res://tests/lighting_art_review.gd"
## Same actual archived/current held scene, no movie or other owned native task.
func sample_held(before: bool, order: int) -> void:
 await setup(before)
 for i in range(30):await process_frame
 var times: Array=[]
 var draws: Array=[]
 var last=Time.get_ticks_usec()
 var end_at=last+2000000
 while Time.get_ticks_usec()<end_at:
  await process_frame
  var now=Time.get_ticks_usec()
  times.append(float(now-last)/1000)
  draws.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
  last=now
 var total=0.0
 for value in times:total+=value
 times.sort()
 draws.sort()
 print('LIGHTING_COST_SAMPLE: ',JSON.stringify({'order':order,'archived':before,'mean_ms':total/times.size(),'p95_ms':times[int(times.size()*.95)],'max_ms':times.back(),'draw_calls_min':draws.front(),'draw_calls_median':draws[int(draws.size()*.5)],'draw_calls_max':draws.back(),'frames':times.size(),'scope':'Actual archived world/backdrop/shader or current source, unchanged GLBs; fixed camera, HUD and 1.3s held pose. Native process intervals, not physical FPS or gameplay CPU; external environment not isolated.'}))
 game.free()
 await process_frame
func run() -> void:
 root.size=Vector2i(1440,900)
 print('LIGHTING_COST_DISPLAY: ',JSON.stringify({'hz':DisplayServer.screen_get_refresh_rate(),'vsync':DisplayServer.window_get_vsync_mode(),'max_fps':Engine.max_fps}))
 for item in [[true,1],[false,2],[false,3],[true,4]]:await sample_held(item[0],item[1])
 quit()
