extends SceneTree
## Actual archived world/GLB and current world/GLB, same importer and held stage.
const LEGACY = "res://../.art_archive/2026-10-02-v14/"
class ReviewWorld extends "res://scripts/world.gd":
 func model(asset: String, parent: Node3D, pos: Vector3 = Vector3.ZERO) -> Node3D:
  if asset != 'revolver': return super.model(asset,parent,pos)
  var doc=GLTFDocument.new()
  var data=GLTFState.new()
  if doc.append_from_file(ProjectSettings.globalize_path('res://assets/models/revolver.glb'),data)!=OK:
   push_error('Unable to import current weapon')
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
  var replacement='\tvar node: Node3D\n\tif asset == "revolver":\n\t\tvar doc = GLTFDocument.new()\n\t\tvar data = GLTFState.new()\n\t\tif doc.append_from_file("'+ProjectSettings.globalize_path(LEGACY+'revolver.glb')+'", data) != OK:\n\t\t\tpush_error("Unable to import archived weapon")\n\t\tnode = doc.generate_scene(data)\n\telse:\n\t\tvar packed: PackedScene = load("res://assets/models/" + asset + ".glb")\n\t\tnode = packed.instantiate()'
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
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path('res://artifacts/v14-'+name_+'.png'))
func run() -> void:
 root.size=Vector2i(1440,900)
 await setup(true)
 snapshot('before-weapon')
 var before_camera: Transform3D=game.world.camera.global_transform
 var before_points: Array=[]
 for t in game.world.targets: before_points.append(game.world.camera.unproject_position(t.weak_hit.global_position))
 game.free()
 await process_frame
 await setup(false)
 snapshot('after-weapon')
 var world=game.world
 var max_registration=0.0
 for i in range(world.targets.size()):
  max_registration=maxf(max_registration,before_points[i].distance_to(world.camera.unproject_position(world.targets[i].weak_hit.global_position)))
 var max_occlusion=0.0
 var min_alignment=1.0
 for target in world.targets:
  world.gun_focus=target.weak_hit.global_position
  world.animate_gun(0,true)
  await rendered()
  var visible: Image=root.get_texture().get_image()
  var muzzle: Vector3=world.gun.to_global(Vector3(0,.035,-1.07))
  var alignment: float=(-world.gun.global_basis.z.normalized()).dot((world.gun_focus-muzzle).normalized())
  min_alignment=minf(min_alignment,alignment)
  world.gun.hide()
  await rendered()
  var hidden: Image=root.get_texture().get_image()
  var point: Vector2=world.camera.unproject_position(target.weak_hit.global_position)
  var change=0.0
  for x in range(-4,5):
   for y in range(-4,5):
    var v=visible.get_pixel(int(point.x)+x,int(point.y)+y)
    var h=hidden.get_pixel(int(point.x)+x,int(point.y)+y)
    change=maxf(change,maxf(absf(v.r-h.r),maxf(absf(v.g-h.g),absf(v.b-h.b))))
  max_occlusion=maxf(max_occlusion,change)
  observations.append({'target':target.index,'screen':[point.x,point.y],'weapon_hidden_pixel_change':change,'muzzle_alignment':alignment})
  world.gun.show()
 world.gun_focus=Vector3(0,2.7,-5)
 world.animate_gun(0,true)
 await rendered()
 snapshot('after-weapon')
 var hand: Vector2=world.camera.unproject_position(world.gun.to_global(Vector3(.025,-.30,.55)))
 var fill=world.gun.get_node('WeaponFill')
 print('WEAPON ART DIAGNOSTICS: ',JSON.stringify({'registration':max_registration,'same_camera':before_camera.is_equal_approx(world.camera.global_transform),'occlusion':max_occlusion,'alignment':min_alignment,'hand':[hand.x,hand.y],'mask':fill.light_cull_mask,'finger':world.gun_rig.parts.has('Index_Finger'),'observations':observations}))
 if max_registration>.01 or not before_camera.is_equal_approx(world.camera.global_transform) or max_occlusion>.01 or min_alignment<.9999 or hand.y>=740 or fill.light_cull_mask!=4 or not world.gun_rig.parts.has('Index_Finger'):
  push_error('Weapon art failed native target visibility, truthful muzzle, hand placement or isolated fill check')
  quit(1)
  return
 print('WEAPON ART REVIEW: ',JSON.stringify({'actual_archived_world_and_glb':true,'same_runtime_glTF_importer_and_held_stage':true,'max_target_registration_change_px':max_registration,'max_target_weapon_hidden_pixel_change':max_occlusion,'minimum_muzzle_alignment':min_alignment,'hand_screen':[hand.x,hand.y],'private_fill_mask':fill.light_cull_mask,'targets':observations,'scope':'Nine aimed weakpoint 9x9 native pixel probes at a fixed held pose; not human recognition or all possible aim/recoil positions.'}))
 # Inspect the actual imported assembled model, including grip and sleeve.
 game.hud.root.hide()
 world.gun.reparent(world)
 world.gun.transform=Transform3D.IDENTITY
 for node in world.get_children():
  if node is Node3D and node!=world.gun and node!=world.camera and not node is Light3D: node.hide()
 world.camera.position=Vector3(-1.8,.55,2.25)
 world.camera.fov=36
 world.camera.look_at(Vector3(0,-.20,-.3))
 await rendered()
 snapshot('weapon-hero')
 game.free()
 await process_frame
 quit()
