extends "res://tests/feedback_walkthrough.gd"
## Native first-person review with real aim, shots, pause and interrupted reload.
func screenshot(name_: String) -> void:
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://artifacts/v22-weapon-'+name_+'.png'))
func move_aim(point: Vector3) -> void:
 var event=InputEventMouseMotion.new()
 event.position=game.world.camera.unproject_position(point)
 review_aim=event.position
 Input.parse_input_event(event)
 await frames(20)
func run() -> void:
 window_review='--window-review' in OS.get_cmdline_user_args()
 root.size=Vector2i(1440,900)
 game=load('res://main.tscn').instantiate()
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 await frames(30)
 await begin(0)
 var world=game.world
 var camera_pose: Transform3D=world.camera.global_transform
 var fill=world.gun.get_node('WeaponFill')
 check(fill.light_cull_mask==4 and not fill.shadow_enabled and world.gun_rig.meshes.all(func(mesh):return mesh.layers==4) and world.targets.all(func(t):return t.find_children('*','MeshInstance3D',true,false).all(func(mesh):return mesh.layers==1)), 'one unshadowed private fill affects only the authored weapon meshes')
 check(world.gun_rig.parts.has('Index_Finger') and world.gun_rig.meshes.any(func(mesh):return mesh.get_active_material(0) is ShaderMaterial and mesh.get_active_material(0).shader.resource_path.ends_with('worker_canvas.gdshader')), 'the actual exported finger and filtered canvas material are present in the native viewmodel')
 for index in [0,4,6,2]:
  await move_aim(world.targets[index].weak_hit.global_position)
  screenshot('aim-'+str(index))
 check(camera_pose.is_equal_approx(world.camera.global_transform) and game.records.is_empty(), 'real pointer aim keeps the fixed camera and spends no ammunition')
 await shoot(world.targets[0].global_position+Vector3(0,0,.24))
 var normal_flex: float=absf(world.gun_rig.parts.Index_Finger.rotation.x)
 check(game.records.size()==1 and game.records.back().weak and game.records.back().base==35 and normal_flex>.02 and absf(world.gun_rig.parts.Trigger.rotation.x)>.04, 'a real weakpoint shot scores 35 base and flexes the finger together with the trigger')
 screenshot('trigger')
 await keyboard(KEY_TAB)
 var finger_pose: Transform3D=world.gun_rig.parts.Index_Finger.transform
 var weapon_pose: Transform3D=world.gun.transform
 var light_pose: Transform3D=fill.global_transform
 await frames(12)
 check(game.state==game.State.PAUSED and finger_pose.is_equal_approx(world.gun_rig.parts.Index_Finger.transform) and weapon_pose.is_equal_approx(world.gun.transform) and light_pose.is_equal_approx(fill.global_transform), 'real pause freezes the trigger finger, grip and attached fill pose')
 await keyboard(KEY_ESCAPE)
 await frames(30)
 check(absf(world.gun_rig.parts.Index_Finger.rotation.x)<.00001 and camera_pose.is_equal_approx(world.camera.global_transform), 'resume settles the finger to rest without moving the camera')
 for i in range(4):
  await shoot(Vector3(-7.1,5.5,-4))
  if i<3: await frames(18)
 await frames(80)
 check(game.state==game.State.SCORE and game.records.size()==5 and game.total_score==116, 'one weakpoint and four real misses create the unchanged 116-point receipt')
 screenshot('report')
 await keyboard(KEY_SPACE)
 var reloading: bool=world.gun_reload<.32
 await shoot(world.targets[1].global_position+Vector3(0,0,.24))
 check(reloading and game.state==game.State.AIMING and game.group_index==2 and game.records.size()==1 and game.records.back().weak and world.gun_reload>=1, 'a real next-group shot interrupts the cosmetic reload immediately and starts a new finger press')
 screenshot('reload-interrupted')
 await frames(30)
 game.set_reduced_motion(true)
 await begin(0)
 await shoot(world.targets[0].global_position+Vector3(0,0,.24))
 var calm_flex: float=absf(world.gun_rig.parts.Index_Finger.rotation.x)
 check(game.records.back().weak and calm_flex>0 and calm_flex<normal_flex*.5, 'reduced motion preserves the actual weakpoint shot with a smaller physical finger flex')
 await frames(30)
 screenshot('reduced')
 if window_review:
  for size_ in [Vector2i(1152,720),Vector2i(1920,1080)]:
   root.size=size_
   await frames(12)
   var hand: Vector2=world.camera.unproject_position(world.gun.to_global(Vector3(.025,-.30,.55)))
   check(hand.y<root.get_visible_rect().end.y-170 and root.get_visible_rect().has_point(hand), 'the native grip stays visible above the ammunition dock at '+str(size_.x))
   screenshot('window-'+str(size_.x))
  root.size=Vector2i(1440,900)
  await frames(8)
 game.reset_round()
 check(game.state==game.State.READY and not world.gun.visible and world.gun_rig.parts.Index_Finger.transform.is_equal_approx(world.gun_rig.rests.Index_Finger), 'restart restores the authored finger rest pose and hides the weapon on the title')
 game.set_reduced_motion(false)
 await frames(25)
 print('WEAPON REVIEW: ',JSON.stringify({'passed':passed,'failed':failed,'actual_outcomes':outcomes,'normal_flex':normal_flex,'reduced_flex':calm_flex,'first_group_score':116,'window_review':window_review,'camera_stable':camera_pose.is_equal_approx(world.camera.global_transform)}))
 for player in game.sound_players:
  player.stop()
  player.stream=null
 await frames(3)
 quit.call_deferred(1 if failed else 0)
