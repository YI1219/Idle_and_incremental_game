extends SceneTree
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
const Field=preload('res://scripts/terrain_editor/contour_terrain.gd')
const Deco=preload('res://scripts/terrain_editor/terrain_decoration.gd')
func _initialize():call_deferred('run')
func section(col:Dictionary,mesh:Mesh)->PackedVector2Array:
 var points:=PackedVector2Array();var faces:=mesh.get_faces();var height:float=col.pose.origin.y-.45
 for i in range(0,faces.size(),3):
  for j in 3:
   var a:Vector3=col.pose*faces[i+j];var b:Vector3=col.pose*faces[i+(j+1)%3]
   if (a.y>height)==(b.y>height):continue
   var p:=a.lerp(b,(height-a.y)/(b.y-a.y));points.append(Vector2(p.x,p.z))
 return Geometry2D.convex_hull(points)
func run():
 var data:=Data.new();data.make_preset(0);var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco._column_layout(field,data.seed)
 var sections:Array=[]
 for col:Dictionary in deco._columns:sections.append(section(col,deco.assets[col.kind][0].mesh))
 var tight:=0;var gaps:=0;var pairs:=0;var widths:Array=[]
 for i in deco._columns.size()-1:
  var a:Dictionary=deco._columns[i];var b:Dictionary=deco._columns[i+1]
  if absf(a.pose.origin.y-b.pose.origin.y)>.01 or a.edge.distance_to(b.edge)>4.5 or a.outward.dot(b.outward)<.65:continue
  var first:PackedVector2Array=sections[i];var second:PackedVector2Array=sections[i+1]
  # Bodies overlap behind their visible fronts to remain one island mass.
  # Measure spacing in the outer half-metre, where crevices are actually seen.
  var out:=Vector2(a.outward.x+b.outward.x,a.outward.z+b.outward.z).normalized()
  var center:Vector2=(a.edge+b.edge)*.5
  first=front(first,center,out);second=front(second,center,out)
  if first.size()<3 or second.size()<3:continue
  var distance:=INF
  if not Geometry2D.intersect_polygons(first,second).is_empty():distance=0.0
  else:
   for p:Vector2 in first:
    for j in second.size()-1:distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,second[j],second[j+1])))
   for p:Vector2 in second:
    for j in first.size()-1:distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,first[j],first[j+1])))
  pairs+=1;widths.append(distance)
  if distance<.04:tight+=1
  elif distance>.10:gaps+=1
 var ok:=tight>=5 and gaps>=3
 print('RIM RHYTHM: section 0.45m below crowns; pairs=',pairs,' tight=',tight,' clear gaps=',gaps,' widths=',widths,' passed=',ok)
 quit(0 if ok else 1)

func front(polygon:PackedVector2Array,center:Vector2,out:Vector2)->PackedVector2Array:
 var result:=PackedVector2Array()
 for i in polygon.size()-1:
  var a:=polygon[i];var b:=polygon[i+1]
  var da:=(a-center).dot(out)-.45;var db:=(b-center).dot(out)-.45
  if da>=0:result.append(a)
  if (da<0 and db>0) or (da>0 and db<0):result.append(a.lerp(b,da/(da-db)))
 if not result.is_empty():result.append(result[0])
 return result
