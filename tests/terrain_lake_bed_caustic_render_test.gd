extends SceneTree
var viewport:SubViewport
var material:ShaderMaterial
var OUT='res://art/review/terrain_fidelity/2026-10-15/water_finish/'
func _initialize()->void:call_deferred('run')
func capture()->Image:
 for i in 8:RenderingServer.force_draw(false);await process_frame
 return viewport.get_texture().get_image()
func changed(a:Image,b:Image,center:Vector2,threshold:float=.012)->int:
 var count:=0
 for y in range(int(center.y)-27,int(center.y)+28):
  for x in range(int(center.x)-27,int(center.x)+28):
   var c:=a.get_pixel(x,y);var d:=b.get_pixel(x,y)
   if absf(c.r-d.r)+absf(c.g-d.g)+absf(c.b-d.b)>threshold:count+=1
 return count
func run()->void:
 RenderingServer.global_shader_parameter_set('terrain_morph_progress',1.0)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 viewport=SubViewport.new();viewport.size=Vector2i(600,240);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.1,.1,.1);viewport.add_child(environment)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-65,20,0);viewport.add_child(light)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=7.5;camera.position=Vector3(0,10,0);viewport.add_child(camera);camera.look_at(Vector3.ZERO,Vector3.BACK);camera.current=true
 material=ShaderMaterial.new();material.shader=load('res://shaders/terrain_editor/lake_bed.gdshader');load('res://scripts/terrain_editor/material_detail.gd').bind(material)
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_color(Color(0,0,0,1));st.set_normal(Vector3.UP)
 for p:Vector3 in [Vector3(-1,0,-1),Vector3(1,0,1),Vector3(1,0,-1),Vector3(-1,0,-1),Vector3(-1,0,1),Vector3(1,0,1)]:st.add_vertex(p)
 var node:=MeshInstance3D.new();node.mesh=st.commit();node.material_override=material;viewport.add_child(node)
 camera.position=Vector3(-2.4,10,0);camera.look_at(Vector3(-2.4,0,0),Vector3.BACK)
 var production:float=RenderingServer.shader_get_parameter_default(material.shader.get_rid(),'caustic_strength')
 var differences:Array[int]=[];var motion:=0;var default_pixels:=0;var default_motion:=0
 # Use identical world XZ/texture/lighting for every depth, isolating depth
 # attenuation from the intentionally patchy spatial caustic coverage.
 for spec:Array in [['shallow',.25],['middle',1.5],['deep',4.5]]:
  node.position=Vector3(-2.4,-spec[1],0)
  var center:=camera.unproject_position(node.position)
  material.set_shader_parameter('caustic_time',0.0);material.set_shader_parameter('caustic_strength',0.0);var off:=await capture()
  material.set_shader_parameter('caustic_strength',.5);var on:=await capture()
  differences.append(changed(off,on,center))
  off.save_png(OUT+'caustic_'+spec[0]+'_off.png');on.save_png(OUT+'caustic_'+spec[0]+'_on.png')
  if spec[0]=='shallow':
   material.set_shader_parameter('caustic_time',2.5);var moved:=await capture();motion=changed(on,moved,center);moved.save_png(OUT+'caustic_moved.png')
   material.set_shader_parameter('caustic_time',0.0);material.set_shader_parameter('caustic_strength',production);var normal:=await capture()
   # Production light is intentionally faint. Count changes above one
   # 8-bit channel step, not the amplified fixture's stronger cutoff.
   default_pixels=changed(off,normal,center,.003)
   material.set_shader_parameter('caustic_time',2.5);var normal_moved:=await capture();default_motion=changed(normal,normal_moved,center,.003)
   normal.save_png(OUT+'caustic_default.png');normal_moved.save_png(OUT+'caustic_default_moved.png')
 var shallow:=differences[0];var middle:=differences[1];var deep:=differences[2]
 # A morph from top0 to previous top-1 scales water/bed depth by6/7.
 # Compare its actual shading with an equivalent static depth at same XZ.
 var field:=Image.create(2,2,false,Image.FORMAT_RGBAF);field.fill(Color(-1,0,0,0))
 RenderingServer.global_shader_parameter_set('terrain_morph_field',ImageTexture.create_from_image(field))
 RenderingServer.global_shader_parameter_set('terrain_morph_rect',Vector4(-20,-20,40,40))
 material.set_shader_parameter('caustic_time',0.0);material.set_shader_parameter('caustic_strength',.5)
 node.position.y=-1.5;RenderingServer.global_shader_parameter_set('terrain_morph_progress',0.0);var morph:=await capture()
 RenderingServer.global_shader_parameter_set('terrain_morph_progress',1.0);node.position.y=-1.5*6.0/7.0;var equivalent:=await capture()
 var morph_difference:=changed(morph,equivalent,camera.unproject_position(node.position))
 morph.save_png(OUT+'caustic_morph.png');equivalent.save_png(OUT+'caustic_equivalent.png')
 var passed:=shallow>100 and middle>25 and middle<=shallow and deep==0 and motion>100 and default_pixels>0 and default_motion>0 and morph_difference==0
 var report:={'shallow_changed_pixels':shallow,'middle_changed_pixels':middle,'deep_changed_pixels':deep,'moving_shallow_pixels':motion,'production_strength':production,'default_changed_pixels':default_pixels,'default_motion_pixels':default_motion,'morph_equivalence_changed_pixels':morph_difference,'passed':passed}
 FileAccess.open(OUT+'caustic_fixture_checks.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print('BED CAUSTIC RENDER: ',report);quit(0 if passed else 1)
