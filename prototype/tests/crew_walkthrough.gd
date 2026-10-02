extends "res://tests/feedback_walkthrough.gd"
## Native real input/cooldowns: block, break, hinged reveal and four-role harvest.
var max_hinge_error=0.0
var min_axis_alignment=1.0
var max_marker_drift=0.0
var captured_palettes: Array=[]
func screenshot(name_: String) -> void:
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://artifacts/v22-crew-'+name_+'.png'))
func anchor_error(actor: Node3D) -> float:
 var mount=actor.body_visual.find_child('ShieldMount',true,false)
 var axle=actor.shield_visual.find_child('CoverAxle',true,false)
 if mount==null or axle==null:return INF
 if not actor.shield_broken:min_axis_alignment=minf(min_axis_alignment,mount.global_basis.x.normalized().dot(axle.global_basis.x.normalized()))
 return mount.global_position.distance_to(axle.global_position)
func latest_chips() -> Variant:
 for i in range(game.world.vfx.effects.size()-1,-1,-1):
  var effect=game.world.vfx.effects[i]
  if effect.kind=='debris' and effect.node.multimesh.mesh==game.world.vfx.meshes.chip:return effect.node.multimesh
 return null
func matching_palette(expected: Array,count: int) -> bool:
 var chips=latest_chips()
 if chips==null or chips.instance_count!=count:return false
 var colors: Array=[]
 var matches=true
 for i in range(3):
  var color: Color=chips.get_instance_color(i)
  colors.append(color.to_html(false))
  var desired: Color=expected[i]
  matches=matches and maxf(absf(color.r-desired.r),maxf(absf(color.g-desired.g),absf(color.b-desired.b)))<=1.0/255.0
 captured_palettes.append({'colors':colors,'particles':count})
 return matches
func track_assembly() -> void:
 for actor in game.world.targets:
  if actor.kind!='pirate' or not actor.alive or actor.shield_broken:continue
  max_hinge_error=maxf(max_hinge_error,anchor_error(actor))
  var marker: Vector2=game.world.camera.unproject_position(actor.weak_visual.to_global(Vector3(0,0,.24)))
  var hit: Vector2=game.world.camera.unproject_position(actor.weak_hit.global_position)
  max_marker_drift=maxf(max_marker_drift,marker.distance_to(hit))
func run() -> void:
 window_review='--window-review' in OS.get_cmdline_user_args()
 root.size=Vector2i(1440,900)
 game=load('res://main.tscn').instantiate()
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 await frames(30)
 await begin(1)
 var world=game.world
 var camera_pose: Transform3D=world.camera.global_transform
 var crew=world.targets.slice(5,9)
 var names=crew.map(func(actor):return str(actor.body_visual.get_child(0).name))
 check(names==['pirate','pirate_navigator','pirate_gunner','pirate_firstmate'],'the native rear line instantiates four distinct authored crew models')
 check(crew.all(func(actor):return actor.rig.parts.has_all(['Eye_L','Eye_R','Pupil_L','Pupil_R','Brow_L','Brow_R','Mouth','Hand_L','Hand_R','Hat']) and actor.rig.parts.Pupil_L.get_parent()==actor.rig.parts.Eye_L and actor.rig.parts.Pupil_R.get_parent()==actor.rig.parts.Eye_R),'all four cast faces and held tools have separate resettable pivots with attached pupils')
 track_assembly()
 check(max_hinge_error<.00001 and min_axis_alignment>.99999,'actual GLB axle and bearing anchor nodes line up in the initial native assembly')
 check(crew.all(func(actor):return actor.body_visual.scale.is_equal_approx(Vector3.ONE)),'the four wooden boards stay rigid in live idle instead of balloon-like stretching')
 screenshot('closed')
 await frames(390)
 screenshot('idle')
 check(game.records.is_empty() and camera_pose.is_equal_approx(world.camera.global_transform),'a full quiet-and-gesture idle interval spends no ammunition and preserves the aim camera')
 var captain=world.targets[5]
 await shoot(captain.global_position+Vector3(0,0,.38))
 check(not game.records.back().valid and game.records.back().base==0 and captain.is_shielded() and captain.shield_hit.collision_layer==1 and captain.cover_reaction_age>=1,'the real spring shot is blocked without breaking or posing a false reveal')
 screenshot('blocked')
 await frames(18)
 await shoot(captain.global_position+Vector3(0,0,.38))
 check(game.records.back().valid and game.records.back().base==5 and not game.records.back().destroyed and captain.shield_hit.collision_layer==0 and captain.shield_broken,'real ordinary fire removes shield collision immediately and scores the unchanged five base points')
 check(matching_palette([Color('425f59'),Color('b29965'),Color('76553b')],12),'actual broken-cover chips use the new painted wood, brass and timber palette')
 await frames(3)
 check(anchor_error(captain)>.01 and captain.alive,'the broken cover physically detaches from its actual bearing while the pirate remains alive')
 screenshot('break')
 await keyboard(KEY_TAB)
 var fall_pose: Transform3D=captain.shield_visual.transform
 var fall_age: float=captain.shield_break_age
 var reaction_age: float=captain.cover_reaction_age
 await frames(12)
 check(game.state==game.State.PAUSED and fall_pose.is_equal_approx(captain.shield_visual.transform) and is_equal_approx(fall_age,captain.shield_break_age) and is_equal_approx(reaction_age,captain.cover_reaction_age),'real pause freezes the broken cover and its facial reaction clocks')
 await keyboard(KEY_ESCAPE)
 await frames(30)
 check(not captain.shield_visual.visible and captain.alive,'resume completes cover retirement without retiring the pirate')
 await shoot(captain.global_position+Vector3(0,0,.24))
 check(game.records.back().destroyed and game.records.back().weak and game.records.back().base==45 and captain.body_hit.collision_layer==0,'the real follow-up weakpoint cashes in the same pirate for 45 base and retires its hitboxes')
 check(matching_palette([Color('79424a'),Color('dbcca8'),Color('b29965')],20),'actual captain retirement uses its painted coat and gesso colors rather than a generic wood override')
 screenshot('retirement')
 await frames(18)
 await shoot(world.bell.global_position)
 check(game.records.back().valid and game.records.back().base==5 and crew.slice(1,4).all(func(actor):return actor.exposed>0 and actor.shield_hit.collision_layer==0),'a real bell reveals the three living remaining crew and keeps the five-point mechanism rule')
 await frames(3)
 check(world.targets[6].rig.parts.Eye_L.scale.y>1.0 and world.targets[6].cover_reaction_age<.55,'the actual opening gives one short widened-eye reaction on the living navigator')
 screenshot('hinge-opening')
 await keyboard(KEY_TAB)
 var navigator=world.targets[6]
 var cover_pose: Transform3D=navigator.shield_visual.transform
 var eye_pose: Transform3D=navigator.rig.parts.Eye_L.transform
 reaction_age=navigator.cover_reaction_age
 await frames(12)
 check(cover_pose.is_equal_approx(navigator.shield_visual.transform) and eye_pose.is_equal_approx(navigator.rig.parts.Eye_L.transform) and is_equal_approx(reaction_age,navigator.cover_reaction_age),'pause also freezes the intact hinge, eyes and bounded reveal response together')
 await keyboard(KEY_ESCAPE)
 for i in range(20):
  await frames(1)
  track_assembly()
 check(max_hinge_error<.00001 and min_axis_alignment>.99999 and max_marker_drift<2,'actual authored axle/bearing anchors stay connected and target marks stay registered throughout the real turn and rail movement')
 screenshot('hinge-open')
 await frames(170)
 track_assembly()
 check(navigator.exposed==0 and navigator.shield_open<.001 and navigator.shield_hit.collision_layer==1 and anchor_error(navigator)<.00001,'actual exposure expiry closes the same mounted cover and restores its shield collision')
 screenshot('hinge-closed')
 await shoot(world.bell.global_position)
 check(game.state==game.State.SCORE and game.last_result.score==294 and game.records.size()==5,'the real blocked/break/kill/bell/bell sequence creates the unchanged 294-point receipt')
 await frames(70)
 check(navigator.cover_reaction_age>=.55 and navigator.rig.parts.Eye_L.scale.y<=1 and navigator.exposed>0,'reveal expression settles on the presentation clock even when receipt accounting has frozen exposure time')
 screenshot('receipt')
 await begin(0)
 await shoot(world.bell.global_position)
 await frames(18)
 screenshot('four-crew-revealed')
 for index in range(5,9):
  await shoot(world.targets[index].global_position+Vector3(0,0,.24))
  if index<8:await frames(22)
 await frames(80)
 var real_win_score: int=game.total_score
 await keyboard(KEY_SPACE)
 await frames(115)
 check(game.state==game.State.END and world.finale_won and real_win_score==4605,'actual bell and four-role weakpoint harvest earn the unchanged 4605-point victory')
 screenshot('win')
 game.set_reduced_motion(true)
 await begin(0)
 await shoot(world.bell.global_position)
 for i in range(25):
  await frames(1)
  track_assembly()
 check(crew.all(func(actor):return actor.body_visual.scale.is_equal_approx(Vector3.ONE) and actor.rig.parts.Hat.rotation.is_zero_approx() and actor.rig.parts.Pupil_L.position.is_equal_approx(actor.rig.rests.Pupil_L.origin) and is_equal_approx(actor.rig.parts.Eye_L.scale.y,1)) and max_hinge_error<.00001,'reduced motion keeps the real mounted flip while removing cast habits, gaze and eye flourishes')
 await shoot(world.targets[6].global_position+Vector3(0,0,.24))
 check(game.records.back().destroyed and game.records.back().weak and matching_palette([Color('3e6860'),Color('dbcca8'),Color('b29965')],6),'reduced real navigator kill keeps its matching palette in the six-particle budget')
 screenshot('reduced')
 game.reset_round()
 var restored=true
 for actor in crew:
  for part in actor.rig.parts:restored=restored and actor.rig.parts[part].transform.is_equal_approx(actor.rig.rests[part])
  restored=restored and actor.cover_reaction_age==1 and not actor.cover_was_open and anchor_error(actor)<.00001 and actor.shield_hit.collision_layer==1
 check(restored,'restart restores all crew pivots, visible bearing connection and reveal clocks')
 game.set_reduced_motion(false)
 game.start_round()
 await frames(30)
 if window_review:
  for size_ in [Vector2i(1152,720),Vector2i(1920,1080)]:
   root.size=size_
   await frames(12)
   var inside=true
   for actor in crew:
    var face: Vector2=world.camera.unproject_position(actor.rig.parts.Eye_L.global_position)
    inside=inside and root.get_visible_rect().has_point(face) and face.y>130
   check(inside,'all four crew faces remain inside the native gameplay viewport below the top counters at '+str(size_.x))
   screenshot('window-'+str(size_.x))
  root.size=Vector2i(1440,900)
  await frames(8)
 check(camera_pose.is_equal_approx(world.camera.global_transform),'all real block/break/reveal/harvest/reset paths preserve the fixed camera')
 print('CREW REVIEW: ',JSON.stringify({'passed':passed,'failed':failed,'window_review':window_review,'models':names,'actual_outcomes':outcomes,'max_imported_anchor_drift':max_hinge_error,'minimum_imported_axle_alignment':min_axis_alignment,'max_marker_drift_px':max_marker_drift,'actual_debris_palettes':captured_palettes,'early_full_score':294,'real_win_score':real_win_score,'camera_stable':camera_pose.is_equal_approx(world.camera.global_transform)}))
 await frames(24)
 for player in game.sound_players:
  player.stop()
  player.stream=null
 await frames(3)
 quit.call_deferred(1 if failed else 0)
