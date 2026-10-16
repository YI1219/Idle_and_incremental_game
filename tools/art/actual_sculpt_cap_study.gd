extends RefCounted
## Tool-only visible-cap coverage experiment. No independent decorative land.
static func apply(field,assets:Dictionary,source_fans:bool=false)->Dictionary:
 var surface=field.surfaces.sculpted_terrain
 var edges:Dictionary={};var directed:Dictionary={};var painted:=0
 var h:=3.5
 for i in range(0,surface.vertices.size(),3):
  var a:Vector3=surface.vertices[i];var b:Vector3=surface.vertices[i+1];var c:Vector3=surface.vertices[i+2]
  if maxf(absf(a.y-h),maxf(absf(b.y-h),absf(c.y-h)))>.002:continue
  if -(b-a).cross(c-a).normalized().y<.999:continue
  if surface.uv[i].y>=0:continue
  for j in 3:
   var color:Color=surface.colors[i+j];color.r=1.0;color.g=1.0
   surface.colors[i+j]=color;surface.uv[i+j]=Vector2(h,-1)
   painted+=1
 # Intersect the whole skin just below the cap. Selecting only flat faces
 # creates artificial tiny loops around shallow lattice triangles.
 var section:=h-.0365083
 for i in range(0,surface.vertices.size(),3):
  var points:Array[Vector3]=[surface.vertices[i],surface.vertices[i+1],surface.vertices[i+2]]
  var hits:Array[Vector2i]=[]
  for j in 3:
   var p:Vector3=points[j];var q:Vector3=points[(j+1)%3]
   if (p.y-section)*(q.y-section)>=0:continue
   var hit:=p.lerp(q,(section-p.y)/(q.y-p.y))
   var key:=Vector2i(roundi(hit.x*10000),roundi(hit.z*10000))
   if not hits.has(key):hits.append(key)
  if hits.size()!=2:continue
  var start:Vector2i=hits[0];var end:Vector2i=hits[1]
  var normal:=-(points[1]-points[0]).cross(points[2]-points[0])
  if Vector2(end-start).dot(Vector2(-normal.z,normal.x))<0:
   var swap:=start;start=end;end=swap
  var key:Array=[start,end] if start<end else [end,start]
  edges[key]=edges.get(key,0)+1;directed[key]=[start,end]
 var next:Dictionary={};var branches:=0
 for key:Array in edges:
  if edges[key]!=1:continue
  var pair:Array=directed[key]
  if not next.has(pair[0]):next[pair[0]]=[]
  next[pair[0]].append(pair[1])
 for values:Array in next.values():
  if values.size()!=1:branches+=1
 assert(branches==0,'Flat cap boundary must have no ambiguous junction')
 var loops:Array=[];var open:=0
 while not next.is_empty():
  var start:Vector2i=next.keys()[0];var current:=start;var loop:=PackedVector2Array()
  var budget:int=next.size()+1
  while budget>0:
   budget-=1;loop.append(Vector2(current)/10000.0)
   if not next.has(current):open+=1;break
   var end:Vector2i=next[current][0];next.erase(current);current=end
   if current==start:break
  if current!=start:open+=1;continue
  var clean:=PackedVector2Array()
  for i in loop.size():
   var before:Vector2=loop[(i+loop.size()-1)%loop.size()];var at:Vector2=loop[i];var after:Vector2=loop[(i+1)%loop.size()]
   if absf((at-before).cross(after-at))<.000001:continue
   clean.append(at)
  if clean.size()>=3:loops.append(clean)
 assert(open==0 and not loops.is_empty(),'Actual flat cap must yield closed contours')
 field._index_triangles()
 var original:Dictionary=field.land_regions
 var regions:Dictionary=original.duplicate(true);regions[h]=loops
 field.land_regions=regions
 var lip=preload('res://scripts/terrain_editor/rim_surface_detail.gd').sculpt_lip(field,assets)
 if source_fans:
  var crowns:Array=[]
  for loop:PackedVector2Array in loops:
   var polygon:=loop.duplicate();polygon.append(loop[0])
   crowns.append({'polygon':polygon,'height':h})
  var fans=preload('res://scripts/terrain_editor/rim_surface_detail.gd').lip({h:loops},crowns,assets)
  lip=preload('res://scripts/terrain_editor/chunk_geometry.gd').Surface.new()
  var support:Dictionary={}
  for i in range(0,fans.vertices.size(),3):
   var at:Vector2=fans.uv2[i]
   if not support.has(at):
    var ground:Dictionary=field.surface_at(at)
    support[at]=not ground.is_empty() and ground.water<0 and absf(ground.height-h)<.12
   if not support[at]:continue
   for j in 3:
    lip.vertices.append(fans.vertices[i+j]);lip.normals.append(fans.normals[i+j]);lip.colors.append(fans.colors[i+j]);lip.uv.append(fans.uv[i+j]);lip.uv2.append(fans.uv2[i+j])
 field.land_regions=original
 field.surfaces.rim_green=lip;field._smooth_normals(lip);field._index_triangles()
 var anchors:Dictionary={};var unsupported:=0
 for at:Vector2 in lip.uv2:anchors[at]=true
 for at:Vector2 in anchors:
  var ground:Dictionary=field.surface_at(at)
  if ground.is_empty() or ground.water>=0:unsupported+=1
 return {'painted_flat_cap_vertex_occurrences':painted,'section_y':section,'source_fans':source_fans,'loops':loops.size(),'open_boundaries':open,'ambiguous_junctions':branches,'grass_anchor_count':anchors.size(),'unsupported_anchor_samples':unsupported,'stage':'Tool-only actual-skin cap color and rooted original-grass contour. No new ground geometry, runtime regeneration/picking or full leaf support acceptance.'}
