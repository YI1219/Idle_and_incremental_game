extends SceneTree
const OUT := "res://art/review/terrain_fidelity/2026-10-06/homestead/"
func _initialize()->void:call_deferred("run")
func run()->void:
 var viewport:=SubViewport.new()
 viewport.size=Vector2i(1671,941)
 viewport.own_world_3d=true
 viewport.msaa_3d=Viewport.MSAA_4X
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport)
 var editor=load("res://scenes/terrain_editor.tscn").instantiate()
 viewport.add_child(editor)
 editor.hud.hide();editor.brush.hide();editor.set_process(false);editor.camera.set_process(false)
 for i in 60:await process_frame
 await RenderingServer.frame_post_draw
 var tag:="updated" if OS.get_cmdline_user_args().is_empty() else OS.get_cmdline_user_args()[0]
 var error:=viewport.get_texture().get_image().save_png(OUT+tag+".png")
 var heights:Array=[]
 var decoration=editor.renderer.decoration
 for chunk in editor.renderer.chunks:
  for pose:Transform3D in decoration.placements(editor.data,chunk).tree:
   var box:AABB=decoration.assets.tree[0].mesh.get_aabb()
   heights.append((pose*box).size.y)
 var evidence:Dictionary={"capture":error,"trees_world_height":heights,"cottage_scale":str(editor.renderer.props.entries[0].node.scale),"camera_position":str(editor.camera.position),"camera_rotation":str(editor.camera.rotation_degrees),"renderer":RenderingServer.get_current_rendering_method(),"resolution":[viewport.size.x,viewport.size.y]}
 var file:=FileAccess.open(OUT+tag+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify(evidence,"\t"))
 print("HOMESTEAD: ",JSON.stringify(evidence))
 if tag=="updated":
  var height:=10.0
  var offset:=height/tan(deg_to_rad(27.0))
  editor.camera.position=Vector3(-9+sin(deg_to_rad(16.0))*offset,height,-5+cos(deg_to_rad(16.0))*offset)
  for i in 30:await process_frame
  await RenderingServer.frame_post_draw
  viewport.get_texture().get_image().save_png(OUT+"garden_detail.png")
 quit(error)
