extends SceneTree
func _initialize():call_deferred('run')
func run():
 var data=preload('res://scripts/terrain_editor/terrain_data.gd').new();data.make_preset(0)
 var field=preload('res://scripts/terrain_editor/contour_terrain.gd').new();field.refresh(data)
 var deco=preload('res://scripts/terrain_editor/terrain_decoration.gd').new();deco.load_assets();deco._column_layout(field,data.seed)
 var report:Dictionary={}
 for index in [36,37,38]:
  var c:Dictionary=deco._columns[index]
  report[str(index)]={'outward':[c.outward.x,c.outward.y,c.outward.z],'tangent':[c.tangent.x,c.tangent.y,c.tangent.z],'edge':[c.edge.x,c.edge.y],'kind':c.kind}
 FileAccess.open('res://art/work/cliff_art_patch/2026-10-18/frames.json',FileAccess.WRITE).store_string(JSON.stringify(report,'\t',true,true));print('CLIFF FRAMES:',JSON.stringify(report));quit()
