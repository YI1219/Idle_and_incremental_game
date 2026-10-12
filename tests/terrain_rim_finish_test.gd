extends SceneTree
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Field=preload('res://scripts/terrain_editor/contour_terrain.gd')
const Deco=preload('res://scripts/terrain_editor/terrain_decoration.gd')
var failures:=0
func _initialize():call_deferred('run')
func distance_to_edge(p:Vector2,regions:Array)->float:
 var distance:=INF
 for poly:PackedVector2Array in regions:
  for j in poly.size():distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,poly[j],poly[(j+1)%poly.size()])))
 return distance
func run():
 var data:=Data.new();data.make_preset(0)
 var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco._column_layout(field,data.seed)
 # Shape is art-directed; validate that regenerated regions are finite closed
 # polygons instead of pinning the old straight-wall crown coordinates.
 var same:=true
 for h:float in field.rim_regions:
  for poly:PackedVector2Array in field.rim_regions[h]:
   same=same and poly.size()>=3
   for p:Vector2 in poly:same=same and p.is_finite()
 if not same:failures+=1;push_error('Invalid crown outline')
 var leaks:=0;var samples:=0
 var grass=field.surfaces.grass
 for i in range(0,grass.vertices.size(),3):
  if grass.colors[i].a>.5:continue
  for weight:Vector3 in [Vector3.ONE/3.0,Vector3(.6,.2,.2),Vector3(.2,.6,.2),Vector3(.2,.2,.6)]:
   var p:Vector3=grass.vertices[i]*weight.x+grass.vertices[i+1]*weight.y+grass.vertices[i+2]*weight.z
   var uv:Vector2=grass.uv[i]*weight.x+grass.uv[i+1]*weight.y+grass.uv[i+2]*weight.z
   samples+=1
   if uv.x<.28 and uv.y>0 and distance_to_edge(Vector2(p.x,p.z),field.rim_regions[grass.vertices[i].y])>.40:leaks+=1
 if leaks:failures+=1;push_error('Stone tint reaches interior lawn: %d probes'%leaks)
 # The historical chip ray is still useful, but a legitimate newly shaped
 # wall can cross it. A hit is orphaned only if its connected component is
 # a tiny fragment, rather than part of the continuous supporting envelope.
 var origin:=Vector3(24,2.2,14)
 var target:=Vector3(-1.622011,3.198752,7.829043)
 var ray:=(target-origin).normalized()
 var chip:=false
 var faces:PackedVector3Array=field.surfaces.cliff.vertices
 var adjacency:Dictionary={};var hit_triangle:=-1
 for i in range(0,faces.size(),3):
  for j in 3:
   var key:=Vector3i((faces[i+j]*10000).round())
   if not adjacency.has(key):adjacency[key]=[]
   adjacency[key].append(i)
  var hit=Geometry3D.ray_intersects_triangle(origin,ray,faces[i],faces[i+1],faces[i+2])
  if hit!=null and hit.distance_to(target)<.06:hit_triangle=i
 if hit_triangle>=0:
  var queue:Array=[hit_triangle];var seen:Dictionary={};var component_area:=0.0
  while not queue.is_empty():
   var i:int=queue.pop_back()
   if seen.has(i):continue
   seen[i]=true
   component_area+=(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length()*.5
   for j in 3:
    for neighbor:int in adjacency[Vector3i((faces[i+j]*10000).round())]:
     if not seen.has(neighbor):queue.append(neighbor)
  chip=component_area<.5
  print('Historical shoulder ray component area=',component_area)
 if chip:failures+=1;push_error('Detached upper shoulder chip is still visible')
 var cap_holes:=0
 # Overlapping crown holes crossed between scanline rows in Step 3, leaving
 # a small triangular opening at this interior lawn location.
 var cap_probes:Array[Vector2]=[Vector2(14.69095,6.826356),Vector2(14.65258,6.820057)]
 for z in 17:
  for x in 17:cap_probes.append(Vector2(14.50+x*.02,6.65+z*.02))
 for p:Vector2 in cap_probes:
  var covered:=false
  for i in range(0,grass.vertices.size(),3):
   if Geometry3D.ray_intersects_triangle(Vector3(p.x,1.9,p.y),Vector3.DOWN,grass.vertices[i],grass.vertices[i+1],grass.vertices[i+2])!=null:covered=true;break
  if not covered:cap_holes+=1
 if cap_holes:failures+=1;push_error('Lawn cap has triangular overlap holes: %d'%cap_holes)
 print('RIM FINISH: valid footprint=',same,'; ',samples,' lawn probes; leaks=',leaks,'; orphan chip=',chip,'; ',cap_probes.size(),' cap probes; holes=',cap_holes,'; failures=',failures)
 quit(1 if failures else 0)
