extends SceneTree
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Field=preload('res://scripts/terrain_editor/contour_terrain.gd')
const Deco=preload('res://scripts/terrain_editor/terrain_decoration.gd')
func _initialize():call_deferred('run')
func run():
 var data:=Data.new();data.make_preset(0)
 var results:=[];var ok:=true
 for state in ['default','expand','contract']:
  if state=='expand':
   data.begin_stroke();data.apply_brush(Vector2(19.2,4.6),2.8,'expand',false,1.5,3);data.end_stroke()
  elif state=='contract':
   data.undo();data.begin_stroke();data.apply_brush(Vector2(18.6,4.4),2.2,'contract',false,1.5,3);data.end_stroke()
  var result:=probe(data);result.state=state;results.append(result)
  ok=ok and result.misses.is_empty()
 print('RIM CLOSURE: ',JSON.stringify(results))
 quit(0 if ok else 1)
func probe(data:Data)->Dictionary:
 var field:=Field.new();field.refresh(data);var deco:=Deco.new();deco.load_assets();deco._column_layout(field,data.seed)
 var faces:PackedVector3Array=field.surfaces.cliff.vertices.duplicate()
 for col:Dictionary in deco._columns+deco._mass:
  for p:Vector3 in deco.assets[col.kind][0].mesh.get_faces():faces.append(col.pose*p)
 var buckets:Dictionary={}
 for i in range(0,faces.size(),3):
  var box:=AABB(faces[i],Vector3.ZERO).expand(faces[i+1]).expand(faces[i+2])
  for z in range(floori(box.position.z),floori(box.end.z)+1):
   for x in range(floori(box.position.x),floori(box.end.x)+1):
    var key:=Vector2i(x,z)
    if not buckets.has(key):buckets[key]=[]
    buckets[key].append(i)
 var misses:=[];var count:=0;var worst:=0.0
 for h:float in field.rim_regions:
  for loop:PackedVector2Array in field.rim_regions[h]:
   for e in loop.size():
    var a:=loop[e];var b:=loop[(e+1)%loop.size()]
    if a.distance_to(b)<.03:continue
    var dir:=(b-a).normalized();var out:=Vector3(dir.y,0,-dir.x)
    for t:float in [.25,.5,.75]:
     var p:=a.lerp(b,t);var near:=INF
     for c:Dictionary in deco._columns:
      if absf(c.pose.origin.y-h)<.001:near=minf(near,p.distance_to(c.edge))
     if near>1.5:continue
     var candidates:Dictionary={}
     for z in range(floori(p.y)-2,floori(p.y)+3):
      for x in range(floori(p.x)-2,floori(p.x)+3):
       for i:int in buckets.get(Vector2i(x,z),[]):candidates[i]=true
     for drop:float in [.08,.25,.55]:
      var origin:=Vector3(p.x,h-drop,p.y)+out*.05
      var distance:=INF
      for i:int in candidates:
       var hit=Geometry3D.ray_intersects_triangle(origin,-out,faces[i],faces[i+1],faces[i+2])
       if hit!=null:distance=minf(distance,origin.distance_to(hit))
      # Up to half the maximum 4.8m crown span allows deep concave joints,
      # but not an unbacked ray reaching the far side of the island.
      count+=1;worst=maxf(worst,distance)
      if distance>2.5:misses.append([str(p),h,drop,distance])
 return {"probes":count,"maximum_recess_m":worst,"misses":misses}
