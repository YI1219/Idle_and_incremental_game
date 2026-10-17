extends SceneTree
const DIR='res://art/work/cliff_representation/2026-10-17/'
const OUT='res://art/review/terrain_fidelity/2026-10-17/cliff_representation/'
const Probe=preload('res://tools/art/probe_cliff_manifold.gd')
var viewport:SubViewport
var camera:Camera3D
var instance:MeshInstance3D
var frames:Array=[]
func _initialize():call_deferred('run')
func capture(name:String):
 for i in 8:RenderingServer.force_draw(false);await process_frame
 RenderingServer.force_draw(false)
 var error:=viewport.get_texture().get_image().save_png(OUT+name+'.png')
 assert(error==OK)
 frames.append({'file':name+'.png','error':error,'position':str(camera.position),'rotation':str(camera.rotation),'size':camera.size})
func height_texture(path:String)->ImageTexture:
 var image:=Image.create_from_data(1024,1024,false,Image.FORMAT_RF,FileAccess.get_file_as_bytes(path));image.generate_mipmaps()
 return ImageTexture.create_from_image(image)
func run():
 DirAccess.make_dir_recursive_absolute(OUT)
 viewport=SubViewport.new();viewport.size=Vector2i(1440,960);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var environment:=WorldEnvironment.new();var env:=Environment.new();environment.environment=env
 env.background_mode=Environment.BG_COLOR;env.background_color=Color('c7d2d4');env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color('b8c9db');env.ambient_light_energy=.65
 env.ssao_enabled=true;env.ssao_radius=1.3;env.ssao_intensity=1.3;env.ssao_power=1.6;env.ssao_detail=.5
 viewport.add_child(environment)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-38,-28,0);sun.light_color=Color('fff0d3');sun.light_energy=1.15;sun.shadow_enabled=true;viewport.add_child(sun)
 camera=Camera3D.new();camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera)
 instance=MeshInstance3D.new();viewport.add_child(instance)
 var neutral:=StandardMaterial3D.new();neutral.albedo_color=Color(.61,.61,.58);neutral.roughness=.9;neutral.metallic_specular=.16
 var stone:=ShaderMaterial.new();stone.shader=preload('res://tools/art/cliff_probe_contact.gdshader');preload('res://scripts/terrain_editor/material_detail.gd').bind(stone)
 var linear:ShaderMaterial=stone.duplicate();linear.set_shader_parameter('cover_enabled',true)
 # Height control uses the exact original packed maps from which these height
 # fields were generated. Both controls share the same maps and geometry.
 var old_detail:=Image.load_from_file(DIR+'height_maps/stone_detail.png');old_detail.generate_mipmaps()
 linear.set_shader_parameter('stone_detail_map',ImageTexture.create_from_image(old_detail));linear.set_shader_parameter('stone_relief_strength',.07)
 linear.set_shader_parameter('probe_stone_height',height_texture(DIR+'height_maps/stone_detail_height.bin'));linear.set_shader_parameter('probe_ground_height',height_texture(DIR+'height_maps/ground_detail_height.bin'))
 var height:ShaderMaterial=linear.duplicate();height.set_shader_parameter('height_contact',true)
 var views:Dictionary={'near':[Vector3(-11,6.5,12.0),Vector3(-15.2,2.5,3.0),8.0],'oblique':[Vector3(-8,8.0,17.0),Vector3(-14.8,1.7,3.0),13.0],'reverse':[Vector3(-26,7,-12),Vector3(-15,1.7,2.8),13.0]}
 for mode:String in ['flat','crease','stone']:
  instance.material_override=stone if mode=='stone' else neutral
  for shape:String in ['assembly','union','sampled']:
   var mesh:ArrayMesh=Probe.mesh_from_points(Probe.read_points(DIR+shape+'.bin'))
   instance.mesh=mesh if mode=='flat' else preload('res://scripts/terrain_editor/stone_normals.gd').soften(mesh,65.0,1.0)
   for view:String in views:
    camera.position=views[view][0];camera.look_at(views[view][1]);camera.size=views[view][2]
    await capture(shape+'_'+mode+'_'+view)
 instance.mesh=preload('res://scripts/terrain_editor/stone_normals.gd').soften(Probe.mesh_from_points(Probe.read_points(DIR+'union.bin')),65.0,1.0)
 var material_mesh_hash:String=instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].to_byte_array().hex_encode().sha256_text()
 for mode:String in ['linear_contact','height_contact']:
  instance.material_override=linear if mode=='linear_contact' else height
  for view:String in ['near','oblique','reverse']:
   camera.position=views[view][0];camera.look_at(views[view][1]);camera.size=views[view][2]
   await capture('union_'+mode+'_'+view)
 assert(material_mesh_hash==instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].to_byte_array().hex_encode().sha256_text())
 var report:Dictionary={'captures':frames,'renderer':RenderingServer.get_current_rendering_method(),'adapter':RenderingServer.get_video_adapter_name(),'resolution':[1440,960],'material_control_geometry_sha256_hex_algorithm':material_mesh_hash,'scope':'Isolated existing-source native study, fixed environment and cameras. No lawn/physical grass, trees, bottom backing or production scene replacement; not final island art or performance acceptance.'}
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t'));print('CLIFF REPRESENTATION CAPTURES: ',frames.size());quit()
