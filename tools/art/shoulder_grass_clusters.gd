extends RefCounted
## Tool-only source-leaf groups rooted in actual sloping stone shoulders.
const Surface=preload('res://scripts/terrain_editor/chunk_geometry.gd').Surface
static func hash2(p:Vector2)->float:return fposmod(sin(p.dot(Vector2(127.1,311.7)))*43758.5453,1.0)
static func supported(field,p:Vector2)->Dictionary:
 var ground:Dictionary=field.surface_at(p)
 if ground.is_empty() or ground.water>=0 or ground.height<3.12 or ground.height>3.501:return {}
 var heights:Array[float]=[]
 for d:Vector2 in [Vector2(.04,0),Vector2(-.04,0),Vector2(0,.04),Vector2(0,-.04)]:
  var at:Dictionary=field.surface_at(p+d)
  if at.is_empty() or at.water>=0:return {}
  heights.append(at.height)
 var normal:=Vector3(-(heights[0]-heights[1])/.08,1,-(heights[2]-heights[3])/.08).normalized()
 if normal.y<.60:return {}
 return {'height':ground.height,'normal':normal}
static func apply(field,assets:Dictionary)->Dictionary:
 var blades:=PackedVector3Array()
 for part:Dictionary in assets.get('grass',[]):
  for p:Vector3 in part.mesh.get_faces():blades.append(part.pose*p)
 assert(not blades.is_empty())
 var box:=AABB(blades[0],Vector3.ZERO)
 for p:Vector3 in blades:box=box.expand(p)
 var foot:=Vector3(box.get_center().x,box.position.y,box.get_center().z)
 var extra:=Surface.new();var clusters:=0;var fans:=0;var rooted:=0;var rejected:=0
 var anchors:Array=[];var centers:Array=[];var root_error:=0.0
 for ix in range(floori(-22/.34),ceili(-8/.34)):
  for iz in range(floori(-3/.34),ceili(9/.34)):
   var key:=Vector2(ix,iz);var choice:=hash2(key+Vector2(13,7))
   var at:Vector2=(key+Vector2(.15+.7*choice,.15+.7*hash2(key+Vector2(31,19))))*.34
   var patch:=hash2((at*.9).floor()+Vector2(3,17))
   if patch<.44 or choice<.20:continue
   var ground:=supported(field,at)
   if ground.is_empty() or ground.height>=3.49:continue
   # Require a nearby actual lawn cap; isolated high rocks stay bare.
   var lawn:=false;var lawn_at:=Vector2.ZERO
   for i in 8:
    var angle:=TAU*i/8.0
    var cap:Dictionary=field.surface_at(at+Vector2(cos(angle),sin(angle))*.42)
    if not cap.is_empty() and cap.water<0 and absf(cap.height-3.5)<.015:lawn=true;lawn_at=at+Vector2(cos(angle),sin(angle))*.42;break
   if not lawn:continue
   var accepted:=0
   for fan in 3:
    var theta:=choice*TAU+fan*2.3
    var p:=at+Vector2(cos(theta),sin(theta))*(.04+.035*fan)
    var support:=supported(field,p)
    if support.is_empty():continue
    var size:float=([.18,.13,.11][fan]+choice*.025)/box.size.y
    var basis:=Basis(Quaternion(Vector3.UP,support.normal))*Basis(Vector3.UP,theta)
    basis=basis.scaled(Vector3.ONE*size)
    var pose:=Transform3D(basis,Vector3(p.x,support.height-.014,p.y)-basis*foot)
    var vertices:=PackedVector3Array();var good:=true;var roots:=0;var error:=0.0
    for source:Vector3 in blades:
     var world:=pose*source
     if source.y-box.position.y<=box.size.y*.08:
      var hit:Dictionary=field.surface_at(Vector2(world.x,world.z))
      if hit.is_empty() or hit.water>=0 or absf(hit.height-support.height)>.18:good=false;break
      world.y=hit.height-.014+(source.y-box.position.y)*size
      error=maxf(error,absf(world.y-hit.height));roots+=1
     vertices.append(world)
    if not good:rejected+=1;continue
    var start:=extra.vertices.size()
    for i in range(0,vertices.size(),3):extra.triangle(vertices[i],vertices[i+1],vertices[i+2],Color.WHITE)
    for i in range(start,extra.vertices.size()):
     extra.colors[i]=Color(.5,choice,1,1);extra.uv[i]=Vector2(support.height,0);extra.uv2.append(p)
    fans+=1;accepted+=1;rooted+=roots;root_error=maxf(root_error,error)
    anchors.append({'x':p.x,'z':p.y,'height':support.height,'normal_y':support.normal.y})
   if accepted>0:
    clusters+=1;centers.append({'x':at.x,'z':at.y,'height':ground.height,'lawn_x':lawn_at.x,'lawn_z':lawn_at.y})
 field._smooth_normals(extra)
 var target=field.surfaces.rim_green;var previous:int=target.vertices.size()
 target.vertices.append_array(extra.vertices);target.normals.append_array(extra.normals);target.colors.append_array(extra.colors);target.uv.append_array(extra.uv);target.uv2.append_array(extra.uv2)
 field._index_triangles()
 return {'clusters':clusters,'fans':fans,'root_vertex_occurrences':rooted,'max_root_height_error':root_error,'rejected_fans':rejected,'old_vertex_occurrences':previous,'added_vertex_occurrences':extra.vertices.size(),'anchors':anchors,'cluster_centers':centers,'scope':'Tool-only sparse source-leaf clusters with centers on actual dry shoulderY3.12..3.49, supported normalY>=.60 and nearby lawn. Offset fan anchors can reachY3.501. Roots drape to authoritative skin. Existing rim prefix preserved; no ground-color/shape or source-asset changes. Not a persistent player/editor feature.'}
