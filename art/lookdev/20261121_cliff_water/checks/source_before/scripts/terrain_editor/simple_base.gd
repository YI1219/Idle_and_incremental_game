extends RefCounted
## Calm lower silhouette: one inward side plane and an authoritative flat floor.
const VERSION:int=2
const FLOOR:float=-2.6
static func floor_for(data)->float:
 var floor_y:float=FLOOR
 for cell:Vector2i in data.cells:floor_y=minf(floor_y,float(data.cells[cell].height)-.6)
 return floor_y
static func point(p:Vector2,normal:Vector2,profile:Dictionary,original:Vector3,old_floor:float,new_floor:float,inset_scale:float=1.0)->Vector3:
 var crown_depth:float=minf(.65,maxf(.05,(profile.top-old_floor)*.25))
 var anchor:float=profile.top-crown_depth
 if original.y>=anchor:return original
 var t:float=clampf((anchor-original.y)/maxf(.001,anchor-old_floor),0,1)
 var inset:float=minf(2.1,profile.inset*.75)*lerpf(.12,1.0,t)*inset_scale
 var target:=Vector2(p.x,p.y)-normal*inset
 var blend:float=smoothstep(0.0,.35,t)
 return Vector3(lerpf(original.x,target.x,blend),lerpf(anchor,new_floor,t),lerpf(original.z,target.y,blend))

static func simple_foot(surface,floor_y:float)->bool:
 # Validate the actual sampled foot, including narrow/wide transitions.
 # A self-crossing inset is not a valid cap boundary, even if the top is fine.
 var counts:Dictionary={};var points:Dictionary={}
 for i:int in range(0,surface.vertices.size(),3):
  for j:int in 3:
   var a:Vector3=surface.vertices[i+j];var b:Vector3=surface.vertices[i+(j+1)%3]
   if absf(a.y-floor_y)>.00001 or absf(b.y-floor_y)>.00001:continue
   var ka:=Vector2i((Vector2(a.x,a.z)*10000).round());var kb:=Vector2i((Vector2(b.x,b.z)*10000).round())
   if ka==kb:continue
   var key:Array=[ka,kb] if ka<kb else [kb,ka]
   counts[key]=counts.get(key,0)+1;points[ka]=Vector2(a.x,a.z);points[kb]=Vector2(b.x,b.z)
 var edges:Array=[];var degrees:Dictionary={}
 for key:Array in counts:
  if counts[key]!=1:continue
  edges.append(key)
  for k:Vector2i in key:degrees[k]=degrees.get(k,0)+1
 for degree:int in degrees.values():
  if degree!=2:return false
 for i:int in edges.size():
  var a:Vector2=points[edges[i][0]];var b:Vector2=points[edges[i][1]]
  for j:int in range(i+1,edges.size()):
   if edges[i][0] in edges[j] or edges[i][1] in edges[j]:continue
   var c:Vector2=points[edges[j][0]];var d:Vector2=points[edges[j][1]]
   if maxf(a.x,b.x)<minf(c.x,d.x) or maxf(c.x,d.x)<minf(a.x,b.x) or maxf(a.y,b.y)<minf(c.y,d.y) or maxf(c.y,d.y)<minf(a.y,b.y):continue
   if Geometry2D.segment_intersects_segment(a,b,c,d)!=null:return false
   # Parallel overlapping boundaries also invalidate a narrow neck.
   for pair:Array in [[a,c,d],[b,c,d],[c,a,b],[d,a,b]]:
    if pair[0].distance_squared_to(Geometry2D.get_closest_point_to_segment(pair[0],pair[1],pair[2]))<1e-10:return false
 return not edges.is_empty()
