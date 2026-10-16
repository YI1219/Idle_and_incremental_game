extends RefCounted
## Unaccepted geometric study: continue real crown sections into the core.
## Source models and authored cells stay untouched. Not a runtime feature.
const NX:=11
const STEP:=.5
var profiles:Array=[]
var cache:Dictionary={}
var diagnostic:Array=[]

func front(faces:PackedVector3Array,origin:Vector3,out:Vector3)->float:
 var nearest:=INF
 for i in range(0,faces.size(),3):
  var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
  if origin.y<minf(a.y,minf(b.y,c.y))-.00001 or origin.y>maxf(a.y,maxf(b.y,c.y))+.00001:continue
  var hit=Geometry3D.ray_intersects_triangle(origin,-out,a,b,c)
  if hit!=null:nearest=minf(nearest,origin.distance_to(hit))
 return 12.0-nearest if nearest!=INF else NAN

func prepare(columns:Array,assets:Dictionary,core:PackedVector3Array)->void:
 for col:Dictionary in columns:
  var edge:Vector2=col.edge
  if edge.x< -22 or edge.x> -9 or edge.y< -2 or edge.y>8:continue
  var faces:=PackedVector3Array();var lo:=INF;var hi:=-INF
  var origin:=Vector3(edge.x,0,edge.y);var tangent:Vector3=col.tangent;var out:Vector3=col.outward
  for p:Vector3 in assets[col.kind][0].mesh.get_faces():
   var q:Vector3=col.pose*p;faces.append(q)
   var along:float=(q-origin).dot(tangent);lo=minf(lo,along);hi=maxf(hi,along)
  var nearby:=PackedVector3Array()
  for i in range(0,core.size(),3):
   var center:Vector3=(core[i]+core[i+1]+core[i+2])/3.0
   if Vector2(center.x,center.z).distance_to(edge)>8:continue
   for j in 3:nearby.append(core[i+j])
  var bottom:=-6.0;var top:float=col.pose.origin.y
  var ny:=ceili((top-bottom)/STEP)+1
  var old:=PackedFloat32Array();var target:=PackedFloat32Array();old.resize(NX*ny);target.resize(NX*ny)
  var valid_rows:Array[int]=[];var source_min:=INF;var source_max:=-INF;var slope_min:=INF;var slope_max:=-INF
  for ix in NX:
   var t:float=lerpf(lo,hi,float(ix)/(NX-1));var found:Array[int]=[]
   for iy in ny:
    var y:float=minf(top-.0001,bottom+iy*STEP)
    var ray:=origin+tangent*t+out*12.0+Vector3.UP*y
    var at:=ix*ny+iy
    old[at]=front(nearby,ray,out);target[at]=front(faces,ray,out)
    if not is_nan(target[at]):
     found.append(iy);source_min=minf(source_min,y);source_max=maxf(source_max,y)
   if found.is_empty():continue
   valid_rows.append(ix)
   var first:int=found[0];var last:int=found[-1]
   var slope:=.4
   if found.size()>1:slope=(target[ix*ny+found[1]]-target[ix*ny+first])/((found[1]-first)*STEP)
   slope=clampf(slope,.20,1.25);slope_min=minf(slope_min,slope);slope_max=maxf(slope_max,slope)
   for iy in ny:
    var at:=ix*ny+iy
    if is_nan(target[at]):
     if iy<first:target[at]=target[ix*ny+first]+slope*(iy-first)*STEP
     elif iy>last:target[at]=target[ix*ny+last]
     else:
      var closest:int=found[0]
      for j:int in found:
       if abs(j-iy)<abs(closest-iy):closest=j
      target[at]=target[ix*ny+closest]
    target[at]-=.055
   var old_valid:Array[int]=[]
   for iy in ny:
    if not is_nan(old[ix*ny+iy]):old_valid.append(iy)
   for iy in ny:
    if not is_nan(old[ix*ny+iy]):continue
    var closest:=-1
    for j:int in old_valid:
     if closest<0 or abs(j-iy)<abs(closest-iy):closest=j
    old[ix*ny+iy]=old[ix*ny+closest] if closest>=0 else target[ix*ny+iy]
  if valid_rows.is_empty():continue
  for ix in NX:
   if valid_rows.has(ix):continue
   var closest:int=valid_rows[0]
   for j:int in valid_rows:
    if abs(j-ix)<abs(closest-ix):closest=j
   for iy in ny:old[ix*ny+iy]=old[closest*ny+iy];target[ix*ny+iy]=target[closest*ny+iy]
  profiles.append({'origin':origin,'tangent':tangent,'out':out,'lo':lo,'hi':hi,'bottom':bottom,'top':top,'ny':ny,'old':old,'target':target})
  diagnostic.append({'edge':str(edge),'kind':col.kind,'source_low':source_min,'source_high':source_max,'return_slope_min':slope_min,'return_slope_max':slope_max,'tangent_min':lo,'tangent_max':hi})

func sample(grid:PackedFloat32Array,profile:Dictionary,tx:float,y:float)->float:
 var fx:float=clampf(tx*(NX-1),0,NX-1.00001);var ix:=floori(fx);fx-=ix
 var fy:float=clampf((y-profile.bottom)/STEP,0,profile.ny-1.00001);var iy:=floori(fy);fy-=iy
 return lerpf(lerpf(grid[ix*profile.ny+iy],grid[ix*profile.ny+iy+1],fy),lerpf(grid[(ix+1)*profile.ny+iy],grid[(ix+1)*profile.ny+iy+1],fy),fx)

func point(p:Vector3)->Vector3:
 if cache.has(p):return cache[p]
 var mask:float=smoothstep(-23,-20,p.x)*(1.0-smoothstep(-10,-8,p.x))*smoothstep(-2,0,p.z)*(1.0-smoothstep(9,11,p.z))
 if mask<=0:cache[p]=p;return p
 var shift:=Vector3.ZERO;var total:=0.0
 for profile:Dictionary in profiles:
  var relative:Vector3=p-profile.origin
  var t:float=relative.dot(profile.tangent)
  var tx:float=(t-profile.lo)/(profile.hi-profile.lo)
  if tx<0 or tx>1 or p.y>profile.top-.65:continue
  var old:float=sample(profile.old,profile,tx,p.y)
  var wanted:float=sample(profile.target,profile,tx,p.y)
  var distance:float=relative.dot(profile.out)
  var depth:float=maxf(0.0,old-distance)
  var weight:float=exp(-pow((tx-.5)*2.0,2)*3.0)*exp(-depth/1.6)*smoothstep(.65,1.7,profile.top-p.y)
  if absf(old-distance)>5.0:continue
  shift+=profile.out*clampf(wanted-old,-2.5,2.5)*weight;total+=weight
 var result:Vector3=p+shift/maxf(1.0,total)*mask
 cache[p]=result;return result

func apply(field,columns:Array,assets:Dictionary)->Dictionary:
 prepare(columns,assets,field.surfaces.cliff.vertices)
 var changed:=0;var maximum:=0.0;var degenerate:=0
 for kind in ['cliff','stone_mantle']:
  var surface=field.surfaces[kind]
  for i in surface.vertices.size():
   var old:Vector3=surface.vertices[i];var next:=point(old)
   if old.distance_squared_to(next)>1e-12:changed+=1
   maximum=maxf(maximum,old.distance_to(next));surface.vertices[i]=next
  for i in range(0,surface.vertices.size(),3):
   var normal:Vector3=-(surface.vertices[i+1]-surface.vertices[i]).cross(surface.vertices[i+2]-surface.vertices[i])
   if normal.length_squared()<1e-16:degenerate+=1
   normal=normal.normalized()
   for j in 3:surface.normals[i+j]=normal
  if kind=='cliff':
   var mesh:ArrayMesh=preload('res://scripts/terrain_editor/stone_normals.gd').soften(surface.mesh(),42.0,1.0)
   if mesh.get_surface_count()>0:surface.normals=mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
 field._index_triangles()
 return {'columns':diagnostic,'changed_vertices':changed,'maximum_shift':maximum,'degenerate_faces':degenerate,'stage':'Unaccepted actual-source geometric study; not production editing integration'}
