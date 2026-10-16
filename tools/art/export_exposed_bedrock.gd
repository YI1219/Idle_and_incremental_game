extends SceneTree
## Existing complete source shoulders in the actual default crown transforms.
## Tool-only experiment: no new model, source overwrite or runtime assembly.
const OUT='res://art/work/exposed_bedrock/2026-10-17/'
const LO=Vector3i(-88,-24,-12)
const HI=Vector3i(-32,24,36)
func _initialize():call_deferred('run')
func packed(p:Vector3)->Array:return [p.x,p.y,p.z]
func run():
 DirAccess.make_dir_recursive_absolute(OUT)
 var data=preload('res://scripts/terrain_editor/terrain_data.gd').new();data.make_preset(0)
 var field=preload('res://scripts/terrain_editor/contour_terrain.gd').new();field.refresh(data)
 var deco=preload('res://scripts/terrain_editor/terrain_decoration.gd').new();deco.load_assets();deco._column_layout(field,data.seed)
 var specs:Dictionary={'cliff_column':['cliff_integrated_tall_v1.glb','cliff_tall_v2.glb',.72], 'cliff_column_b':['cliff_integrated_main_v1.glb','cliff_main_v4.glb',.72], 'cliff_column_c':['cliff_integrated_tall_v1.glb','cliff_tall_v2.glb',.86]}
 var crowns:Array=[]
 for col:Dictionary in deco._columns:
  var edge:Vector2=col.edge
  if edge.x< -18.8 or edge.x> -11.0 or edge.y<1 or edge.y>6:continue
  var spec:Array=specs[col.kind];var library=deco.model_library
  var whole:Dictionary=library._merge(library._load('res://assets/nature/refined/'+spec[0],'cliff_rock'))
  var reference:Dictionary=library._merge(library._load('res://assets/nature/refined/'+spec[1],'cliff_rock'))
  var box:AABB=reference.mesh.get_aabb();var cut:float=box.position.y+box.size.y*spec[2]
  var cap_lo:=Vector2(INF,INF);var cap_hi:=-cap_lo;var faces:PackedVector3Array=whole.mesh.get_faces()
  for i in range(0,faces.size(),3):
   for j in 3:
    var a:=faces[i+j];var b:=faces[i+(j+1)%3]
    if (a.y<cut and b.y>cut) or (a.y>cut and b.y<cut):
     var q:=a.lerp(b,(cut-a.y)/(b.y-a.y));cap_lo=cap_lo.min(Vector2(q.x,q.z));cap_hi=cap_hi.max(Vector2(q.x,q.z))
  var size:=cap_hi-cap_lo;var center:=Vector3((cap_lo.x+cap_hi.x)*.5,cut,(cap_lo.y+cap_hi.y)*.5)
  var scale3:=Vector3(1.0/size.x,.68/(cut-box.position.y),1.0/size.y)
  var vertices:Array=[];var above:=0
  for p:Vector3 in faces:
   var world:Vector3=col.pose*((p-center)*scale3);vertices.append(packed(world))
   if world.y>col.pose.origin.y+.01:above+=1
  crowns.append({'kind':col.kind,'cap_height':col.pose.origin.y,'outward':packed(col.outward),'edge':[edge.x,edge.y],'world_faces':vertices,'above_cap_vertex_occurrences':above,'source':spec[0]})
 data.set_sculpt_base(true);data.ensure_sculpt_base();var base=data.rocks.base
 var nodes:=PackedFloat32Array();var columns:=PackedFloat32Array()
 for z in range(LO.z,HI.z+1):
  for x in range(LO.x,HI.x+1):
   var p:=Vector2(x,z)*.25;columns.append(base._body_height(p))
   for h:float in base.levels:columns.append(base._distance(base.regions[h],p))
  for y in range(LO.y,HI.y+1):
   for x in range(LO.x,HI.x+1):nodes.append(base.node_value(Vector3i(x,y,z)))
 FileAccess.open(OUT+'base_nodes.bin',FileAccess.WRITE).store_buffer(nodes.to_byte_array())
 FileAccess.open(OUT+'base_columns.bin',FileAccess.WRITE).store_buffer(columns.to_byte_array())
 FileAccess.open(OUT+'base_save.json',FileAccess.WRITE).store_string(JSON.stringify(data.serialize()))
 FileAccess.open(OUT+'source.json',FileAccess.WRITE).store_string(JSON.stringify({'crowns':crowns,'lo':[LO.x,LO.y,LO.z],'hi':[HI.x,HI.y,HI.z],'levels':base.levels,'step':.25,'axis_order':'nodes=z,y,x; columns=z,x,height+level_distances','stage':'Unaccepted whole-source exposure in ordinary editable density; sources and original cap normalization retained.'}))
 print('EXPOSED BEDROCK EXPORT: crowns=',crowns.size(),' nodes=',nodes.size());quit()
