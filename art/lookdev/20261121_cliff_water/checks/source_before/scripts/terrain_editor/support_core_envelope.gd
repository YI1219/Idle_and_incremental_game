extends RefCounted
## Fit only the lower backing/closure to the retained source feet. One envelope
## per connected outline; upper shoulders, topology and authoring data stay put.
const VERSION:int=2
const FOOT_MARGIN:float=.7
const PROTECT_ABOVE_FOOT:float=.6

static func _component(p:Vector2,loops:Array)->int:
 var nearest:int=0
 var distance:float=INF
 var contained:int=-1
 var contained_area:float=INF
 for i:int in loops.size():
  var loop:PackedVector2Array=loops[i]
  if Geometry2D.is_point_in_polygon(p,loop):
   # A disjoint inner island may lie inside an outer ring's positive loop.
   # Choose the tightest containing body, independent of loop ordering.
   var area:float=0.0
   for j:int in loop.size():area+=loop[j].cross(loop[(j+1)%loop.size()])
   if absf(area)<contained_area:contained_area=absf(area);contained=i
  for j:int in loop.size():
   var q:Vector2=Geometry2D.get_closest_point_to_segment(p,loop[j],loop[(j+1)%loop.size()])
   var d:float=p.distance_squared_to(q)
   if d<distance:distance=d;nearest=i
 return contained if contained>=0 else nearest

static func apply(surface,columns:Array,assets:Dictionary,regions:Array=[])->Dictionary:
 var loops:Array=[]
 for loop:PackedVector2Array in regions:
  if not Geometry2D.is_polygon_clockwise(loop):loops.append(loop)
 var groups:Array[Dictionary]=[]
 for i:int in maxi(1,loops.size()):groups.append({'source_floor':INF,'old_floor':INF,'changed':0})
 for col:Dictionary in columns:
  var bounds:AABB=col.pose*(assets[col.kind][0].mesh as Mesh).get_aabb()
  var group:int=_component(col.edge,loops)
  groups[group].source_floor=minf(groups[group].source_floor,bounds.position.y)
 var memberships:PackedInt32Array=PackedInt32Array()
 var cache:Dictionary={}
 for p:Vector3 in surface.vertices:
  var xz:=Vector2(p.x,p.z)
  if not cache.has(xz):cache[xz]=_component(xz,loops)
  var group:int=cache[xz]
  memberships.append(group)
  groups[group].old_floor=minf(groups[group].old_floor,p.y)
 var changed:int=0
 for i:int in surface.vertices.size():
  var group:Dictionary=groups[memberships[i]]
  if not is_finite(group.source_floor):continue
  var floor_y:float=group.source_floor-FOOT_MARGIN
  var protected_y:float=group.source_floor+PROTECT_ABOVE_FOOT
  if floor_y<=group.old_floor+.001 or group.old_floor>=protected_y-.001:continue
  var p:Vector3=surface.vertices[i]
  if p.y>=protected_y:continue
  var t:float=clampf((protected_y-p.y)/(protected_y-group.old_floor),0.0,1.0)
  p.y=lerpf(protected_y,floor_y,t)
  surface.vertices[i]=p
  group.changed+=1;changed+=1
 return {'changed_vertices':changed,'groups':groups,'foot_margin':FOOT_MARGIN,'protected_above_foot':PROTECT_ABOVE_FOOT}
