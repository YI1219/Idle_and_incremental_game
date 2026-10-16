extends SceneTree
## Actual source geometry, not the object's pivot, must emerge from the bank.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Field=preload('res://scripts/terrain_editor/contour_terrain.gd')
const Deco=preload('res://scripts/terrain_editor/terrain_decoration.gd')
var failures:=0
var checked:=0
func _initialize()->void:call_deferred('run')
func ground_height(field,p:Vector2,h:float)->float:
 var result:=-INF
 var chunk:=Data.chunk_of(Vector2i(p.floor()))
 for kind in ['sculpted_terrain'] if field.source.sculpt_base_enabled else ['grass','shore','lake_bed']:
  var vertices:PackedVector3Array=field.surfaces[kind].vertices
  for i:int in field.triangle_chunks.get(chunk,{}).get(kind,[]):
   if kind=='sculpted_terrain':
    # Near-zero lattice crossings produce valid tiny projected triangles.
    # Geometry3D's generic ray epsilon skips some of these. Use independent
    # scalar barycentrics here instead of mistaking that epsilon for a hole.
    var a:=vertices[i];var b:=vertices[i+1];var c:=vertices[i+2]
    var denominator:float=(b.x-a.x)*(c.z-a.z)-(b.z-a.z)*(c.x-a.x)
    if absf(denominator)<1e-16:continue
    var u:float=((p.x-a.x)*(c.z-a.z)-(p.y-a.z)*(c.x-a.x))/denominator
    var v:float=((b.x-a.x)*(p.y-a.z)-(b.z-a.z)*(p.x-a.x))/denominator
    if u<-.00000001 or v<-.00000001 or u+v>1.00000001:continue
    var y:float=a.y+u*(b.y-a.y)+v*(c.y-a.y)
    if y<=h+.2:result=maxf(result,y)
    continue
   var hit=Geometry3D.ray_intersects_triangle(Vector3(p.x,h+.2,p.y),Vector3.DOWN,vertices[i],vertices[i+1],vertices[i+2])
   if hit!=null:result=maxf(result,hit.y)
 return result
func inspect(field,deco,kind:String,pose:Transform3D)->void:
 var vertices:PackedVector3Array=deco.assets[kind][0].mesh.get_faces()
 var lo:=INF;var hi:=-INF
 for p in vertices:lo=minf(lo,(pose*p).y);hi=maxf(hi,(pose*p).y)
 var sample:Dictionary=field.surface_at(Vector2(pose.origin.x,pose.origin.z))
 if sample.is_empty():failures+=1;return
 var h:float=sample.height
 # A continuous bank can slope below its pond. The seating section belongs
 # to the pond elevation, rather than the dry height under the stone pivot.
 if field.source.sculpt_base_enabled:
  var nearest:=INF
  for water:int in field.water_regions:
   if absf(water*.5-sample.height)<nearest:nearest=absf(water*.5-sample.height);h=water*.5
 var level:=lo+(hi-lo)*.30
 var dry_points:=0;var gaps:=0
 # Intersect all real triangle edges with a horizontal lower-third section.
 # Merely checking the lowest vertex misses raised, pinched lower flanks.
 var unique:Dictionary={}
 for i in range(0,vertices.size(),3):
  for j in 3:
   var a:Vector3=pose*vertices[i+j];var b:Vector3=pose*vertices[i+(j+1)%3]
   if (a.y-level)*(b.y-level)>=0.0:continue
   var p:=a.lerp(b,(level-a.y)/(b.y-a.y));var at:=Vector2(p.x,p.z)
   var land:Dictionary=field.surface_at(at)
   if land.is_empty() or land.water>=0 or absf(land.height-h)>.15:continue
   var key:=at.snapped(Vector2.ONE*.001)
   if unique.has(key):continue
   unique[key]=true;dry_points+=1;checked+=1
   var support:=ground_height(field,at,h)
   if support==-INF or p.y>support+.015:
    gaps+=1
    if OS.get_cmdline_user_args().has('debug_contact'):print('SHORE PROBE ',at,' flank=',p.y,' ground=',support,' land=',land,' pond=',h)
 if dry_points>0:
  failures+=gaps
  if gaps>0:print('RAISED LOWER FLANK ',kind,' ',pose.origin,' gaps=',gaps,'/',dry_points)
 else:
  # Fully wet pebbles must touch the real lake bed, not float at water_y-sink.
  var at:=Vector2(pose.origin.x,pose.origin.z);var support:=ground_height(field,at,h)
  var bottom:=INF
  for i in range(0,vertices.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(Vector3(at.x,h+.2,at.y),Vector3.DOWN,pose*vertices[i],pose*vertices[i+1],pose*vertices[i+2])
   if hit!=null:bottom=minf(bottom,hit.y)
  checked+=1
  if support==-INF or bottom==INF or bottom>support+.015:
   failures+=1;print('UNROOTED WET STONE ',kind,' ',pose.origin,' bottom=',bottom,' bed=',support)
func run()->void:
 var data:=Data.new();data.make_preset(0);var deco:=Deco.new();deco.load_assets()
 for state in ['default','dry','raise','contract']:
  data.make_preset(0)
  if OS.get_cmdline_user_args().has('unified'):data.set_sculpt_base(true)
  if OS.get_cmdline_user_args().has('shoulder'):load('res://tools/art/author_unified_cliff_cutstone.gd').full_island(data)
  if OS.get_cmdline_user_args().has('recess'):load('res://tools/art/author_unified_cliff_recess.gd').author(data)
  if state!='default':
   data.begin_stroke();data.apply_brush(Vector2(-3,0) if state=='dry' else Vector2(12,4),3.0,state,false,1.5,3);data.end_stroke()
  var field:=Field.new();field.refresh(data);deco.contours=field
  var chunks:Dictionary={};var count:=0;var before:=failures
  for cell in data.cells:chunks[Data.chunk_of(cell)]=true
  for chunk in chunks:
   var placed:Dictionary=deco.placements(data,chunk)
   for kind in ['shore_rock','shore_boulder','shore_pebble']:
    for pose:Transform3D in placed[kind]:inspect(field,deco,kind,pose);count+=1
  if count<20:failures+=1
  print('SHORE STONE CONTACT ',state,': stones=',count,' failures=',failures-before)
 print('SHORE STONE CONTACT: probes=',checked,' failures=',failures)
 quit(0 if failures==0 else 1)
