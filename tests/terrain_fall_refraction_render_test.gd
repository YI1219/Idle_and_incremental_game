extends SceneTree
## Fixed-phase spatial background sampling through a real falling-water quad.
var viewport:SubViewport
var OUT='res://art/review/terrain_fidelity/2026-10-15/waterfall_finish/refraction/'
func _initialize()->void:call_deferred('run')
func capture()->Image:
 for i in 8:RenderingServer.force_draw(false);await process_frame
 return viewport.get_texture().get_image()
func delta(a:Image,b:Image)->int:
 var count:=0
 for y in range(100,300):
  for x in range(140,460):
   var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
   if absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)>.03:count+=1
 return count
func run()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('out='):OUT=arg.trim_prefix('out=')
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 viewport=SubViewport.new();viewport.size=Vector2i(600,400);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var camera:=Camera3D.new();camera.position=Vector3(0,1.5,6);camera.fov=40;viewport.add_child(camera);camera.current=true
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,20,0);viewport.add_child(light)
 var pattern:=Image.create(128,128,false,Image.FORMAT_RGB8)
 for y in 128:
  for x in 128:pattern.set_pixel(x,y,Color(.8,.18,.12) if (x/8+y/8)%2==0 else Color(.12,.3,.8))
 var back:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(8,6);back.mesh=quad;back.position=Vector3(0,1.5,-1)
 var plain:=StandardMaterial3D.new();plain.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;plain.albedo_texture=ImageTexture.create_from_image(pattern);back.material_override=plain;viewport.add_child(back)
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_normal(Vector3(0,0,1))
 for p:Vector3 in [Vector3(-2,0,0),Vector3(2,3,0),Vector3(-2,3,0),Vector3(-2,0,0),Vector3(2,0,0),Vector3(2,3,0)]:
  st.set_color(Color((p.x+2)/4,(3-p.y)/16,.2,.2*(3-p.y)/3));st.add_vertex(p)
 var fall:=MeshInstance3D.new();fall.mesh=st.commit();viewport.add_child(fall)
 var material:=ShaderMaterial.new();var shader:=Shader.new()
 shader.code=FileAccess.get_file_as_string('res://shaders/terrain_editor/waterfall.gdshader').replace('#include "terrain_morph.gdshaderinc"',FileAccess.get_file_as_string('res://shaders/terrain_editor/terrain_morph.gdshaderinc')).replace('TIME','0.5');material.shader=shader;fall.material_override=material
 RenderingServer.global_shader_parameter_set('terrain_morph_progress',1.0)
 material.set_shader_parameter('refraction_strength',0.0);var off:=await capture();off.save_png(OUT+'off.png')
 material.set_shader_parameter('refraction_strength',.075);var on:=await capture();on.save_png(OUT+'on.png')
 var changed:=delta(off,on)
 material.set_shader_parameter('refraction_strength',null);var production:=await capture();production.save_png(OUT+'production.png')
 var default_changed:=delta(off,production)
 # Foreground must occlude the fall, never be sampled/distorted across it.
 var front:=MeshInstance3D.new();front.mesh=quad;front.position=Vector3(0,1.5,1)
 var green:=StandardMaterial3D.new();green.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;green.albedo_color=Color(.1,.8,.1);front.material_override=green;viewport.add_child(front)
 material.set_shader_parameter('refraction_strength',0.0);var covered_off:=await capture()
 material.set_shader_parameter('refraction_strength',.075);var covered_on:=await capture()
 var foreground:=delta(covered_off,covered_on)
 # A thin foreground strip can otherwise leak into neighboring visible fall
 # pixels when the displaced UV lands in front of the curtain. Compare to an
 # intentionally unguarded control to prove the rejection branch is exercised.
 var strip:=QuadMesh.new();strip.size=Vector2(1.0,5.0);front.mesh=strip
 var no_guard:=Shader.new();no_guard.code=shader.code.replace('if(depth<.00001 || behind_view.z/behind_view.w<VERTEX.z-.01)sample_uv=bent_uv;','sample_uv=bent_uv;')
 var edge_rejections:=0;var cases:Array=[]
 # A different strand phase may bend away from both edges of a centered
 # strip. Exercise multiple actual phases/positions, keeping the same guard
 # threshold and requiring an intentionally leaking control to differ.
 for spec:Array in [[0.0,.5],[-1.0,.5],[1.0,.5],[0.0,1.25],[0.0,2.5]]:
  front.position.x=spec[0]
  material.shader=shader;material.set_shader_parameter('refraction_strength',.15);material.set_shader_parameter('flow_time',spec[1]);var guarded:=await capture()
  material.shader=no_guard;material.set_shader_parameter('refraction_strength',.15);material.set_shader_parameter('flow_time',spec[1]);var leaking:=await capture()
  var rejected:=0
  var left:=camera.unproject_position(Vector3(spec[0]-.5,1.5,1)).x;var right:=camera.unproject_position(Vector3(spec[0]+.5,1.5,1)).x
  for y in range(100,300):
   for x in range(140,460):
    if x>=left-1 and x<=right+1:continue
    var a:=guarded.get_pixel(x,y);var b:=leaking.get_pixel(x,y)
    if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)>.02:rejected+=1
  if rejected>edge_rejections:
   guarded.save_png(OUT+'guarded_edge.png');leaking.save_png(OUT+'unguarded_edge.png')
  edge_rejections=maxi(edge_rejections,rejected)
  cases.append({'strip_x':spec[0],'flow_time':spec[1],'rejected_pixels':rejected})
 var ok:=changed>1000 and default_changed>300 and foreground==0 and edge_rejections>5
 var report:={'changed_background_pixels':changed,'foreground_difference_pixels':foreground,'production_default_changed_pixels':default_changed,'rejected_foreground_edge_samples':edge_rejections,'probes':64000,'guard_cases':cases,'passed':ok};FileAccess.open(OUT+'fixture_checks.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print('FALL REFRACTION RENDER: ',report);quit(0 if ok else 1)
