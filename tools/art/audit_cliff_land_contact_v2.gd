extends 'res://tools/art/capture_cliff_land_contact_v2.gd'
func run():
 WORK='res://art/work/cliff_land_v2/2026-10-18/contact/'
 var output:='res://art/work/cliff_land_v2/2026-10-18/contact/ownership_after.json'
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with('--report='):output=arg.trim_prefix('--report=')
 compiler.prepare(compiler.fixture(),7301)
 var variants:=fields();var geometry:=tagged_mesh(variants.candidate)
 var arrays:Array=geometry.surface_get_arrays(0);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
 var low_owned:=0;var low_added:=0;var minimum:=INF
 for i:int in vertices.size():
  if colors[i].g>0 and vertices[i].y<2.65:low_owned+=1;minimum=minf(minimum,vertices[i].y)
 for key:Vector3i in variants.candidate.rocks.samples:
  if variants.candidate.rocks.node_value(key)<0 and original_data.rocks.node_value(key)>=0 and key.y*.25<2.65:low_added+=1
 var report:Dictionary={'owned_vertex_occurrences_below_cap':low_owned,'air_to_solid_nodes_below_cap':low_added,'minimum_owned_y':minimum if is_finite(minimum) else null,'hypothesis':'All projected roofs accepted as upper land, so low rock shoulders receive soil and owned colour. Both construction and material must use same upper-cap eligibility.'}
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,'\t',true,true));print('CONTACT OWNERSHIP: ',report);quit()
