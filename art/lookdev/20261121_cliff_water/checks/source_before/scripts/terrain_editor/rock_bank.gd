extends RefCounted
## Blend only the submerged continuation of a higher neighboring rock wall.
const VERSION:int=1
const REACH:float=.65
static func annotate(field,surface)->void:
 var edges:Dictionary={}
 for level:int in field.water_regions:
  edges[level]=[]
  for loop:PackedVector2Array in field.water_regions[level]:
   for i:int in loop.size():
    var a:=loop[i];var b:=loop[(i+1)%loop.size()]
    var out:=Vector2(b.y-a.y,a.x-b.x).normalized()
    var sample:Dictionary=field.surface_at((a+b)*.5+out*.30)
    if not sample.is_empty() and float(sample.height)>level*.5+.20:edges[level].append([a,b])
 for i:int in surface.vertices.size():
  var p:Vector3=surface.vertices[i];var level:int=roundi(surface.colors[i].r*255.0)
  var distance:float=INF;var at:=Vector2(p.x,p.z)
  for edge:Array in edges.get(level,[]):distance=minf(distance,at.distance_to(Geometry2D.get_closest_point_to_segment(at,edge[0],edge[1])))
  surface.colors[i].g=1.0-smoothstep(.0,REACH,distance)
