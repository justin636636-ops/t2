extends "res://tests/feedback_walkthrough.gd"
## Actual unused-round growth through all groups; real bells, pause and endings.
var levels: Array=[]
func screenshot(name_: String) -> void:
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://artifacts/v22-duck-'+name_+'.png'))
func surrender() -> void:
 var event=InputEventKey.new()
 event.physical_keycode=KEY_R
 event.keycode=KEY_R
 event.pressed=true
 Input.parse_input_event(event)
 await frames(24)
 event=event.duplicate()
 event.pressed=false
 Input.parse_input_event(event)
 await frames(2)
func visible_upgrades() -> Array:
 var result: Array=[]
 for i in range(1,4): result.append(game.world.duck_rig.parts['Upgrade_%d'%i].visible)
 return result
func foot_contact_error() -> float:
 for mesh in game.world.duck_rig.meshes:
  if String(mesh.name).begins_with('duck_Body_') and String(mesh.name).ends_with('duck_coral_lacquer'):
   var bounds: AABB=mesh.get_aabb()
   var lowest=INF
   for i in range(8): lowest=minf(lowest,mesh.to_global(bounds.get_endpoint(i)).y)
   var cushion: float=game.world.award_plinth.to_global(Vector3(0,game.world.DUCK_CUSHION_TOP,0)).y
   return absf(lowest-cushion)
 return INF
func run() -> void:
 window_review='--window-review' in OS.get_cmdline_user_args()
 root.size=Vector2i(1440,900)
 game=load('res://main.tscn').instantiate()
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 await frames(30)
 var world=game.world
 var rig=world.duck_rig
 var camera_pose: Transform3D=world.camera.global_transform
 check(visible_upgrades()==[false,false,false] and not world.duck.visible,'initial title has no upgrades and hides the assembled toy')
 check(rig.parts.has_all(['Duck_Head','Duck_Beak','Duck_Eye_L','Duck_Eye_R','Upgrade_1','Upgrade_2','Upgrade_3']) and rig.parts.Duck_Eye_L.get_parent()==rig.parts.Duck_Head and rig.parts.Duck_Eye_R.get_parent()==rig.parts.Duck_Head and rig.parts.Duck_Beak.get_parent()==rig.parts.Duck_Head,'exported eyes and lower beak stay parented to the authored neck hinge')
 await begin(0)
 await shoot(world.targets[2].global_position+Vector3(0,0,.24))
 await frames(18)
 await surrender()
 check(game.state==game.State.SCORE and game.duck_energy==4 and game.duck_level==1 and game.group_duck_level==0 and visible_upgrades()==[true,false,false],'one real weakpoint plus four returned rounds installs the clamp immediately but keeps current-group ability at zero')
 check(world.duck_growth>0 and absf(rig.parts.Duck_Head.rotation.x)>.01 and game.last_result.score==116,'actual growth nod accompanies the unchanged 116-point early receipt')
 levels.append({'group':game.group_index,'energy':game.duck_energy,'level':game.duck_level,'score':game.last_result.score,'foot_contact_error':foot_contact_error()})
 check(foot_contact_error()<.001,'actual imported webbed-foot bounds remain on the cushion during the growth scale pulse')
 screenshot('growth-1')
 await frames(38)
 await keyboard(KEY_SPACE)
 await frames(65)
 check(game.group_index==2 and game.group_duck_level==1 and rig.parts.Duck_Head.rotation.is_zero_approx() and rig.parts.Duck_Beak.rotation.is_zero_approx(),'next real group enables level one and the growth face has settled')
 await shoot(world.bell.global_position)
 check(game.records.back().valid and world.targets[5].held>0 and game.duck_used and world.duck_flash>0,'first actual level-one bell holds the real first pirate without delaying the ability')
 await frames(16)
 var normal_beak: float=rig.parts.Duck_Beak.rotation.x
 check(rig.parts.Duck_Head.rotation.y<-.05 and rig.parts.Duck_Head.rotation.x<0 and normal_beak>.10 and absf(rig.parts.Upgrade_1.rotation.x)>.08,'the toy looks up toward the actual left pirate and opens its beak and attached clamp')
 screenshot('help-1')
 await keyboard(KEY_TAB)
 var head_pose: Transform3D=rig.parts.Duck_Head.transform
 var beak_pose: Transform3D=rig.parts.Duck_Beak.transform
 var eye_pose: Transform3D=rig.parts.Duck_Eye_L.transform
 var tool_pose: Transform3D=rig.parts.Upgrade_1.transform
 var key_angle: float=world.duck_key_angle
 var flash: float=world.duck_flash
 await frames(15)
 check(game.state==game.State.PAUSED and head_pose.is_equal_approx(rig.parts.Duck_Head.transform) and beak_pose.is_equal_approx(rig.parts.Duck_Beak.transform) and eye_pose.is_equal_approx(rig.parts.Duck_Eye_L.transform) and tool_pose.is_equal_approx(rig.parts.Upgrade_1.transform) and is_equal_approx(key_angle,world.duck_key_angle) and is_equal_approx(flash,world.duck_flash),'real pause freezes neck, jaw, eyes, tool, winding key and help clock together')
 await keyboard(KEY_ESCAPE)
 await frames(50)
 check(world.duck_flash==0 and rig.parts.Duck_Head.rotation.is_zero_approx() and rig.parts.Duck_Beak.rotation.is_zero_approx() and rig.parts.Upgrade_1.rotation.is_zero_approx(),'help face and clamp return to rest after resume without a retained pirate reference')
 await surrender()
 check(game.duck_energy==8 and game.duck_level==2 and game.group_duck_level==1 and visible_upgrades()==[true,true,false],'four more actual returned rounds fit the reinforced mechanism for the next group')
 levels.append({'group':game.group_index,'energy':game.duck_energy,'level':game.duck_level,'score':game.last_result.score,'foot_contact_error':foot_contact_error()})
 screenshot('growth-2')
 await frames(38)
 game.set_reduced_motion(true)
 await keyboard(KEY_SPACE)
 await frames(200)
 await shoot(world.bell.global_position)
 check(game.group_index==3 and game.group_duck_level==2 and game.records.back().valid and world.targets[5].held>0,'reduced motion keeps the real reinforced bell hold and exposure')
 await frames(16)
 var reduced_beak: float=rig.parts.Duck_Beak.rotation.x
 check(reduced_beak>0 and reduced_beak<normal_beak*.5,'reduced-motion jaw cue is smaller while the actual assistance remains immediate')
 key_angle=world.duck_key_angle
 var calm_y: float=world.duck.position.y
 await frames(35)
 check(is_equal_approx(key_angle,world.duck_key_angle) and is_equal_approx(calm_y,world.duck.position.y) and world.duck.rotation.is_zero_approx(),'reduced motion removes perpetual winding, body bounce and decorative sway')
 screenshot('help-2-reduced')
 await surrender()
 check(game.duck_energy==9 and game.duck_level==3 and game.group_duck_level==2 and visible_upgrades()==[true,true,true] and world.duck.scale.is_equal_approx(Vector3.ONE),'real energy caps at nine and installs both ankle springs without a reduced-motion growth pulse')
 levels.append({'group':game.group_index,'energy':game.duck_energy,'level':game.duck_level,'score':game.last_result.score,'foot_contact_error':foot_contact_error()})
 check(foot_contact_error()<.001,'reduced-motion growth uses the real foot-to-cushion contact datum')
 screenshot('growth-3')
 await frames(38)
 game.set_reduced_motion(false)
 await keyboard(KEY_SPACE)
 await frames(200)
 await shoot(world.bell.global_position)
 check(game.group_index==4 and game.group_duck_level==3 and world.targets[5].airborne and game.duck_used,'level three launches the actual first pirate on the fourth-group bell')
 await frames(16)
 screenshot('help-3')
 for i in range(5,9):
  await shoot(world.targets[i].global_position+Vector3(0,0,.24))
  if i<8: await frames(22)
 await frames(80)
 var win_score: int=game.total_score
 await keyboard(KEY_SPACE)
 await frames(20)
 check(game.state==game.State.END and world.finale_won and win_score>=1800 and rig.parts.Duck_Beak.rotation.x>.04,'actual pirate harvest earns the raised award and its one-shot proud face')
 screenshot('win-flourish')
 await frames(110)
 check(rig.parts.Duck_Head.rotation.is_zero_approx() and rig.parts.Duck_Beak.rotation.is_zero_approx() and rig.parts.Wing_L.rotation.is_zero_approx() and rig.parts.Upgrade_1.rotation.is_zero_approx(),'victory head, jaw, wings and clamp settle after one flourish')
 check(foot_contact_error()<.001,'the fully raised and enlarged award keeps the actual feet on the velvet surface')
 screenshot('win-rest')
 if window_review:
  for size_ in [Vector2i(1152,720),Vector2i(1920,1080)]:
   root.size=size_
   await frames(12)
   var face: Vector2=world.camera.unproject_position(rig.parts.Duck_Head.global_position)
   check(root.get_visible_rect().has_point(face) and face.x>game.hud.modal.get_global_rect().end.x,'raised duck face clears the actual end card at '+str(size_.x))
   screenshot('win-window-'+str(size_.x))
  root.size=Vector2i(1440,900)
  await frames(8)
 # Four actual early returns of misses produce the loss without editing score,
 # remaining time, group count or target state.
 await begin(0)
 for group in range(4):
  await shoot(Vector3(-7.1,5.5,-4))
  await frames(18)
  await surrender()
  await frames(38)
  await keyboard(KEY_SPACE)
  if group<3: await frames(25)
 await frames(25)
 check(game.state==game.State.END and not world.finale_won and game.total_score==0 and rig.parts.Duck_Head.rotation.x>.05,'four actual miss-and-return groups produce a zero-score loss and one quiet downward glance')
 screenshot('loss')
 await frames(100)
 check(rig.parts.Duck_Head.rotation.is_zero_approx() and rig.parts.Duck_Beak.rotation.is_zero_approx(),'loss bow finishes without leaving the face permanently drooped')
 game.reset_round()
 var restored=true
 for part in rig.parts:
  restored=restored and rig.parts[part].transform.is_equal_approx(rig.rests[part])
 check(restored and world.duck_key_angle==0 and world.duck_help_direction==Vector2.ZERO and visible_upgrades()==[false,false,false] and not world.duck.visible,'restart restores every authored duck pivot, key phase and upgrade visibility')
 check(camera_pose.is_equal_approx(world.camera.global_transform),'real growth, assistance and endings preserve the fixed aim camera')
 print('DUCK REVIEW: ',JSON.stringify({'passed':passed,'failed':failed,'window_review':window_review,'actual_outcomes':outcomes,'real_growth':levels,'normal_beak':normal_beak,'reduced_beak':reduced_beak,'win_score':win_score,'loss_score':game.total_score,'camera_stable':camera_pose.is_equal_approx(world.camera.global_transform)}))
 await frames(24)
 for player in game.sound_players:
  player.stop()
  player.stream=null
 await frames(3)
 quit.call_deferred(1 if failed else 0)
