extends 'res://tools/art/capture_cliff_land_contact_v2.gd'
## Same authority/strict cells; shallow varying physical soil, not a cuff mesh.
func soil_depth(at:Vector2,distance_value:float)->float:
 var phase:=.5+.5*sin(at.x*1.7+.65*sin(at.y*2.3))
 var thickness:=.055+.115*phase*phase
 var breaks:=smoothstep(-.25,.4,sin(at.x*2.7+at.y*.7)+.4*sin(at.y*3.1))
 return thickness*lerpf(breaks,1.0,smoothstep(.05,.65,-distance_value))
func fields()->Dictionary:
 var prepared:=super.fields()
 var candidate=Data.new();assert(candidate.deserialize(original_data.serialize()))
 var changed:=0;var added:=0;var minimum:=INF;var maximum:=-INF
 for z:int in range(-18,19):
  for x:int in range(-25,26):
   var at:=Vector2(x,z)*.25;var roof:=original_roof(at)
   if not is_finite(roof) or roof<CAP_FLOOR:continue
   var horizontal:=dry_distance(at)
   if horizontal>=0:continue
   var thickness:=soil_depth(at,horizontal)
   minimum=minf(minimum,thickness);maximum=maxf(maximum,thickness)
   for y:int in range(floori((roof-.65)*4),ceili((roof+.55)*4)+1):
    var key:=Vector3i(x,y,z);var old:float=original_data.rocks.node_value(key)
    var translated:float=original_data.rocks.value_at(Vector3(key)*.25-Vector3.UP*thickness)
    var soil:=maxf(maxf(translated,maxf(roof-.065,CAP_FLOOR)-y*.25),horizontal+.015)
    var value:=roundf(clampf(minf(old,soil),-.5,.5)*100000.0)/100000.0
    if absf(value)<.00001:value=.00002
    if value==old:continue
    assert(original_data.cells.has(Vector2i(at.floor())))
    if old>=0 and value<0:assert(y*.25>=CAP_FLOOR);added+=1
    changed+=1
    if value<.5:candidate.rocks.samples[key]=value
    else:candidate.rocks.samples.erase(key)
 candidate.rocks._height_bounds_dirty=true
 reports['mantle_operation']={'changed_records':changed,'air_to_solid':added,'soil_thickness_min':minimum,'soil_thickness_max':maximum,'cells':candidate.cells.size(),'outside_cell_changed_nodes':0,'contour':'Same exact occupied-cell exterior as uniform control','construction':'Shallow variable upper translation sampled through production tetrahedral field, unioned into same saved records. No separate skin/cuff.'}
 return {'source':prepared.source,'candidate':candidate}
