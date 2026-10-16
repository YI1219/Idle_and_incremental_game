extends SceneTree
## Export actual retained crown solids and an ordinary editable base for a
## bounded three-dimensional union study. No production asset replacement.
const OUT='res://art/work/cliff_volume/2026-10-16/'
const LO=Vector3i(-80,-24,0)
const HI=Vector3i(-40,18,32)
func _initialize():call_deferred('run')
func packed(p:Vector3)->Array:return [p.x,p.y,p.z]
func run():
 DirAccess.make_dir_recursive_absolute(OUT)
 var data=preload('res://scripts/terrain_editor/terrain_data.gd').new();data.make_preset(0)
 var field=preload('res://scripts/terrain_editor/contour_terrain.gd').new();field.refresh(data)
 var deco=preload('res://scripts/terrain_editor/terrain_decoration.gd').new();deco.load_assets();deco._column_layout(field,data.seed)
 var crowns:Array=[]
 for col:Dictionary in deco._columns:
  var edge:Vector2=col.edge
  if edge.x< -18.8 or edge.x> -11.0 or edge.y<1 or edge.y>6:continue
  var vertices:Array=[]
  for p:Vector3 in deco.assets[col.kind][0].mesh.get_faces():vertices.append(packed(col.pose*p))
  crowns.append({'kind':col.kind,'cap_height':col.pose.origin.y,'outward':packed(col.outward),'edge':[edge.x,edge.y],'world_faces':vertices})
 data.set_sculpt_base(true);data.ensure_sculpt_base()
 var base=data.rocks.base
 var nodes:=PackedFloat32Array();var columns:=PackedFloat32Array()
 for z in range(LO.z,HI.z+1):
  for x in range(LO.x,HI.x+1):
   var p:=Vector2(x,z)*.25
   columns.append(base._body_height(p))
   for h:float in base.levels:columns.append(base._distance(base.regions[h],p))
  for y in range(LO.y,HI.y+1):
   for x in range(LO.x,HI.x+1):nodes.append(base.node_value(Vector3i(x,y,z)))
 FileAccess.open(OUT+'base_nodes.bin',FileAccess.WRITE).store_buffer(nodes.to_byte_array())
 FileAccess.open(OUT+'base_columns.bin',FileAccess.WRITE).store_buffer(columns.to_byte_array())
 FileAccess.open(OUT+'base_save.json',FileAccess.WRITE).store_string(JSON.stringify(data.serialize()))
 var report:Dictionary={'crowns':crowns,'lo':[LO.x,LO.y,LO.z],'hi':[HI.x,HI.y,HI.z],'levels':base.levels,'step':.25,'axis_order':'nodes=z,y,x; columns=z,x,height+level_distances','source':'Actual existing default crown solids and ordinary local unified base','stage':'Unaccepted authoring experiment; no automatic scattering or runtime mesh overlay'}
 FileAccess.open(OUT+'source.json',FileAccess.WRITE).store_string(JSON.stringify(report))
 print('CLIFF VOLUME EXPORT: crowns=',crowns.size(),' nodes=',nodes.size(),' columns=',columns.size());quit()
