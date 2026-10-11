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
 var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://art/review/terrain_fidelity/2026-10-11/rocks_step4/baseline_geometry.json'))
 var same:=true
 for h:float in field.rim_regions:
  var actual:Array=[]
  for poly:PackedVector2Array in field.rim_regions[h]:
   var points:Array=[]
   for p:Vector2 in poly:points.append([p.x,p.y])
   actual.append(points)
  same=same and JSON.stringify(actual)==JSON.stringify(baseline.regions[str(h)])
 if not same:failures+=1;push_error('Step 3 crown outline changed')
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
 # This exact ray hits the detached old-shoulder chip in the Step 3 side view.
 var origin:=Vector3(24,2.2,14)
 var target:=Vector3(-1.622011,3.198752,7.829043)
 var ray:=(target-origin).normalized()
 var chip:=false
 var faces:PackedVector3Array=field.surfaces.cliff.vertices
 for i in range(0,faces.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(origin,ray,faces[i],faces[i+1],faces[i+2])
  if hit!=null and hit.distance_to(target)<.06:chip=true
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
 print('RIM FINISH: footprint identical=',same,'; ',samples,' lawn probes; leaks=',leaks,'; orphan chip=',chip,'; ',cap_probes.size(),' cap probes; holes=',cap_holes,'; failures=',failures)
 quit(1 if failures else 0)
