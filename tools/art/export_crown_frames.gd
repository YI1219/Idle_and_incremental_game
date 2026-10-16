extends SceneTree
## Actual original crown ownership frames for offline body refinement.
func _initialize():call_deferred('run')
func run():
 var data=preload('res://scripts/terrain_editor/terrain_data.gd').new();data.make_preset(0)
 var field=preload('res://scripts/terrain_editor/contour_terrain.gd').new();field.refresh(data)
 var deco=preload('res://scripts/terrain_editor/terrain_decoration.gd').new();deco.load_assets();deco._column_layout(field,data.seed)
 var records:Array=[]
 for i in deco._columns.size():
  var c:Dictionary=deco._columns[i]
  records.append({'index':i,'kind':c.kind,'edge':[c.edge.x,c.edge.y],'origin':[c.pose.origin.x,c.pose.origin.y,c.pose.origin.z],'outward':[c.outward.x,c.outward.y,c.outward.z],'tangent':[c.tangent.x,c.tangent.y,c.tangent.z],'width':c.width,'thickness':c.thickness,'height':c.height})
 FileAccess.open('res://art/work/rendered_join/2026-10-17/crown_frames.json',FileAccess.WRITE).store_string(JSON.stringify(records,'\t'))
 print('CROWN OWNERSHIP FRAMES: ',records.size());quit()
