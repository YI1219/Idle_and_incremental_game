extends SceneTree
## Native proof scene. One production density mesh; no old wall/backing draws.
const Compiler=preload('res://tools/art/pcg_cliff_field.gd')
const Mesher=preload('res://scripts/terrain_editor/rock_sculpt_mesh.gd')
const Surface=preload('res://scripts/terrain_editor/chunk_geometry.gd').Surface
var OUT:='res://art/review/terrain_fidelity/2026-10-18/pcg_cliff/'
var WORK:='res://art/work/pcg_cliff/2026-10-18/'
var viewport:SubViewport
var camera:Camera3D
var body:MeshInstance3D
var grass:MeshInstance3D
var material:ShaderMaterial
var frames:Array=[]
var reports:Dictionary={}
var bins:Dictionary={}
var source:=PackedVector3Array()
var source_box:AABB
var source_foot:Vector3
var compiler=Compiler.new()
func _initialize():call_deferred('run')
func setup():
 viewport=SubViewport.new();viewport.size=Vector2i(1671,941);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var environment:=WorldEnvironment.new();var env:=Environment.new();environment.environment=env
 env.background_mode=Environment.BG_COLOR;env.background_color=Color('c7d2d4');env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color('b8c9db');env.ambient_light_energy=.45
 env.ssao_enabled=true;env.ssao_radius=1.3;env.ssao_intensity=1.3;env.ssao_power=1.6;env.ssao_detail=.5;env.ssao_light_affect=.25
 env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.adjustment_enabled=true;env.adjustment_contrast=1.04;viewport.add_child(environment)
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,40,0);sun.light_color=Color('ffe7c9');sun.light_energy=1.18;sun.light_specular=.28;sun.shadow_enabled=true;sun.light_angular_distance=2.2;sun.shadow_normal_bias=.3;viewport.add_child(sun)
 var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-45,-28,0);fill.light_color=Color('cedbe5');fill.light_energy=.19;viewport.add_child(fill)
 camera=Camera3D.new();camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera)
 body=MeshInstance3D.new();viewport.add_child(body)
 material=ShaderMaterial.new();material.shader=preload('res://tools/art/pcg_cliff_surface.gdshader');preload('res://scripts/terrain_editor/material_detail.gd').bind(material);material.set_shader_parameter('footpath_count',0);body.material_override=material
 grass=MeshInstance3D.new();viewport.add_child(grass)
 var leaf_material:=ShaderMaterial.new();leaf_material.shader=preload('res://shaders/terrain_editor/rim_green.gdshader');preload('res://scripts/terrain_editor/material_detail.gd').bind(leaf_material);leaf_material.set_shader_parameter('footpath_count',0);grass.material_override=leaf_material
 # Uniform values are linear; source-colour UI swatches cannot be copied as
 # linear shader values without washing the short sunlit blades to straw.
 leaf_material.set_shader_parameter('grass_base',Vector3(.11,.18,.065));leaf_material.set_shader_parameter('grass_highlight',Vector3(.20,.29,.11))
 var assets=preload('res://scripts/terrain_editor/terrain_models.gd').new();assets.load_assets()
 for part:Dictionary in assets.assets.grass:
  for p:Vector3 in part.mesh.get_faces():source.append(part.pose*p)
 source_box=AABB(source[0],Vector3.ZERO)
 for p:Vector3 in source:source_box=source_box.expand(p)
 source_foot=Vector3(source_box.get_center().x,source_box.position.y,source_box.get_center().z)
func mesh(data,control:bool)->ArrayMesh:
 var surface=Mesher.build(data.rocks)
 var count:int=surface.vertices.size()
 # Explicit separate-volume records receive shared gradient normals from
 # Mesher. The coherent-base production path uses actual face normals before
 # the crease pass. Match that path here; smoothing already-smoothed gradients
 # cannot preserve the generated geological turns. Vertex bytes stay intact.
 surface.normals.clear()
 for i in range(0,count,3):
  var normal:Vector3=-(surface.vertices[i+1]-surface.vertices[i]).cross(surface.vertices[i+2]-surface.vertices[i]).normalized()
  for j in 3:surface.normals.append(normal)
 surface.colors.clear()
 for p:Vector3 in surface.vertices:
  var h:Dictionary=compiler.horizontal(Vector2(p.x,p.z))
  var top:float=3.5 if control else compiler.cap_height(h.distance,h.arc)
  surface.colors.append(Color(clampf(top-p.y,0,1),0,0,1))
 var result:ArrayMesh=preload('res://scripts/terrain_editor/stone_normals.gd').soften(surface.mesh(),42.0,1.0)
 var vertices:PackedVector3Array=result.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 assert(vertices.size()==count)
 bins.clear()
 for i in range(0,vertices.size(),3):
  var a:=vertices[i];var b:=vertices[i+1];var c:=vertices[i+2]
  var n:=-(b-a).cross(c-a).normalized()
  if n.y<=.12:continue
  var lo:=Vector2(a.x,a.z).min(Vector2(b.x,b.z)).min(Vector2(c.x,c.z)).floor()
  var hi:=Vector2(a.x,a.z).max(Vector2(b.x,b.z)).max(Vector2(c.x,c.z)).floor()
  for z in range(int(lo.y),int(hi.y)+1):
   for x in range(int(lo.x),int(hi.x)+1):
    var key:=Vector2i(x,z)
    if not bins.has(key):bins[key]=[]
    bins[key].append([a,b,c,n])
 return result
func support(at:Vector2)->Dictionary:
 var best:Dictionary={};var height:=-INF
 for triangle:Array in bins.get(Vector2i(at.floor()),[]):
  var a:Vector3=triangle[0];var b:Vector3=triangle[1];var c:Vector3=triangle[2]
  var u:=Vector2(b.x-a.x,b.z-a.z);var v:=Vector2(c.x-a.x,c.z-a.z);var q:=at-Vector2(a.x,a.z)
  var det:=u.cross(v)
  if absf(det)<1e-12:continue
  var x:=q.cross(v)/det;var y:=u.cross(q)/det
  if x< -1e-6 or y< -1e-6 or x+y>1.000001:continue
  var h:float=a.y+x*(b.y-a.y)+y*(c.y-a.y)
  if h>height:height=h;best={'height':h,'normal':triangle[3]}
 return best
func leaves(data)->Dictionary:
 var result:=Surface.new();var roots:Array=[];var skipped:=0;var max_error:=0.0
 var rng:=RandomNumberGenerator.new();rng.seed=9017
 for z in range(-26,39):
  for x in range(-40,40):
   var at:=Vector2(x,z)*.18+Vector2(rng.randf_range(-.07,.07),rng.randf_range(-.07,.07))
   var h:Dictionary=compiler.horizontal(at)
   if h.distance>-.025 or h.distance<-.78:continue
   if sin(h.arc*1.6+.7*sin(h.arc*.53))<-.45 or rng.randf()>.74:continue
   var hit:=support(at)
   if hit.is_empty() or hit.height<3.05 or hit.normal.y<.35:skipped+=1;continue
   var scalar_height:float=data.rocks.height_at(at)
   assert(is_finite(scalar_height))
   max_error=maxf(max_error,absf(scalar_height-hit.height))
   assert(absf(scalar_height-hit.height)<.0001)
   var height:=rng.randf_range(.07,.17)
   if rng.randf()<.10:height*=1.6
   var scale:float=height/source_box.size.y
   var basis:=Basis(Vector3.UP,rng.randf()*TAU)*Basis(Vector3.RIGHT,rng.randf_range(-.52,.52))
   basis=basis.scaled(Vector3(1.7,1.0,1.7)*scale)
   var pose:=Transform3D(basis,Vector3(at.x,hit.height-.012,at.y)-basis*source_foot)
   roots.append({'xz':[at.x,at.y],'y':hit.height,'triangle_support':true,'field_support_error':absf(scalar_height-hit.height),'normal_y':hit.normal.y,'height':height})
   for i in range(0,source.size(),3):
    var a:=pose*source[i];var b:=pose*source[i+1];var c:=pose*source[i+2];var n:=-(b-a).cross(c-a).normalized()
    for p:Vector3 in [a,b,c]:
     result.vertices.append(p);result.normals.append(n);result.colors.append(Color.WHITE);result.uv.append(Vector2(hit.height,0));result.uv2.append(at)
 grass.mesh=result.mesh()
 assert(result.vertices.size()==roots.size()*source.size())
 return {'roots':roots,'source_vertices_per_fan':source.size(),'uploaded_vertices':result.vertices.size(),'skipped_unsupported':skipped,'max_root_support_error':max_error,'scope':'All source triangles retained; root support agrees with actual upward mesh triangles and production tetrahedral field. Leaf tips are not ground-contact constraints.'}
func capture(stage:String,view:String,position:Vector3,target:Vector3,size_value:float):
 camera.position=position;camera.look_at(target);camera.size=size_value
 for i in 8:RenderingServer.force_draw(false);await process_frame
 RenderingServer.force_draw(false)
 var file:=stage+'_'+view+'.png';var error:=viewport.get_texture().get_image().save_png(OUT+file);assert(error==OK)
 frames.append({'stage':stage,'view':view,'file':file,'position':str(position),'target':str(target),'size':size_value,'error':error})
func run():
 var quick:=false
 for arg:String in OS.get_cmdline_user_args():
  if arg=='--quick':quick=true
  elif arg.begins_with('--output='):OUT=arg.trim_prefix('--output=')
 DirAccess.make_dir_recursive_absolute(OUT);DirAccess.make_dir_recursive_absolute(WORK)
 setup()
 var stages:Array=['control','pcg_shape','pcg_contact'] if quick else ['control','pcg_shape','pcg_contact','pcg_seed7319','pcg_layout','pcg_carved','neutral']
 for stage:String in stages:
  var control:=stage=='control';var seed_value:=7319 if stage=='pcg_seed7319' else 7301
  var records:Dictionary={}
  if stage=='pcg_layout':
   records=compiler.fixture()
   for cell:Vector2i in records.keys():
    if cell.x>=4:records.erase(cell)
  var data=compiler.generate(seed_value,control,records)
  var before_hash:String=JSON.stringify(data.serialize()).sha256_text()
  if stage=='pcg_carved':data.begin_stroke();data.apply_rock_brush(Vector3(0,1.25,2.25),1.1,'rock_cut',Vector3.FORWARD);data.end_stroke()
  body.mesh=mesh(data,control)
  var finished:bool=stage in ['pcg_contact','pcg_seed7319','pcg_layout','pcg_carved']
  material.set_shader_parameter('contact_finish',finished);grass.visible=finished
  var contact:Dictionary=leaves(data) if finished else {}
  if stage=='neutral':
   var neutral:=StandardMaterial3D.new();neutral.albedo_color=Color(.60,.60,.57);neutral.roughness=.95;body.material_override=neutral
  else:body.material_override=material
  var vertices:PackedVector3Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  FileAccess.open(WORK+stage+'.bin',FileAccess.WRITE).store_buffer(vertices.to_byte_array())
  FileAccess.open(WORK+stage+'.layout',FileAccess.WRITE).store_string(JSON.stringify(data.serialize(),'\t',true,true))
  reports[stage]={'triangles':vertices.size()/3,'density_records':data.rocks.samples.size(),'cells':data.cells.size(),'before_hash':before_hash,'save_hash':JSON.stringify(data.serialize()).sha256_text(),'contact':contact,'sectors':compiler.sectors,'perimeter':compiler.perimeter}
  await capture(stage,'close',Vector3(9,7.6,15),Vector3(-.5,.8,.6),11.8)
  await capture(stage,'grass',Vector3(5,8,12),Vector3(-.3,2.9,1.8),7.6)
  await capture(stage,'whole',Vector3(13,13,19),Vector3(-.3,.0,.0),18.5)
  if not quick:
   await capture(stage,'reverse',Vector3(-13,8,-14),Vector3(-.5,.4,.0),16)
   await capture(stage,'bottom',Vector3(9,-8,15),Vector3(-.5,-1,.0),15.5)
 FileAccess.open(OUT+'captures.json',FileAccess.WRITE).store_string(JSON.stringify({'frames':frames,'stages':reports,'resolution':[1671,941],'fixed_lights':true,'adapter':RenderingServer.get_video_adapter_name(),'scope':'Native standalone crop of actual dry preset cells, translated by (15,-1). Shared .25m scalar samples and production tetrahedral mesher/public editing. This is not full-island renderer integration or target-device acceptance.'},'\t',true,true))
 print('PCG NATIVE: ',frames.size(),' frames, ',reports.size(),' states');quit()
