extends SceneTree
const Renderer=preload('res://scripts/terrain_editor/terrain_renderer.gd')
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const OUT='res://art/review/terrain_fidelity/2026-10-11/rocks_step4/'
var viewport:SubViewport
func _initialize():call_deferred('run')
func capture()->Image:
 for i in 8:
  RenderingServer.force_draw(false)
  await process_frame
 return viewport.get_texture().get_image()
func run():
 var renderer:=Renderer.new();var data:=Data.new();data.make_preset(0);renderer.configure(data)
 viewport=SubViewport.new();viewport.size=Vector2i(512,512);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(8,8);mesh.mesh=plane;mesh.material_override=renderer.materials.grass;viewport.add_child(mesh)
 var camera:=Camera3D.new();camera.position=Vector3(0,8,0);viewport.add_child(camera);camera.look_at(Vector3.ZERO,Vector3.FORWARD);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.current=true
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,30,0);viewport.add_child(light)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color(.6,.6,.6);environment.environment.ambient_light_energy=.4;viewport.add_child(environment)
 var standing:=await capture();standing.save_png(OUT+'grass_mask_standing.png')
 var img:=Image.create(64,64,false,Image.FORMAT_R8);img.fill(Color(1,0,0));var texture:=ImageTexture.create_from_image(img)
 renderer.set_grass_compression(texture,Rect2(-4,-4,8,8))
 var flat:=await capture();flat.save_png(OUT+'grass_mask_flat.png')
 for y in 64:
  for x in 64:img.set_pixel(x,y,Color(1 if x<32 else 0,0,0))
 texture.update(img)
 var half:=await capture();half.save_png(OUT+'grass_mask_half.png')
 var changed:=0;var left_error:=0.0;var right_error:=0.0;var count:=0
 for y in range(16,496):
  for x in range(16,240):
   if absf(standing.get_pixel(x,y).get_luminance()-flat.get_pixel(x,y).get_luminance())>.01:changed+=1
   left_error+=absf(half.get_pixel(x,y).get_luminance()-flat.get_pixel(x,y).get_luminance())
   right_error+=absf(half.get_pixel(511-x,y).get_luminance()-standing.get_pixel(511-x,y).get_luminance())
   count+=1
 var ok:=changed>count*.2 and left_error/count<.002 and right_error/count<.002
 var report:={'changed_pixels':changed,'samples':count,'flattened_half_error':left_error/count,'standing_half_error':right_error/count,'passed':ok}
 FileAccess.open(OUT+'grass_compression_render.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
 print('GRASS COMPRESSION RENDER: ',JSON.stringify(report))
 renderer.free();quit(0 if ok else 1)
