extends SceneTree
## Real foam material over a transparent target: core is aerated coverage,
## not an opaque white pad; ripple arcs have moving gaps.
var viewport:SubViewport
var material:ShaderMaterial
var OUT='res://art/review/terrain_fidelity/2026-10-15/waterfall_finish/'
func _initialize()->void:call_deferred('run')
func capture()->Image:
 for i in 8:RenderingServer.force_draw(false);await process_frame
 return viewport.get_texture().get_image()
func run()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('out='):OUT=arg.trim_prefix('out=')
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 viewport=SubViewport.new();viewport.size=Vector2i(360,360);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.5;camera.position=Vector3(0,8,0);viewport.add_child(camera);camera.look_at(Vector3.ZERO,Vector3.BACK);camera.current=true
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-60,20,0);viewport.add_child(light)
 RenderingServer.global_shader_parameter_set('terrain_morph_progress',1.0)
 material=ShaderMaterial.new();material.shader=load('res://shaders/terrain_editor/foam.gdshader')
 var mesh:=MeshInstance3D.new();viewport.add_child(mesh);mesh.material_override=material
 var report:={};var core_image:Image
 for kind:String in ['core','ring']:
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color.WHITE if kind=='core' else Color(0,1,1,.5));st.set_normal(Vector3.UP)
  for p:Vector3 in [Vector3(-1.5,0,-1.5),Vector3(1.5,0,1.5),Vector3(1.5,0,-1.5),Vector3(-1.5,0,-1.5),Vector3(-1.5,0,1.5),Vector3(1.5,0,1.5)]:st.add_vertex(p)
  mesh.mesh=st.commit();material.set_shader_parameter('foam_time',0.0);var a:=await capture();a.save_png(OUT+'foam_'+kind+'_0.png')
  material.set_shader_parameter('foam_time',1.2);var b:=await capture();b.save_png(OUT+'foam_'+kind+'_1.png')
  var opaque:=0;var gaps:=0;var moving:=0;var visible:=0;var low:=1.0;var high:=0.0
  for y in range(80,280):
   for x in range(80,280):
    var alpha:=a.get_pixel(x,y).a;low=minf(low,alpha);high=maxf(high,alpha)
    if alpha>.95:opaque+=1
    if alpha<.02:gaps+=1
    if alpha>.05:visible+=1
    if absf(alpha-b.get_pixel(x,y).a)>.04:moving+=1
  report[kind]={'opaque':opaque,'gaps':gaps,'moving':moving,'visible':visible,'min_alpha':low,'max_alpha':high,'probes':40000}
 var ok:bool=report.core.opaque<2000 and report.core.visible>30000 and report.core.moving>2000 and report.ring.gaps>2000 and report.ring.visible>10000 and report.ring.moving>2000
 report.passed=ok;FileAccess.open(OUT+'foam_fixture_checks.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print('FOAM BREAKUP RENDER: ',report);quit(0 if ok else 1)
