extends RefCounted
## Tool-only connected low source-leaf canopies, no sod shell or paint band.
const Surface=preload('res://scripts/terrain_editor/chunk_geometry.gd').Surface
const Support=preload('res://tools/art/shoulder_grass_clusters.gd')
static func apply(field,assets:Dictionary)->Dictionary:
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://art/work/cliff_finish/2026-10-17/cluster_anchors.json'))
 var patches:Array=report.cluster_centers
 var blades:=PackedVector3Array()
 for part:Dictionary in assets.get('grass',[]):
  for p:Vector3 in part.mesh.get_faces():blades.append(part.pose*p)
 assert(not blades.is_empty())
 var box:=AABB(blades[0],Vector3.ZERO)
 for p:Vector3 in blades:box=box.expand(p)
 var foot:=Vector3(box.get_center().x,box.position.y,box.get_center().z)
 var extra:=Surface.new();var fans:=0;var roots:=0;var rejected:=0;var error:=0.0;var anchors:Array=[]
 for ix in range(floori(-22/.08),ceili(-8/.08)):
  for iz in range(floori(-3/.08),ceili(9/.08)):
   var key:=Vector2(ix,iz);var choice:=Support.hash2(key+Vector2(57,13))
   if choice<.16:continue
   var p:Vector2=(key+Vector2(.15+.7*choice,.15+.7*Support.hash2(key+Vector2(41,27))))*.08
   var best:=-INF
   for patch:Dictionary in patches:
    var a:=Vector2(patch.x,patch.z);var b:=Vector2(patch.lawn_x,patch.lawn_z)
    var closest:=Geometry2D.get_closest_point_to_segment(p,a,b)
    var radius:float=.18+.06*Support.hash2(a+Vector2(7,23))
    var fray:float=(Support.hash2((p*21).floor())-.5)*.08
    best=maxf(best,radius-p.distance_to(closest)+fray)
   if best<=0:continue
   var support:=Support.supported(field,p)
   if support.is_empty():continue
   var height:=.065+.055*choice
   var size:float=height/box.size.y
   var basis:=Basis(Quaternion(Vector3.UP,support.normal))*Basis(Vector3.UP,choice*TAU)
   basis=basis.scaled(Vector3.ONE*size)
   var pose:=Transform3D(basis,Vector3(p.x,support.height-.014,p.y)-basis*foot)
   var vertices:=PackedVector3Array();var valid:=true;var root_count:=0;var local_error:=0.0
   for source:Vector3 in blades:
    var world:=pose*source
    if source.y-box.position.y<=box.size.y*.08:
     var hit:Dictionary=field.surface_at(Vector2(world.x,world.z))
     if hit.is_empty() or hit.water>=0 or absf(hit.height-support.height)>.12:valid=false;break
     world.y=hit.height-.014+(source.y-box.position.y)*size
     local_error=maxf(local_error,absf(world.y-hit.height));root_count+=1
    vertices.append(world)
   if not valid:rejected+=1;continue
   var start:=extra.vertices.size()
   # Terrain-sized area cutoffs erase valid leaves at this uniform scale.
   for i in range(0,vertices.size(),3):
    var cross:Vector3=-(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
    assert(cross.length_squared()>1e-18,'Original source leaf must retain a finite area')
    for j in 3:
     extra.vertices.append(vertices[i+j]);extra.normals.append(cross.normalized());extra.colors.append(Color.WHITE);extra.uv.append(Vector2.ZERO)
   for i in range(start,extra.vertices.size()):
    extra.colors[i]=Color(.5,choice,1,1);extra.uv[i]=Vector2(support.height,0);extra.uv2.append(p)
   fans+=1;roots+=root_count;error=maxf(error,local_error)
   anchors.append({'x':p.x,'z':p.y,'height':support.height,'normal_y':support.normal.y,'blade_height':height})
 field._smooth_normals(extra)
 var target=field.surfaces.rim_green;var previous:int=target.vertices.size()
 assert(extra.vertices.size()==fans*blades.size())
 return {'_canopy_surface':extra,'source_fan_vertex_occurrences':blades.size(),'patches':patches.size(),'fans':fans,'anchors':anchors,'root_vertex_occurrences':roots,'max_root_height_error':error,'rejected_fans':rejected,'old_vertex_occurrences':previous,'added_vertex_occurrences':extra.vertices.size(),'all_source_leaf_triangles_preserved':true,'scope':'Tool-only low source-leaf canopy groups between actual lawn and supported shoulders, heights.065..12m, frayed source-root distribution. All sampled low roots drape to authoritative skin. Separately uploaded with existing rim material to avoid terrain-sized triangle-area culling. No terrain fill, cuff shell, painted side-color or source-asset change. Not persistent editor behavior or performance acceptance.'}
