extends SceneTree
var view:SubViewport
func _initialize():call_deferred('run')
func picture()->Image:
 for i in 3:RenderingServer.force_draw(false);await process_frame
 return view.get_texture().get_image()
func run():
 view=SubViewport.new();view.size=Vector2i(160,160);view.own_world_3d=true;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(view)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLACK
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=1;view.add_child(env)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3;camera.position=Vector3(0,-7,0);view.add_child(camera);camera.look_at(Vector3(0,-4.5,0),Vector3.FORWARD);camera.current=true
 var object=MeshInstance3D.new();view.add_child(object)
 var material=ShaderMaterial.new();material.shader=load('res://shaders/terrain_editor/sculpt_terrain.gdshader');preload('res://scripts/terrain_editor/material_detail.gd').bind(material);object.material_override=material
 var images:Array[Image]=[]
 for water:float in [-1.0,3.5]:
  var surface=preload('res://scripts/terrain_editor/rock_sculpt_mesh.gd').SculptSurface.new()
  surface.quad(Vector3(-1,-4.5,-1),Vector3(-1,-4.5,1),Vector3(1,-4.5,1),Vector3(1,-4.5,-1),Color(0,0,0,1))
  for i in surface.vertices.size():surface.normals[i]=Vector3.DOWN;surface.uv[i]=Vector2(3,water)
  object.mesh=surface.mesh();images.append(await picture())
 var changes:=0;var foreground:=0
 for y in range(20,140):
  for x in range(20,140):
   var a:Color=images[0].get_pixel(x,y);var b:Color=images[1].get_pixel(x,y)
   if maxf(a.r,maxf(a.g,a.b))>.03:foreground+=1
   if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.008:changes+=1
 var up_images:Array[Image]=[]
 camera.position=Vector3(0,6,0);camera.look_at(Vector3(0,3,0),Vector3.FORWARD)
 for water:float in [-1.0,3.5]:
  var surface=preload('res://scripts/terrain_editor/rock_sculpt_mesh.gd').SculptSurface.new()
  surface.quad(Vector3(-1,3,-1),Vector3(1,3,-1),Vector3(1,3,1),Vector3(-1,3,1),Color(0,0,0,1))
  for i in surface.vertices.size():surface.normals[i]=Vector3.UP;surface.uv[i]=Vector2(3,water)
  object.mesh=surface.mesh();up_images.append(await picture())
 var up_changes:=0
 for y in range(20,140):
  for x in range(20,140):
   var a:Color=up_images[0].get_pixel(x,y);var b:Color=up_images[1].get_pixel(x,y)
   if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.008:up_changes+=1
 var passed=foreground>500 and changes==0 and up_changes>500
 print('SCULPT BASE UNDERSIDE MATERIAL: foreground=',foreground,' pond_tag_changes=',changes,' valid_bed_changes=',up_changes,' passed=',passed)
 view.queue_free();quit(0 if passed else 1)
