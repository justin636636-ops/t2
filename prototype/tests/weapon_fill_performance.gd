extends SceneTree
## Controlled local frame-interval samples, same held scene, fill on/off.
var game: Node3D
func _initialize() -> void:
 run.call_deferred()
func sample(enabled: bool, index: int) -> void:
 game.world.gun.get_node('WeaponFill').visible=enabled
 for i in range(30):await process_frame
 var times: Array[float]=[]
 var end_at=Time.get_ticks_usec()+2000000
 var last=Time.get_ticks_usec()
 while Time.get_ticks_usec()<end_at:
  await process_frame
  var now=Time.get_ticks_usec()
  times.append(float(now-last)/1000)
  last=now
 times.sort()
 var mean=0.0
 for value in times:mean+=value/times.size()
 print('PRIVATE_FILL_SAMPLE: ',JSON.stringify({'index':index,'fill_enabled':enabled,'frames':times.size(),'mean_ms':mean,'p95_ms':times[int(times.size()*.95)],'max_ms':times.back()}))
func run() -> void:
 root.size=Vector2i(1440,900)
 game=load('res://main.tscn').instantiate()
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 game.sound_on=false
 game.start_round()
 game.world.update_world(.4,false,1)
 game.hud.update_hud(.4)
 print('PRIVATE_FILL_SCOPE: ',JSON.stringify({'same_held_camera_and_stage':true,'screen_hz':DisplayServer.screen_get_refresh_rate(),'vsync':DisplayServer.window_get_vsync_mode(),'resolution':[1440,900],'scope':'Four 2s process-frame interval samples with a 30-frame settle, external environment not isolated. Does not prove GPU time, physical display FPS or full-game stable performance.'}))
 for i in range(4):await sample([true,false,false,true][i],i)
 game.free()
 await process_frame
 quit()
