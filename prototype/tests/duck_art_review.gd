extends SceneTree
## Actual archived world/GLB and current world/GLB, same importer and held stage.
const LEGACY = "res://../.art_archive/2026-10-02-v15/"
class ReviewWorld extends "res://scripts/world.gd":
 func model(asset: String, parent: Node3D, pos: Vector3 = Vector3.ZERO) -> Node3D:
  if asset != 'duck': return super.model(asset,parent,pos)
  var doc=GLTFDocument.new()
  var data=GLTFState.new()
  if doc.append_from_file(ProjectSettings.globalize_path('res://assets/models/duck.glb'),data)!=OK:
   push_error('Unable to import current duck')
  var node=doc.generate_scene(data)
  node.position=pos
  parent.add_child(node)
  apply_finishes(node)
  return node
var game: Node3D
var observations: Array=[]
func _initialize() -> void:
 run.call_deferred()
func rendered() -> void:
 for i in range(5):
  await process_frame
  await RenderingServer.frame_post_draw
func setup(before: bool) -> void:
 game=load('res://main.tscn').instantiate()
 root.add_child(game)
 game.set_physics_process(false)
 game.set_process(false)
 game.sound_on=false
 game.world.free()
 var world: Node3D
 if before:
  var script=GDScript.new()
  var source=FileAccess.get_file_as_string(ProjectSettings.globalize_path(LEGACY+'world.gd'))
  var old='\tvar packed: PackedScene = load("res://assets/models/" + asset + ".glb")\n\tvar node: Node3D = packed.instantiate()'
  var replacement='\tvar node: Node3D\n\tif asset == "duck":\n\t\tvar doc = GLTFDocument.new()\n\t\tvar data = GLTFState.new()\n\t\tif doc.append_from_file("'+ProjectSettings.globalize_path(LEGACY+'duck.glb')+'", data) != OK:\n\t\t\tpush_error("Unable to import archived duck")\n\t\tnode = doc.generate_scene(data)\n\telse:\n\t\tvar packed: PackedScene = load("res://assets/models/" + asset + ".glb")\n\t\tnode = packed.instantiate()'
  if not source.contains(old):
   push_error('Archived importer adapter cannot find exact original model loader')
   quit(1)
   return
  script.source_code=source.replace(old,replacement)
  if script.reload()!=OK:
   push_error('Unable to compile archived world')
   quit(1)
   return
  world=script.new()
 else: world=ReviewWorld.new()
 game.world=world
 game.add_child(world)
 game.start_round()
 world.update_world(.40,false,1)
 game.hud.update_hud(.40)
 await rendered()
func snapshot(name_: String) -> void:
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://artifacts/v15-'+name_+'.png'))
func hero(before: bool) -> void:
 game.hud.root.hide()
 game.world.duck_label.hide()
 game.world.gun.hide()
 var world=game.world
 world.duck.reparent(world)
 world.duck.transform=Transform3D.IDENTITY
 for node in world.get_children():
  if node is Node3D and node!=world.duck and node!=world.camera and not node is Light3D: node.hide()
 world.camera.position=Vector3(-1.08,.70,1.20)
 world.camera.fov=32
 world.camera.look_at(Vector3(0,.10,0))
 await rendered()
 snapshot('before-duck-hero' if before else 'duck-hero')
func run() -> void:
 root.size=Vector2i(1440,900)
 await setup(true)
 snapshot('before-duck')
 var camera_pose: Transform3D=game.world.camera.global_transform
 var points: Array=[]
 for t in game.world.targets: points.append(game.world.camera.unproject_position(t.weak_hit.global_position))
 await hero(true)
 game.free()
 await process_frame
 await setup(false)
 var world=game.world
 snapshot('after-duck')
 var registration=0.0
 for i in range(world.targets.size()):
  registration=maxf(registration,points[i].distance_to(world.camera.unproject_position(world.targets[i].weak_hit.global_position)))
 var upgrade_visibility: Array=[]
 for level in range(4):
  world.set_duck_level(level)
  world.duck_growth=0
  world.animate_duck(0)
  await rendered()
  snapshot('duck-level-%d' % level)
  var visibility: Array=[]
  for n in range(1,4): visibility.append(world.duck_rig.parts['Upgrade_%d' % n].visible)
  upgrade_visibility.append(visibility)
 var visible: Image=root.get_texture().get_image()
 world.duck.hide()
 await rendered()
 var hidden: Image=root.get_texture().get_image()
 var occlusion=0.0
 var probes: Array=[]
 for target in world.targets:
  var point: Vector2=world.camera.unproject_position(target.weak_hit.global_position)
  var change=0.0
  for x in range(-4,5):
   for y in range(-4,5):
    var v=visible.get_pixel(int(point.x)+x,int(point.y)+y)
    var h=hidden.get_pixel(int(point.x)+x,int(point.y)+y)
    change=maxf(change,maxf(absf(v.r-h.r),maxf(absf(v.g-h.g),absf(v.b-h.b))))
  occlusion=maxf(occlusion,change)
  probes.append({'target':target.index,'duck_hidden_pixel_change':change})
 world.duck.show()
 await rendered()
 var attached=world.duck_rig.parts.Duck_Eye_L.get_parent()==world.duck_rig.parts.Duck_Head and world.duck_rig.parts.Duck_Eye_R.get_parent()==world.duck_rig.parts.Duck_Head and world.duck_rig.parts.Duck_Beak.get_parent()==world.duck_rig.parts.Duck_Head
 var same_camera=camera_pose.is_equal_approx(world.camera.global_transform)
 print('DUCK ART REVIEW: ',JSON.stringify({'actual_archived_world_and_glb':true,'same_runtime_glTF_importer_and_held_stage':true,'max_target_registration_change_px':registration,'camera_stable':same_camera,'max_target_duck_hidden_pixel_change':occlusion,'native_weakpoint_probes':probes,'face_parented_to_neck':attached,'upgrade_visibility':upgrade_visibility,'scope':'Native fixed held-stage comparison, level-three 9x9 weakpoint visibility probes and separate assembled asset closeup; not human recognition, all aim states or realtime performance.'}))
 if registration>.01 or occlusion>.01 or not same_camera or not attached or upgrade_visibility!=[[false,false,false],[true,false,false],[true,true,false],[true,true,true]]:
  push_error('Duck artwork changed target registration, face parenting or upgrades')
  quit(1)
  return
 await hero(false)
 game.free()
 await process_frame
 quit()
