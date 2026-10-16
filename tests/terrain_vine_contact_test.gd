extends SceneTree
## Finite support evidence for actual hanging module centroids. This does not
## prove every leaf vertex, visibility, connected vines or arbitrary layouts.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Contours=preload('res://scripts/terrain_editor/contour_terrain.gd')
const Decoration=preload('res://scripts/terrain_editor/terrain_decoration.gd')
func _initialize():call_deferred('run')
func wall_fixture(levels:Array)->RefCounted:
 var field=Contours.new()
 var surface=preload('res://scripts/terrain_editor/chunk_geometry.gd').Surface.new()
 for z:float in levels:surface.quad(Vector3(-1,-1,z),Vector3(-1,1,z),Vector3(1,1,z),Vector3(1,-1,z),Color.WHITE)
 field.surfaces={'cliff':surface};field._index_triangles();return field
func run():
 var data=Data.new();data.make_preset(0);var initial=data.serialize()
 var deco=Decoration.new();deco.load_assets()
 var center=Vector3.ZERO
 var vertices:PackedVector3Array=deco.assets.vine[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
 for point:Vector3 in vertices:center+=point
 center/=vertices.size()
 var reports=[];var failures=0
 # Both actual planes face +Z. The spray belongs next to the rear plane;
 # ranking hits from the outward ray origin would choose the front plane.
 var fixture_pose:=Transform3D(Basis.IDENTITY,Vector3(0,0,.03)-center)
 var attached:Dictionary=deco._drape_vine(wall_fixture([0.0,.4]),fixture_pose,Vector2.DOWN)
 var ownership_ok:bool=not attached.is_empty() and absf((attached.pose*center).z)<.10
 var rejected:Dictionary=deco._drape_vine(wall_fixture([-1.0]),fixture_pose,Vector2.DOWN)
 var bounded_ok:bool=rejected.is_empty()
 if not ownership_ok or not bounded_ok:failures+=1
 print('VINE WALL OWNERSHIP: closest=',ownership_ok,', bounded=',bounded_ok)
 for spec in [['default',Vector2.ZERO,0.0],['raise',Vector2(-13,2),2.3],['lower',Vector2(13,7),2.0],['expand',Vector2(18,4),2.6],['contract',Vector2(3,7),2.2]]:
  data.deserialize(initial)
  if spec[0]!='default':data.begin_stroke();data.apply_brush(spec[1],spec[2],spec[0],false,1.5,3);data.end_stroke()
  if OS.get_cmdline_user_args().has('unified'):data.set_sculpt_base(true)
  var field=Contours.new();field.refresh(data);deco.contours=field
  deco._column_layout(field,data.seed) # Prepare the final rim before snapshotting cliff arrays.
  var chunks={}
  for cell:Vector2i in data.cells:chunks[Data.chunk_of(cell)]=true
  var wall_kind:='sculpted_terrain' if data.sculpt_base_enabled else 'cliff'
  var faces:PackedVector3Array=field.surfaces[wall_kind].vertices
  var checked=0;var missing=0;var separated=0;var max_gap=0.0
  for chunk:Vector2i in chunks:
   for pose:Transform3D in deco.placements(data,chunk).vine:
    # Rim sprays have horizontal local Y; hanging sprays retain downward Y.
    if pose.basis.y.normalized().y<.2:continue
    var point:Vector3=pose*center
    var nearest=INF;var candidates={}
    for z in range(floori((point.z-.10)/8),floori((point.z+.10)/8)+1):
     for x in range(floori((point.x-.10)/8),floori((point.x+.10)/8)+1):
      for i:int in field.triangle_chunks.get(Vector2i(x,z),{}).get(wall_kind,[]):candidates[i]=true
    for i:int in candidates:
     var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
     var low:=a.min(b).min(c)-Vector3.ONE*.10;var high:=a.max(b).max(c)+Vector3.ONE*.10
     if point.x<low.x or point.x>high.x or point.y<low.y or point.y>high.y or point.z<low.z or point.z>high.z:continue
     var normal:Vector3=(b-a).cross(c-a).normalized()
     var distance:float=normal.dot(point-a)
     var projected:Vector3=point-normal*distance
     var weights:=Geometry3D.get_triangle_barycentric_coords(projected,a,b,c)
     if minf(weights.x,minf(weights.y,weights.z))>=-.000001:nearest=minf(nearest,absf(distance))
     else:
      for edge in [[a,b],[b,c],[c,a]]:nearest=minf(nearest,point.distance_to(Geometry3D.get_closest_point_to_segment(point,edge[0],edge[1])))
    # Since round 4, standing stone columns clad broad outer walls in front
    # of the recessed procedural rock. A spray hanging over a column is
    # supported by that column's actual mesh, so its triangles also count.
    var column_faces:PackedVector3Array=deco.column_faces_near(point)
    for i in range(0,column_faces.size(),3):
     var a:=column_faces[i];var b:=column_faces[i+1];var c:=column_faces[i+2]
     var normal:Vector3=(b-a).cross(c-a).normalized()
     var distance:float=normal.dot(point-a)
     var weights:=Geometry3D.get_triangle_barycentric_coords(point-normal*distance,a,b,c)
     if minf(weights.x,minf(weights.y,weights.z))>=-.000001:nearest=minf(nearest,absf(distance))
     else:
      for edge in [[a,b],[b,c],[c,a]]:nearest=minf(nearest,point.distance_to(Geometry3D.get_closest_point_to_segment(point,edge[0],edge[1])))
    checked+=1
    if nearest==INF:missing+=1;continue
    var gap:float=nearest;max_gap=maxf(max_gap,gap)
    if gap>.10:separated+=1
  # Density is an art choice; quiet clustered drapes intentionally emit far
  # fewer modules. Every emitted hanging centroid still must contact its
  # actual cliff, and every default/edit fixture must exercise that check.
  if checked==0 or missing>0 or separated>0:failures+=1
  reports.append({'fixture':spec[0],'checked_module_centroids':checked,'missing':missing,'separated_over_010':separated,'max_absolute_gap':max_gap})
 print('TERRAIN VINE CONTACT: ',JSON.stringify({'reports':reports,'failures':failures,'scope':'Actual mesh centroids and source cliff triangles, default/four edits; not every leaf vertex or arbitrary layout.'}))
 quit(1 if failures else 0)
