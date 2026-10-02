extends SceneTree
## Actual archived world/target/two GLBs against current crew, same importer.
const LEGACY='res://../.art_archive/2026-10-02-v16/'
class ReviewWorld extends "res://scripts/world.gd":
 func model(asset: String,parent: Node3D,pos: Vector3=Vector3.ZERO) -> Node3D:
  if not asset in ['pirate','pirate_navigator','pirate_gunner','pirate_firstmate','shield']:return super.model(asset,parent,pos)
  var doc=GLTFDocument.new()
  var data=GLTFState.new()
  if doc.append_from_file(ProjectSettings.globalize_path('res://assets/models/'+asset+'.glb'),data)!=OK:push_error('Unable to import crew artwork')
  var node=doc.generate_scene(data)
  node.position=pos
  parent.add_child(node)
  apply_finishes(node)
  return node
var game: Node3D
var before_camera: Transform3D
var before_points: Array=[]
var before_colliders: Array=[]
func _initialize() -> void:run.call_deferred()
func rendered() -> void:
 for i in range(5):
  await process_frame
  await RenderingServer.frame_post_draw
func snapshot(name_: String) -> void:
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://artifacts/v16-'+name_+'.png'))
func setup(before: bool) -> void:
 game=load('res://main.tscn').instantiate()
 root.add_child(game)
 game.set_process(false)
 game.set_physics_process(false)
 game.sound_on=false
 game.world.free()
 var world: Node3D
 if before:
  var source=FileAccess.get_file_as_string(ProjectSettings.globalize_path(LEGACY+'world.gd'))
  var target_const='const Target = preload("res://scripts/target.gd")'
  var loader='\tvar packed: PackedScene = load("res://assets/models/" + asset + ".glb")\n\tvar node: Node3D = packed.instantiate()'
  var adapter='\tvar node: Node3D\n\tif asset in ["pirate", "shield"]:\n\t\tvar doc = GLTFDocument.new()\n\t\tvar data = GLTFState.new()\n\t\tif doc.append_from_file("'+ProjectSettings.globalize_path(LEGACY)+'" + asset + ".glb", data) != OK:\n\t\t\tpush_error("Unable to import archived crew artwork")\n\t\tnode = doc.generate_scene(data)\n\telse:\n\t\tvar packed: PackedScene = load("res://assets/models/" + asset + ".glb")\n\t\tnode = packed.instantiate()'
  if not source.contains(loader) or not source.contains(target_const):
   push_error('Archived source adapter does not match exact target preload/model loader')
   quit(1)
   return
  var script=GDScript.new()
  script.source_code=source.replace(target_const,'const Target = preload("'+LEGACY+'target.gd")').replace(loader,adapter)
  if script.reload()!=OK:
   push_error('Archived crew comparison could not compile')
   quit(1)
   return
  world=script.new()
 else:world=ReviewWorld.new()
 game.world=world
 game.add_child(world)
 game.start_round()
 world.update_world(.4,false,1)
 game.hud.update_hud(.4)
 await rendered()
func collider_description(target: Node3D) -> Dictionary:
 var description={}
 for name_ in ['body_hit','weak_hit','shield_hit']:
  var body=target.get(name_)
  if body:
   var shape=body.get_child(0).shape
   description[name_]={'position':str(body.position),'size':str(shape.size),'layers':body.collision_layer}
 return description
func reveal() -> void:
 # Fixed art-only pose; gameplay evidence lives in crew_walkthrough.gd.
 for target in game.world.targets:
  if target.kind=='pirate':
   target.exposed=3.0
   target.sync_visuals()
 game.world.update_world(.30,false,1)
 await rendered()
func hero() -> void:
 game.hud.root.hide()
 var world=game.world
 world.gun.hide()
 for node in world.get_children():
  if node is Node3D and node!=world.camera and not node is Light3D and not node in world.targets:node.hide()
 for target in world.targets:
  if target.index<5:target.hide()
 world.camera.position=Vector3(-.7,4.9,3.6)
 world.camera.fov=43
 world.camera.look_at(Vector3(-.7,3.8,-6))
 await rendered()
 snapshot('crew-hero')
func run() -> void:
 root.size=Vector2i(1440,900)
 await setup(true)
 snapshot('before-crew')
 before_camera=game.world.camera.global_transform
 for t in game.world.targets:
  before_points.append(game.world.camera.unproject_position(t.weak_hit.global_position))
  before_colliders.append(collider_description(t))
 await reveal()
 snapshot('before-crew-revealed')
 game.free()
 await process_frame
 await setup(false)
 var world=game.world
 snapshot('after-crew')
 var registration=0.0
 var collider_changes=0
 var face_parents=true
 var asset_names: Array=[]
 for t in world.targets:
  registration=maxf(registration,before_points[t.index].distance_to(world.camera.unproject_position(t.weak_hit.global_position)))
  if before_colliders[t.index]!=collider_description(t):collider_changes+=1
  if t.kind=='pirate':
   asset_names.append(str(t.body_visual.get_child(0).name))
   face_parents=face_parents and t.rig.parts.Pupil_L.get_parent()==t.rig.parts.Eye_L and t.rig.parts.Pupil_R.get_parent()==t.rig.parts.Eye_R
 await reveal()
 snapshot('after-crew-revealed')
 var visible: Image=root.get_texture().get_image()
 for t in world.targets:
  if t.kind=='pirate':t.shield_visual.hide()
 await rendered()
 var hidden: Image=root.get_texture().get_image()
 var occlusion=0.0
 var probes: Array=[]
 for t in world.targets:
  if t.kind!='pirate':continue
  var point: Vector2=world.camera.unproject_position(t.weak_hit.global_position)
  var change=0.0
  for x in range(-4,5):
   for y in range(-4,5):
    var v=visible.get_pixel(int(point.x)+x,int(point.y)+y)
    var h=hidden.get_pixel(int(point.x)+x,int(point.y)+y)
    change=maxf(change,maxf(absf(v.r-h.r),maxf(absf(v.g-h.g),absf(v.b-h.b))))
  probes.append({'index':t.index,'open_shield_hidden_pixel_change':change})
  occlusion=maxf(occlusion,change)
 for t in world.targets:
  if t.kind=='pirate':t.shield_visual.show()
 print('CREW ART REVIEW: ',JSON.stringify({'actual_archived_world_target_and_glbs':true,'same_runtime_glTF_importer':true,'camera_stable':before_camera.is_equal_approx(world.camera.global_transform),'max_target_registration_change_px':registration,'collider_definition_changes':collider_changes,'eyes_parented':face_parents,'open_shield_pixel_change':occlusion,'weakpoint_probes':probes,'asset_scene_names':asset_names,'scope':'Fixed native held-stage comparison; current revealed 9x9 weakpoint cover probes and separate cast closeup. Static reveal sets exposure for the art study, not gameplay evidence or human recognition.'}))
 if registration>.01 or collider_changes!=0 or not face_parents or not before_camera.is_equal_approx(world.camera.global_transform) or occlusion>.01:
  push_error('Crew artwork changed camera, collider registration, face parenting or revealed target pixels')
  quit(1)
  return
 await hero()
 game.free()
 await process_frame
 quit()
