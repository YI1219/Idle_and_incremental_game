extends SceneTree
## A real above-water red marker must appear at its mirrored position, while
## a neutral submerged bed must never create a false red reflection.
var viewport:SubViewport
var camera:Camera3D
var water:ShaderMaterial
var OUT='res://art/review/terrain_fidelity/2026-10-15/water_reflection/'
func _initialize()->void:call_deferred('run')
func box(size:Vector3,at:Vector3,color:Color)->MeshInstance3D:
 var mesh:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=size;mesh.mesh=shape;mesh.position=at
 var material:=StandardMaterial3D.new();material.albedo_color=color;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.material_override=material
 viewport.add_child(mesh);return mesh
func capture()->Image:
 for i in 12:
  RenderingServer.force_draw(false);await process_frame
 return viewport.get_texture().get_image()
func redness(image:Image,center:Vector2)->int:
 var count:=0
 for y in range(int(center.y)-13,int(center.y)+14):
  for x in range(int(center.x)-13,int(center.x)+14):
   var c:=image.get_pixel(x,y)
   if c.r-c.g>.045 and c.r-c.b>.045:count+=1
 return count
func run()->void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 viewport=SubViewport.new();viewport.size=Vector2i(640,480);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.2,.2,.2);viewport.add_child(env)
 camera=Camera3D.new();camera.position=Vector3(0,4,8);camera.fov=50;viewport.add_child(camera);camera.look_at(Vector3(0,0,-1));camera.current=true
 box(Vector3(8,.1,8),Vector3(0,-1.1,0),Color(.35,.35,.35))
 var marker:=box(Vector3(1,2,.6),Vector3(0,1,-2),Color(1,.01,.01))
 var plane:=MeshInstance3D.new();var shape:=PlaneMesh.new();shape.size=Vector2(8,8);plane.mesh=shape
 water=ShaderMaterial.new();water.shader=load('res://shaders/terrain_editor/water.gdshader');water.render_priority=-10
 water.set_shader_parameter('water_deep',Vector3(.2,.2,.2))
 var field:=Image.create(2,2,false,Image.FORMAT_RGBAF);field.fill(Color(.5,0,0,1))
 water.set_shader_parameter('shore_field',ImageTexture.create_from_image(field));water.set_shader_parameter('shore_origin',Vector2(-4,-4));water.set_shader_parameter('shore_extent',Vector2(8,8))
 plane.material_override=water;viewport.add_child(plane)
 var projected:=camera.unproject_position(Vector3(0,-.8,-2))
 water.set_shader_parameter('reflection_strength',0.0);var disabled:=await capture();disabled.save_png(OUT+'fixture_disabled.png')
 water.set_shader_parameter('reflection_strength',.8);var enabled:=await capture();enabled.save_png(OUT+'fixture_enabled.png')
 marker.hide();var absent:=await capture();absent.save_png(OUT+'fixture_absent.png')
 var off:=redness(disabled,projected);var on:=redness(enabled,projected);var gone:=redness(absent,projected)
 marker.position.x=1.8;marker.show()
 var moved:=await capture();moved.save_png(OUT+'fixture_moved.png')
 var shifted:=camera.unproject_position(Vector3(1.8,-.8,-2))
 var moved_count:=redness(moved,shifted);var stale:=redness(moved,projected)
 camera.position=Vector3(-3,4,8);camera.look_at(Vector3(0,0,-1))
 var angled:=await capture();angled.save_png(OUT+'fixture_angled.png')
 var angled_count:=redness(angled,camera.unproject_position(Vector3(1.8,-.8,-2)))
 var passed:=on>30 and off==0 and gone==0 and moved_count>30 and stale==0 and angled_count>30
 var report:={'projected_mirror':str(projected),'reflected_red_pixels':on,'disabled_red_pixels':off,'removed_marker_red_pixels':gone,'moved_marker_red_pixels':moved_count,'stale_mirror_red_pixels':stale,'angled_camera_red_pixels':angled_count,'passed':passed}
 FileAccess.open(OUT+'fixture_checks.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'))
 print('WATER REFLECTION RENDER: ',JSON.stringify(report));quit(0 if passed else 1)
