extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco=preload("res://scripts/terrain_editor/terrain_decoration.gd")
const Renderer=preload("res://scripts/terrain_editor/terrain_renderer.gd")
const OUT="res://art/review/terrain_fidelity/2026-10-11/rocks_step5/"
var viewport:SubViewport
func _initialize():call_deferred("run")
func capture()->Image:
 for i in 8:
  RenderingServer.force_draw(false);await process_frame
 return viewport.get_texture().get_image()
func run():
 var data:=Data.new();data.make_preset(0);var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco._column_layout(field,data.seed)
 var renderer:=Renderer.new();renderer.configure(data)
 viewport=SubViewport.new();viewport.size=Vector2i(768,512);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var mesh:=MeshInstance3D.new();mesh.mesh=field.surfaces.rim_green.mesh();mesh.material_override=renderer.materials.rim_green;viewport.add_child(mesh)
 var camera:=Camera3D.new();camera.position=Vector3(-7,8,16);viewport.add_child(camera);camera.look_at(Vector3(-12,3.5,3));camera.fov=31;camera.current=true
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,30,0);viewport.add_child(light)
 var standing:=await capture();standing.save_png(OUT+"lip_mask_standing.png")
 var img:=Image.create(2,2,false,Image.FORMAT_R8);img.fill(Color(1,0,0));renderer.set_grass_compression(ImageTexture.create_from_image(img),Rect2(-64,-64,128,128))
 var flat:=await capture();flat.save_png(OUT+"lip_mask_flat.png")
 renderer.set_grass_compression(ImageTexture.create_from_image(img),Rect2(-14,-64,4,128))
 var partial:=await capture();partial.save_png(OUT+"lip_mask_local.png")
 var before:=0;var after:=0;var local_count:=0
 for y in 512:
  for x in 768:
   if standing.get_pixel(x,y).a>.5:before+=1
   if flat.get_pixel(x,y).a>.5:after+=1
   if partial.get_pixel(x,y).a>.5:local_count+=1
 var ok:=before>500 and after<before*.05 and local_count>100 and local_count<before-100
 var report:={"standing_pixels":before,"compressed_pixels":after,"local_mask_pixels":local_count,"passed":ok}
 FileAccess.open(OUT+"lip_compression_render.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("LIP COMPRESSION RENDER: ",report)
 renderer.free();quit(0 if ok else 1)
