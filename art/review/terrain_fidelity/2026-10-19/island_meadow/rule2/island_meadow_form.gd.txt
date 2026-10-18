extends RefCounted
## Tools-only whole-body warp: a rolling outer meadow and inward lower return.
## Ordinary saved densities are the only visible terrain authority.
const Data=preload('res://scripts/terrain_editor/terrain_data.gd')
static func apply(editor)->Dictionary:
 var source:=Data.new();assert(source.deserialize(editor.data.serialize()) and source.ensure_sculpt_base())
 var protected:Array=[]
 for entry:Dictionary in editor.renderer.props.entries:
  if not entry.node.visible:continue
  var footprint:Vector2=entry.get('footprint',Vector2.ONE*float(entry.radius))
  protected.append({'at':entry.at,'radius':footprint.length()+.20})
 # The two retained authored trees use a .6m stable footprint in the live
 # decoration rule; protect that whole footprint, not just their centers.
 for at:Vector2 in [Vector2(-16,-3),Vector2(-5,-8)]:
  if not source.cells.has(Vector2i(at.floor())):continue
  protected.append({'at':at,'radius':.90})
 # The original paving consists of rigid stones. Keep their full real mesh
 # footprint flat, rather than seating only each center over a sloped cut.
 var path_zones:=0
 for chunk:Node in editor.renderer.chunks.values():
  for child:Node in chunk.get_children():
   if not child is MultiMeshInstance3D or not str(child.name).begins_with('path_'):continue
   var mm:MultiMesh=child.multimesh
   var bounds:AABB=mm.mesh.get_aabb()
   for i in mm.instance_count:
    var pose:=mm.get_instance_transform(i)
    var center:=pose*bounds.get_center();var radius:=0.0
    for j in 8:
     var corner:=pose*bounds.get_endpoint(j)
     radius=maxf(radius,Vector2(corner.x-center.x,corner.z-center.z).length())
    protected.append({'at':Vector2(center.x,center.z),'radius':radius+.15});path_zones+=1
 var payload:Dictionary=source.serialize();payload.rocks=[]
 for cell:Dictionary in payload.cells:cell.height=1.5
 assert(editor.data.deserialize(payload) and editor.data.ensure_sculpt_base())
 var base=editor.data.rocks.base
 var lo:Vector3i=base.low;var hi:Vector3i=base.low+base.size-Vector3i.ONE
 for key:Vector3i in source.rocks.samples:
  lo.x=mini(lo.x,key.x);lo.z=mini(lo.z,key.z);hi.x=maxi(hi.x,key.x);hi.z=maxi(hi.z,key.z)
 var samples:Dictionary[Vector3i,float]={};var guards:=0;var columns:=0
 var start:=Time.get_ticks_usec();var maximum_drop:=0.0
 for z in range(lo.z,hi.z+1):
  for x in range(lo.x,hi.x+1):
   var at:=Vector2(x,z)*.25
   var inset:float=-source.rocks.base._cover_distance(at,3.5)
   var free:=1.0
   for zone:Dictionary in protected:free=minf(free,smoothstep(zone.radius,zone.radius+.85,at.distance_to(zone.at)))
   var drop:float=.58*(1.0-smoothstep(.10,1.75,inset))*free
   var top:float=1.5-drop
   # Deep interior and shallow outer return, rather than one globally
   # compressed side-wall plate. Variation is broad and deterministic.
   var scale_y:=.52
   var floor_y:float=-.55-.75*smoothstep(-.3,3.0,inset)
   maximum_drop=maxf(maximum_drop,drop);columns+=1
   for y in range(lo.y,hi.y+1):
    var key:=Vector3i(x,y,z);var p:=Vector3(key)*.25
    var world_y:=p.y
    p.y=3.5+(p.y-1.5)/scale_y
    var old:float=source.rocks.value_at(p)
    var value:float=.5 if old>=.499999 else clampf(old*scale_y,-.5,.5)
    # Independent analytic upper/lower cuts avoid warping every source
    # density band with the top, which caused corrugated slopes in rule1.
    if drop>.000001:value=maxf(value,world_y-top)
    value=clampf(maxf(value,floor_y-world_y),-.5,.5)
    value=roundf(value*100000.0)/100000.0
    if absf(value)<.0002:value=-.0002 if value<0 else .0002;guards+=1
    if value!=base.node_value(key):samples[key]=value
 assert(samples.size()<=editor.data.rocks.MAX_SAMPLES)
 editor.data.rocks.samples=samples;editor.data.rocks._height_bounds_dirty=true
 editor.data._invalidate_rocks(samples.keys());editor.renderer.rebuild_all()
 return {'rule':'meadow_cut2','records':samples.size(),'sampled_xz_columns':columns,'near_zero_guards':guards,'maximum_top_drop':maximum_drop,'protected_flat_zones':protected.size(),'protected_path_footprints':path_zones,'construction_ms':(Time.get_ticks_usec()-start)/1000.0,'method':'Original retained field compressed uniformly.52 around cap1.5; independent analytic top cut cap1.5 minus rolling drop up to.58m; independent lower cut floor−.55→−1.30 from signed contour depth. Protected full live prop/tree/path footprints. Saturated far air+.5, five decimals, sign-preserving near-zero guard. Ordinary v4records; not renderer scaling or extra terrain.','scope':'One tools-only whole-scene shape study. New support, geometry, editing and preset adoption remain unverified until separate evidence.'}
static func cover(editor)->Dictionary:
 var field=editor.data.rocks;var contours=editor.renderer.contours
 var surface=contours.surfaces.sculpted_terrain
 var before:PackedByteArray=surface.vertices.to_byte_array()
 var roofs:Dictionary={};var owned:=0;var max_error:=0.0
 for i in surface.vertices.size():
  var p:Vector3=surface.vertices[i];var n:Vector3=surface.normals[i]
  if surface.uv[i].y>=0 or p.y<.72 or p.y>1.53 or n.y<.30:continue
  var at:=Vector2(p.x,p.z)
  if not roofs.has(at):roofs[at]=field.height_at(at)
  var roof:float=roofs[at]
  if not is_finite(roof) or absf(roof-p.y)>.001:continue
  var cover:float=smoothstep(.30,.77,n.y)
  if cover<=surface.colors[i].r:continue
  surface.colors[i].r=cover;owned+=1;max_error=maxf(max_error,absf(roof-p.y))
 contours._index_triangles()
 for chunk:Vector2i in editor.renderer.chunks:
  var instance:MeshInstance3D=editor.renderer.chunks[chunk].get_node_or_null('sculpted_terrain')
  if instance!=null:instance.mesh=contours.build(chunk).sculpted_terrain
 assert(before==surface.vertices.to_byte_array())
 return {'actual_top_vertex_occurrences':owned,'unique_roof_queries':roofs.size(),'maximum_roof_error':max_error,'terrain_vertex_bytes_unchanged':true,'rule':'Slope-based grass on actual topmost dry roots between.72–1.53m; no color shell or geometry. Prototype-only; not edit-refresh integration.'}
