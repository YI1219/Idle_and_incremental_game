extends SceneTree
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Field=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Deco=preload("res://scripts/terrain_editor/terrain_decoration.gd")
func _initialize():call_deferred("run")
func run():
 var data:=Data.new();data.make_preset(0);var field:=Field.new();field.refresh(data)
 var deco:=Deco.new();deco.load_assets();deco._column_layout(field,data.seed)
 var cover=field.surfaces.rim_green;var raised:=0;var unsupported:=0;var invalid:=0;var roots:Dictionary={}
 for i in cover.vertices.size():
  var p:Vector3=cover.vertices[i];var h:float=cover.uv[i].x;var anchor:Vector2=cover.uv2[i]
  if p.y>h+.08:raised+=1
  if p.y>h+.30 or not p.is_finite() or not cover.normals[i].is_finite() or absf(cover.normals[i].length()-1.0)>.002:invalid+=1
  roots[Vector3(anchor.x,h,anchor.y)]=true
 for root:Vector3 in roots:
  if not field.contains(field.rim_regions[root.y],Vector2(root.x,root.z)):
   unsupported+=1;print('UNSUPPORTED TUFT ROOT: ',root)
 var uploaded:=0
 for chunk:Vector2i in field.triangle_chunks:
  var mesh:Mesh=field.build(chunk).rim_green
  if mesh.get_surface_count()==0:continue
  var arrays:Array=mesh.surface_get_arrays(0)
  var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  var anchors:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
  if anchors.size()!=positions.size() or normals.size()!=positions.size():invalid+=1;continue
  for i in positions.size():
   uploaded+=1
   if not positions[i].is_finite() or not normals[i].is_finite() or absf(normals[i].length()-1.0)>.002 or not anchors[i].is_finite():invalid+=1
 var ok:bool=uploaded>0 and raised>100 and unsupported==0 and invalid==0
 print("RIM TUFT: raised blade vertices=",raised," uploaded=",uploaded," triangles=",cover.vertices.size()/3," roots=",roots.size()," unsupported=",unsupported," invalid=",invalid," passed=",ok)
 quit(0 if ok else 1)
