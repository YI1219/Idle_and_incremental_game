extends RefCounted
## Cosmetic surface detail assembled from the authoritative merged rim.
const Surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface

static func _hash(p:Vector2)->float:
 return fposmod(sin(p.dot(Vector2(127.1,311.7)))*43758.5453,1.0)

static func lip(regions:Dictionary,crowns:Array,assets:Dictionary):
 var result:=Surface.new()
 var faces:Dictionary={}
 for crown:Dictionary in crowns:
  var col:Dictionary=crown.column
  if not faces.has(crown.height):faces[crown.height]=PackedVector3Array()
  for p:Vector3 in assets[col.kind][0].mesh.get_faces():faces[crown.height].append(col.pose*p)
 for h:float in regions:
  for loop:PackedVector2Array in regions[h]:
   for e in loop.size():
    var a:=loop[e];var b:=loop[(e+1)%loop.size()];var length:=a.distance_to(b)
    if length<.12:continue
    var tangent:=(b-a)/length;var out:=Vector2(tangent.y,-tangent.x)
    var count:=maxi(1,floori(length/.45))
    for k in count:
     var center:=a.lerp(b,(k+.5)/count)
     var choice:=_hash(center*2.1+Vector2(h,7))
     var patch:=_hash((center*.60).floor()+Vector2(h,29))
     if patch<.56 or choice<.18:continue
     # Only crown-backed final boundary segments get flaps; skip water lips
     # and raw terrace joins. No orphan cards in the waterfall openings.
     var on_crown:=false
     for crown:Dictionary in crowns:
      if absf(crown.height-h)>.001:continue
      var poly:PackedVector2Array=crown.polygon
      for j in poly.size()-1:
       if center.distance_to(Geometry2D.get_closest_point_to_segment(center,poly[j],poly[j+1]))<.003:on_crown=true;break
      if on_crown:break
     if not on_crown:continue
     var width:=minf(length/count*.88,.30+.35*_hash(center+Vector2(4,2)))
     var depth:=.18+.38*pow(_hash(center+Vector2(19,3)),1.6)
     # Several overlapping rounded lobes form a thick turf cluster. The
     # rear lies against the stone; the proud ridge catches light and casts
     # a small contact shadow. This is not a face-colour spill or flat card.
     var left:=center-tangent*width*.5;var right:=center+tangent*width*.5
     var start:=result.vertices.size()
     var outward:=Vector3(out.x,0,out.y)
     for lobe in 3:
      var u:float=(lobe+.5)/3.0
      var c:=left.lerp(right,u)
      var w:=width*(.24+.08*_hash(c+Vector2(3,5)))
      var d:=depth*(.55+.45*_hash(c*7.0))
      var l:=c-tangent*w;var r:=c+tangent*w
      var top_l:=Vector3(l.x,h-.014,l.y)-outward*.025
      var top_r:=Vector3(r.x,h-.014,r.y)-outward*.025
      var shoulder_l=_drape(l,out,h-.07,faces[h])
      var shoulder_r=_drape(r,out,h-.06,faces[h])
      var tip_l=_drape(c-tangent*w*.44,out,h-d,faces[h])
      var tip_r=_drape(c+tangent*w*.36,out,h-d*.91,faces[h])
      if shoulder_l==null or shoulder_r==null or tip_l==null or tip_r==null:continue
      var outline:Array=[top_l,top_r,shoulder_r,tip_r,tip_l,shoulder_l]
      var ridge:Vector3=(top_l+top_r+tip_l+tip_r)*.25+outward*.075
      for j in outline.size():
       var va:Vector3=outline[j];var vb:Vector3=outline[(j+1)%outline.size()]
       result.triangle(va,vb,ridge,Color.WHITE)
       result.triangle(vb-outward*.025,va-outward*.025,ridge-outward*.075,Color.WHITE)
       result.quad(vb,va,va-outward*.025,vb-outward*.025,Color.WHITE)
     for i in range(start,result.vertices.size()):
      var p:Vector3=result.vertices[i]
      var along:=clampf((Vector2(p.x,p.z)-left).dot(tangent)/maxf(width,.001),0,1)
      var anchor:=left.lerp(right,along)
      result.colors[i]=Color(along,choice,1,1)
      result.uv2.append(anchor)
      result.uv[i]=Vector2(h,clampf((h-p.y)/depth,0,1))

 return result

static func _drape(p:Vector2,out:Vector2,y:float,faces:PackedVector3Array):
 var origin:=Vector3(p.x+out.x*1.0,y,p.y+out.y*1.0)
 var direction:=Vector3(-out.x,0,-out.y)
 var nearest:=INF;var point=null
 for i in range(0,faces.size(),3):
  var hit=Geometry3D.ray_intersects_triangle(origin,direction,faces[i],faces[i+1],faces[i+2])
  if hit==null:continue
  var distance:float=origin.distance_to(hit)
  var offset:=absf(distance-1.0)
  if offset<nearest and offset<.50:nearest=offset;point=hit-direction*.012
 return point

static func lawn(mesh:ArrayMesh,boundaries:Dictionary,wet:Dictionary={})->ArrayMesh:
 if mesh.get_surface_count()==0:return mesh
 var arrays:=mesh.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR];var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var result:=Surface.new();var cache:Dictionary={}
 for i in range(0,vertices.size(),3):
  if colors[i].a<.5:
   for j in 3:
    result.vertices.append(vertices[i+j]);result.normals.append(Vector3.UP);result.colors.append(colors[i+j]);result.uv.append(uv[i+j])
   continue
  # Shared world grid intersections avoid displaced T-junctions across slabs
  # and chunks. Original crown tops remain calm and exactly in place.
  var polys:Array=[[vertices[i],vertices[i+1],vertices[i+2]]]
  for axis in [0,2]:
   var lo:=minf(vertices[i][axis],minf(vertices[i+1][axis],vertices[i+2][axis]))
   var hi:=maxf(vertices[i][axis],maxf(vertices[i+1][axis],vertices[i+2][axis]))
   for row in range(floori(lo/.8)+1,ceili(hi/.8)):
    var next:Array=[]
    for poly:Array in polys:
     var sides:=[[],[]]
     for j in poly.size():
      var a:Vector3=poly[j];var b:Vector3=poly[(j+1)%poly.size()]
      var da:float=a[axis]-row*.8;var db:float=b[axis]-row*.8
      if da<=0:sides[0].append(a)
      if da>=0:sides[1].append(a)
      if da*db<0:
       var cross:=a.lerp(b,da/(da-db));sides[0].append(cross);sides[1].append(cross)
     for side:Array in sides:
      if side.size()>2:next.append(side)
    polys=next
  for poly:Array in polys:
   for j in range(1,poly.size()-1):
    var points:Array=[]
    for p:Vector3 in [poly[0],poly[j],poly[j+1]]:
     var key:=Vector3(snappedf(p.x,.00001),p.y,snappedf(p.z,.00001))
     if not cache.has(key):
      var distance:=INF;var q:=Vector2(p.x,p.z)
      for edge:PackedVector2Array in boundaries.get(p.y,[]):
       for n in edge.size():distance=minf(distance,q.distance_to(Geometry2D.get_closest_point_to_segment(q,edge[n],edge[(n+1)%edge.size()])))
      var submerged:=false
      for water_level:int in wet:
       if water_level*.5<p.y-.001:continue
       var winding:=0
       for edge:PackedVector2Array in wet[water_level]:
        for n in edge.size():distance=minf(distance,q.distance_to(Geometry2D.get_closest_point_to_segment(q,edge[n],edge[(n+1)%edge.size()])))
        if Geometry2D.is_point_in_polygon(q,edge):winding+=-1 if Geometry2D.is_polygon_clockwise(edge) else 1
       if winding>0:submerged=true
      if submerged:distance=0.0
      cache[key]=.055*sin(p.x*.8+p.z*.3)*sin(p.z*.62-p.x*.21)*smoothstep(.02,.85,distance)
     points.append(p+Vector3.UP*cache[key])
    result.triangle(points[0],points[1],points[2],colors[i],true)
 return result.mesh()
