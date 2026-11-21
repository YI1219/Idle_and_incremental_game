class_name TerrainRenderer
extends Node3D
signal terrain_published
class BuildCancellation extends RefCounted:
	var mutex:=Mutex.new()
	var cancelled:bool=false
	func cancel()->void:
		mutex.lock()
		cancelled=true
		mutex.unlock()
	func is_cancelled()->bool:
		mutex.lock()
		var result:bool=cancelled
		mutex.unlock()
		return result
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Geometry=preload("res://scripts/terrain_editor/chunk_geometry.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
var contours:=Contours.new()
var _contour_revision:=-1
var _pick_faces:Dictionary={}
var _pick_bounds:Dictionary={}
var _pending_chunks:Dictionary={}
var _pending_faces:Dictionary={}
var _pending_bounds:Dictionary={}
var _build_queue:Array=[]
var _pending_shore:Dictionary={}
var _build_data:Data
var _build_revision:int=-1
var _pending_contours:RefCounted
var _published_data:Data
var props:Node3D
var mist:MultiMeshInstance3D
var data:Data
var chunks:Dictionary={}
var materials:Dictionary={}
var rebuild_count:=0
var last_rebuild_ms:=0.0
var decoration:RefCounted
## Interactive edits rebuild the whole revision on a worker thread while the
## previous complete revision stays visible; the main thread only publishes.
## rebuild_all() and large flush budgets remain synchronous (tests, capture).
var threaded_builds:=true
## Swaying 3D grass blades over the lawn (grass_field.gd).
var grass_blades_enabled:=true
var _back_contours:=Contours.new()
var _worker_task:=-1
var _worker_cancel:BuildCancellation
var _worker_result:Dictionary={}
var _blueprint_source:Data
var _committed_blueprint_source:Data
var _worker_blueprint_stamp:String=""
var _prepared_blueprint_stamp:String=""
var _prepared_blueprint:Dictionary={}
var _committed_blueprint_stamp:String=""
var _committed_blueprint_revision:int=-1
var _published_runs:Dictionary={}
## Worker wall time of the last threaded revision and main-thread publish cost.
var last_worker_ms:=0.0
var last_publish_ms:=0.0
var last_worker_stages:Dictionary={}
## Threaded results publish in steps: new chunk nodes enter the tree hidden a
## few per frame, then all swap visibility in one frame; replaced nodes are
## freed a few per frame afterwards. Keeps every step inside the frame budget.
const STAGE_BUDGET_USEC:=2500
var _staging:Array=[]
var _staging_ready:=false
var _staging_active:=false
var _graveyard:Array=[]
var _retiring_chunks:Array[Node3D]=[]
## Edits grow into place over MORPH_SECONDS. A full rebuild snaps.
const MORPH_SECONDS:=.55
const MORPH_RISE:=2.4
var animate_edits:=true
var morph_progress:=1.0
var _morph_from:Dictionary={}
var _morph_to:Dictionary={}
var _snap_next:=false
# R: 0 = standing, 1 = flattened. Caller owns painting/recovery and texture
# updates; this round only reserves the world-space data/material path.
var _grass_compression:Texture2D
var _compression_bounds:=Rect2(-64,-64,128,128)

func set_grass_compression(texture:Texture2D,world_rect:Rect2)->bool:
	if world_rect.size.x<=0 or world_rect.size.y<=0:return false
	_grass_compression=texture
	_compression_bounds=world_rect
	_bind_grass_compression()
	return true

func _bind_grass_compression()->void:
	for kind in ["grass","cliff","rim_green","shore","sculpted_terrain","grass_blades"]:
		if not materials.has(kind):continue
		materials[kind].set_shader_parameter("grass_compression",_grass_compression)
		materials[kind].set_shader_parameter("compression_origin",_compression_bounds.position)
		materials[kind].set_shader_parameter("compression_extent",_compression_bounds.size)


func configure(source:Data)->void:
	_finish_worker()
	_flush_staging()
	_discard_pending()
	_build_queue.clear()
	data=source
	_contour_revision=-1
	if props==null:
		props=preload("res://scripts/terrain_editor/terrain_props.gd").new()
		add_child(props)
	if mist==null:
		mist=preload("res://scripts/terrain_editor/waterfall_mist.gd").new()
		add_child(mist)
	if materials.is_empty():
		var ground:=ShaderMaterial.new()
		ground.shader=load("res://shaders/terrain_editor/ground.gdshader")
		materials.grass=ground
		var green:=ShaderMaterial.new()
		green.shader=load("res://shaders/terrain_editor/rim_green.gdshader")
		materials.rim_green=green
		var cliff:=ShaderMaterial.new()
		cliff.shader=load("res://shaders/terrain_editor/cliff.gdshader")
		materials.cliff=cliff
		materials.sculpted_rock=cliff.duplicate()
		materials.sculpted_rock.set_shader_parameter("follow_land_morph",false)
		var unified:=ShaderMaterial.new()
		unified.shader=load("res://shaders/terrain_editor/sculpt_terrain.gdshader")
		materials.sculpted_terrain=unified
		var mantle:=ShaderMaterial.new()
		mantle.shader=load("res://shaders/terrain_editor/stone_mantle.gdshader")
		materials.stone_mantle=mantle
		var foam:=ShaderMaterial.new()
		foam.shader=load("res://shaders/terrain_editor/foam.gdshader")
		materials.bank=foam
		var water:=ShaderMaterial.new()
		water.shader=load("res://shaders/terrain_editor/water.gdshader")
		# Render the refracting surface before translucent falls/froth/mist.
		# Those effects are absent from its opaque scene-color buffer.
		water.render_priority=-10
		materials.water=water
		var bed:=ShaderMaterial.new()
		bed.shader=load("res://shaders/terrain_editor/lake_bed.gdshader")
		materials.lake_bed=bed
		var fall:=ShaderMaterial.new()
		fall.shader=load("res://shaders/terrain_editor/waterfall.gdshader")
		materials.waterfall=fall
		var shore:=ShaderMaterial.new()
		shore.shader=load("res://shaders/terrain_editor/shore.gdshader")
		materials.shore=shore
		materials.grass_blades=preload("res://scripts/terrain_editor/grass_field.gd").material()
	for material in materials.values():preload("res://scripts/terrain_editor/material_detail.gd").bind(material)
	_bind_grass_compression()
	for cell:Vector2i in data.cells:
		for z in range(-1,2):
			for x in range(-1,2):data.dirty_chunks[Data.chunk_of(cell+Vector2i(x,z))]=true

func _solid(color:Color,vertex:bool=false)->StandardMaterial3D:
	var result:=StandardMaterial3D.new()
	result.albedo_color=color
	result.vertex_color_use_as_albedo=vertex
	result.vertex_color_is_srgb=true
	result.roughness=0.95
	result.cull_mode=BaseMaterial3D.CULL_DISABLED
	return result

func flush_dirty(max_chunks:int=2)->int:
	if data==null:return 0
	_reap_graveyard()
	if _staging_active:
		_advance_staging()
		return 0
	if _worker_task!=-1:
		if not WorkerThreadPool.is_task_completed(_worker_task):return 0
		WorkerThreadPool.wait_for_task_completion(_worker_task)
		_worker_task=-1
		if not _worker_blueprint_stamp.is_empty():_finish_blueprint_build()
		else:_adopt_worker_result()
		return 1
	var wants:=_contour_revision!=data.revision or not data.dirty_chunks.is_empty()
	if _committed_blueprint_source!=null and data.revision!=_committed_blueprint_revision:
		_committed_blueprint_source=null
		_committed_blueprint_stamp=""
	if threaded_builds and wants and max_chunks<(1<<20) and _build_queue.is_empty():
		if _committed_blueprint_source!=null:
			_start_blueprint_build()
			return 0
		_start_worker()
		return 0
	if not wants and _blueprint_source!=null and threaded_builds and _prepared_blueprint_stamp!=_blueprint_stamp(_blueprint_source):
		_start_blueprint_build()
		return 0
	var start:=Time.get_ticks_usec()
	var count:=0
	var refreshed:=false
	if _build_queue.is_empty() and (_contour_revision!=data.revision or not data.dirty_chunks.is_empty()):
		refreshed=true
		_build_data=_snapshot()
		_build_revision=data.revision
		contours.refresh(_build_data)
		if decoration!=null:
			decoration.load_assets()
			decoration._column_layout(contours,_build_data.seed)
		_contour_revision=data.revision
		_discard_pending()
		_pending_shore=preload("res://scripts/terrain_editor/water_shore_field.gd").build(_build_data,contours)
		# Shared cap triangulation can cross distant chunks. Reconstruct the owning
		# chunks under the ordinary two-chunk budget, including removed geometry.
		# The triangle index avoids scanning the whole island per chunk.
		for chunk in chunks:data.dirty_chunks[chunk]=true
		for chunk in contours.triangle_chunks:data.dirty_chunks[chunk]=true
		_build_queue=data.dirty_chunks.keys()
		data.dirty_chunks.clear()
		if max_chunks<=8:
			last_rebuild_ms=(Time.get_ticks_usec()-start)/1000.0
			return 0
	while not _build_queue.is_empty() and count<max_chunks:
		_rebuild(_build_queue.pop_front())
		count+=1
	if (count>0 or refreshed) and _build_queue.is_empty():_publish()
	last_rebuild_ms=(Time.get_ticks_usec()-start)/1000.0 if count>0 else 0.0
	return count

## Footprints that keep blades out of rocks, trunks, shrubs, stepping stones
## and props: Vector3(x, radius, z) circles and Rect2 areas (world XZ).
const GRASS_CLEAR:={"tree":.12,"tree_b":.12,"surface_rock":.75,"cliff_rock":.8,"shore_rock":.45,"shore_boulder":.55,"shore_pebble":.3,"bush":.5,"path":.46,"reeds":.3}
func _grass_blockers(build:Data,chunk:Vector2i)->Array:
	var blockers:Array=[]
	if decoration!=null:
		var groups:Dictionary=decoration.placements(build,chunk)
		for kind in GRASS_CLEAR:
			for pose:Transform3D in groups.get(kind,[]):
				var r:float=GRASS_CLEAR[kind]*maxf(pose.basis.x.length(),pose.basis.z.length())
				blockers.append(Vector3(pose.origin.x,r,pose.origin.z))
		var chunk_box:=Rect2(Vector2(chunk.x*8.0-2.5,chunk.y*8.0-2.5),Vector2(13.0,13.0))
		for oc:Dictionary in decoration._outcrops:
			if oc.get("kind","")=="rim_shelf":continue
			var oc_pose:Transform3D=oc.pose
			var oc_pos:=Vector2(oc_pose.origin.x,oc_pose.origin.z)
			if not chunk_box.has_point(oc_pos):continue
			var oc_poly:PackedVector2Array=oc.get("turf_hull",PackedVector2Array())
			if oc_poly.size()>=3:
				blockers.append(oc_poly)
			else:
				blockers.append(Vector3(oc_pos.x,1.35,oc_pos.y))
	if props!=null:
		for entry:Dictionary in props.entries:
			var at:Vector2=entry.at
			if entry.has("footprint"):
				var fp:Vector2=entry.footprint
				blockers.append(Rect2(at-fp,fp*2.0))
			else:blockers.append(Vector3(at.x,float(entry.radius),at.y))
	return blockers

func _snapshot()->Data:
	data.ensure_sculpt_base()
	return data.copy()

func _start_worker()->void:
	_worker_cancel=null
	_worker_blueprint_stamp=""
	if decoration!=null:decoration.load_assets()
	var snapshot:=_snapshot()
	_contour_revision=data.revision
	var wanted:Dictionary=_affected_chunks(snapshot)
	data.dirty_chunks.clear()
	_discard_pending()
	_worker_result={}
	_back_contours.inherit_generation_cache(contours)
	_worker_task=WorkerThreadPool.add_task(_worker_build.bind(snapshot,_back_contours,wanted,Time.get_ticks_usec()),false,"terrain revision")

func _blueprint_stamp(draft:Data)->String:
	return "%d|%d"%[draft.get_instance_id(),draft.revision]

func prepare_blueprint(draft:Data)->void:
	_blueprint_source=draft
	# A superseded preview should not finish expensive chunks after release.
	if _worker_cancel!=null and not _worker_blueprint_stamp.is_empty() and _worker_blueprint_stamp!=_blueprint_stamp(draft):
		_worker_cancel.cancel()

func cancel_blueprint()->void:
	if _worker_cancel!=null and _worker_blueprint_stamp!=_committed_blueprint_stamp:_worker_cancel.cancel()
	_blueprint_source=null
	_discard_blueprint_result()

func commit_prepared_blueprint(draft:Data)->void:
	_committed_blueprint_stamp=_blueprint_stamp(draft)
	_committed_blueprint_revision=data.revision
	_committed_blueprint_source=draft
	_blueprint_source=null
	if _prepared_blueprint_stamp==_committed_blueprint_stamp:
		_worker_result=_prepared_blueprint
		_worker_result.authoritative_revision=data.revision
		_prepared_blueprint={}
		_prepared_blueprint_stamp=""
		_committed_blueprint_stamp=""
		_committed_blueprint_source=null
		_contour_revision=data.revision
		data.dirty_chunks.clear()
		_adopt_worker_result()

func _discard_blueprint_result()->void:
	for node:Node3D in _prepared_blueprint.get("chunks",{}).values():
		if node!=null:node.free()
	_prepared_blueprint={}
	_prepared_blueprint_stamp=""

func _start_blueprint_build()->void:
	if decoration!=null:decoration.load_assets()
	_discard_blueprint_result()
	var source:Data=_committed_blueprint_source if _committed_blueprint_source!=null else _blueprint_source
	var snapshot:Data=source.copy()
	_worker_blueprint_stamp=_blueprint_stamp(source)
	var wanted:Dictionary=_affected_chunks(snapshot)
	_worker_result={}
	_back_contours.inherit_generation_cache(contours)
	_worker_cancel=BuildCancellation.new()
	_worker_task=WorkerThreadPool.add_task(_worker_build.bind(snapshot,_back_contours,wanted,Time.get_ticks_usec(),_worker_cancel),false,"terrain blueprint")

func _affected_chunks(snapshot:Data)->Dictionary:
	var affected:Dictionary={}
	var previous:Data=_published_data
	if previous==null or previous.seed!=snapshot.seed or previous.sculpt_base_enabled!=snapshot.sculpt_base_enabled:
		for chunk:Vector2i in chunks:affected[chunk]=true
		for cell:Vector2i in snapshot.cells:affected[Data.chunk_of(cell)]=true
		return affected
	var candidates:Dictionary=previous.cells.duplicate()
	candidates.merge(snapshot.cells,true)
	for cell:Vector2i in candidates:
		var old:Dictionary=previous.cells.get(cell,{})
		var next:Dictionary=snapshot.cells.get(cell,{})
		if old.get("height")==next.get("height") and old.get("water")==next.get("water"):continue
		var center:Vector2i=Data.chunk_of(cell)
		# Broad source crowns and their roots can extend beyond their owning
		# eight-metre chunk. Include a full neighboring chunk on each side.
		for z:int in range(-1,2):
			for x:int in range(-1,2):affected[center+Vector2i(x,z)]=true
	var rock_keys:Dictionary=previous.rocks.samples.duplicate()
	rock_keys.merge(snapshot.rocks.samples,true)
	for key:Vector3i in rock_keys:
		if previous.rocks.samples.get(key)==snapshot.rocks.samples.get(key):continue
		var point:Vector3=Vector3(key)*Data.RockSculpt.STEP
		var center:Vector2i=Data.chunk_of(Vector2i(floori(point.x),floori(point.z)))
		for z:int in range(-1,2):
			for x:int in range(-1,2):affected[center+Vector2i(x,z)]=true
	return affected

func _finish_blueprint_build()->void:
	var result:Dictionary=_worker_result
	_worker_result={}
	var stamp:String=_worker_blueprint_stamp
	_worker_blueprint_stamp=""
	if result.is_empty():return
	_back_contours=result.field
	if result.get("cancelled",false):
		for node:Node3D in result.get("chunks",{}).values():
			if node!=null:node.free()
		return
	if stamp==_committed_blueprint_stamp and data.revision==_committed_blueprint_revision:
		_worker_result=result
		_worker_result.authoritative_revision=data.revision
		_committed_blueprint_stamp=""
		_committed_blueprint_source=null
		_contour_revision=data.revision
		data.dirty_chunks.clear()
		_adopt_worker_result()
	elif _blueprint_source!=null and stamp==_blueprint_stamp(_blueprint_source):
		_prepared_blueprint=result
		_prepared_blueprint_stamp=stamp
	else:
		for node:Node3D in result.chunks.values():
			if node!=null:node.free()

func _worker_build(snapshot:Data,field,wanted:Dictionary,started:int,cancellation:BuildCancellation=null)->void:
	# Runs off the scene tree: only new resources and detached nodes are made.
	var stages:={}
	var t:=Time.get_ticks_usec()
	field.refresh(snapshot)
	stages.contours=(Time.get_ticks_usec()-t)/1000.0;t=Time.get_ticks_usec()
	if cancellation!=null and cancellation.is_cancelled():
		_worker_result={"field":field,"cancelled":true}
		return
	if decoration!=null:
		decoration._previous_runs=_published_runs.duplicate(true)
		decoration._column_layout(field,snapshot.seed)
	stages.layout=(Time.get_ticks_usec()-t)/1000.0;t=Time.get_ticks_usec()
	if decoration!=null:stages.layout_detail=decoration.layout_stages.duplicate()
	if cancellation!=null and cancellation.is_cancelled():
		_worker_result={"field":field,"cancelled":true}
		return
	var shore:Dictionary=preload("res://scripts/terrain_editor/water_shore_field.gd").build(snapshot,field)
	stages.shore=(Time.get_ticks_usec()-t)/1000.0;t=Time.get_ticks_usec()
	var out:={"chunks":{},"faces":{},"bounds":{},"stages":stages}
	for chunk in wanted:
		if cancellation!=null and cancellation.is_cancelled():
			out.field=field
			out.cancelled=true
			_worker_result=out
			return
		_rebuild(chunk,field,snapshot,out)
	stages.chunks=(Time.get_ticks_usec()-t)/1000.0
	out.shore=shore
	out.data=snapshot
	out.authoritative_revision=snapshot.revision
	out.field=field
	out.ms=(Time.get_ticks_usec()-started)/1000.0
	_worker_result=out

func _adopt_worker_result()->void:
	var result:=_worker_result
	_worker_result={}
	if result.is_empty():return
	if int(result.authoritative_revision)!=data.revision:
		_back_contours=result.field
		for node:Node3D in result.chunks.values():
			if node!=null:node.free()
		return
	var start:=Time.get_ticks_usec()
	_discard_pending()
	_pending_chunks=result.chunks
	_pending_faces=result.faces
	_pending_bounds=result.bounds
	_pending_shore=result.shore
	_build_data=result.data
	_build_revision=int(result.authoritative_revision)
	_pending_contours=result.field
	for chunk in _pending_chunks:_staging.append(chunk)
	_staging_ready=false
	_staging_active=true
	_advance_staging()
	last_worker_ms=result.ms
	last_worker_stages=result.get("stages",{})
	last_publish_ms=(Time.get_ticks_usec()-start)/1000.0
	last_rebuild_ms=last_publish_ms

func _advance_staging()->void:
	var start:=Time.get_ticks_usec()
	while not _staging.is_empty():
		var node:Node3D=_pending_chunks.get(_staging.pop_back())
		if node!=null:
			node.visible=false
			add_child(node)
		if Time.get_ticks_usec()-start>STAGE_BUDGET_USEC:return
	if not _staging_ready:
		# Leave the commit to the next frame unless budget remains.
		_staging_ready=true
		if Time.get_ticks_usec()-start>STAGE_BUDGET_USEC/2:return
	if morph_progress<1.0:return
	if _build_revision!=data.revision:
		_staging_ready=false
		_staging_active=false
		_discard_pending()
		return
	_staging_ready=false
	_staging_active=false
	_publish(true)

func _reap_graveyard()->void:
	var start:=Time.get_ticks_usec()
	while not _graveyard.is_empty() and Time.get_ticks_usec()-start<STAGE_BUDGET_USEC:
		var old:Node3D=_graveyard.pop_back()
		if is_instance_valid(old):
			if old.get_parent()==self:remove_child(old)
			old.free()

func _flush_staging()->void:
	if not _staging_active:return
	if _build_revision!=data.revision:
		_discard_pending()
		return
	while not _staging.is_empty():
		var node:Node3D=_pending_chunks.get(_staging.pop_back())
		if node!=null:
			node.visible=false
			add_child(node)
	_staging_ready=false
	_staging_active=false
	_publish(true)

func _finish_worker()->void:
	# Block until an in-flight revision ends, then drop its detached result.
	if _worker_task!=-1:
		WorkerThreadPool.wait_for_task_completion(_worker_task)
		_worker_task=-1
		_worker_blueprint_stamp=""
		var result:=_worker_result
		_worker_result={}
		if not result.is_empty():
			_back_contours=result.field
			for node in result.get("chunks",{}).values():
				if node!=null:node.free()
	_discard_blueprint_result()
	_blueprint_source=null
	_committed_blueprint_source=null
	_committed_blueprint_stamp=""

func _rebuild(chunk:Vector2i,field=null,build:Data=null,out:Dictionary={})->void:
	if field==null:field=contours
	if build==null:build=_build_data
	var target_chunks:Dictionary=out.get("chunks",_pending_chunks)
	var target_faces:Dictionary=out.get("faces",_pending_faces)
	var target_bounds:Dictionary=out.get("bounds",_pending_bounds)
	var geometry:Dictionary=field.build(chunk)
	if not field.lawn_boundaries.is_empty():
		geometry.grass=preload("res://scripts/terrain_editor/rim_surface_detail.gd").lawn(geometry.grass,field.lawn_boundaries,field.water_regions,0.0)
	target_chunks[chunk]=null
	target_faces.erase(chunk)
	target_bounds.erase(chunk)
	var faces:=PackedVector3Array()
	for kind in ["grass","cliff","water","waterfall","shore","stone_mantle","sculpted_rock","sculpted_terrain"]:
		if geometry.has(kind):faces.append_array(preload("res://scripts/terrain_editor/chunk_geometry.gd").faces_of(geometry[kind]))
	if decoration!=null:
		for crown:Dictionary in decoration._columns:
			if Data.chunk_of(crown.cell)!=chunk:continue
			var part_entry:Dictionary=decoration.assets[crown.kind][0]
			var crown_faces:PackedVector3Array=part_entry.get("faces",PackedVector3Array())
			if crown_faces.is_empty():
				var drawn:Mesh=crown.get('render_mesh',part_entry.render_mesh)
				crown_faces=preload("res://scripts/terrain_editor/chunk_geometry.gd").faces_of(drawn)
			for point:Vector3 in crown_faces:faces.append(crown.pose*point)
		for rock:Dictionary in decoration._outcrops:
			var at:=Vector2(rock.pose.origin.x,rock.pose.origin.z)
			if Data.chunk_of(Vector2i(at.floor()))!=chunk:continue
			for point:Vector3 in preload("res://scripts/terrain_editor/chunk_geometry.gd").faces_of(decoration.assets[rock.kind][0].mesh):faces.append(rock.pose*point)
	if not faces.is_empty():
		target_faces[chunk]=faces
		var bounds:=AABB(faces[0],Vector3.ZERO)
		for point in faces:bounds=bounds.expand(point)
		target_bounds[chunk]=bounds.grow(.001)
	var populated:=false
	for key in geometry:
		if geometry[key].get_surface_count()>0:populated=true
	if not populated:return
	var node:=Node3D.new()
	node.name="Chunk_%d_%d"%[chunk.x,chunk.y]
	for key in geometry:
		if geometry[key].get_surface_count()==0:continue
		var instance:=MeshInstance3D.new()
		instance.name=key
		instance.mesh=geometry[key]
		instance.material_override=materials[key]
		# The thin meadow roll uses its narrow material contact. Its shadow-map
		# silhouette otherwise stamps a continuous dark belt over the cliff.
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key in ["grass","water","waterfall"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.add_child(instance)
	target_chunks[chunk]=node
	if decoration!=null:
		var t_pop:=Time.get_ticks_usec()
		decoration.contours=field
		decoration.populate(node,build,chunk)
		if out.has("stages"):out.stages.populate=out.stages.get("populate",0.0)+(Time.get_ticks_usec()-t_pop)/1000.0
	if grass_blades_enabled and geometry.has("grass"):
		var t_grass:=Time.get_ticks_usec()
		var blades:MultiMeshInstance3D=preload("res://scripts/terrain_editor/grass_field.gd").build(geometry.grass,chunk,_grass_blockers(build,chunk))
		if blades!=null:node.add_child(blades)
		if out.has("stages"):out.stages.grass=out.stages.get("grass",0.0)+(Time.get_ticks_usec()-t_grass)/1000.0
	rebuild_count+=1

func _discard_pending()->void:
	_staging.clear()
	_staging_active=false
	_staging_ready=false
	if _pending_contours!=null:
		_back_contours=_pending_contours
		_pending_contours=null
		if decoration!=null:decoration.contours=contours
	_pending_shore={}
	for node in _pending_chunks.values():
		if node!=null:node.free()
	_pending_chunks.clear()
	_pending_faces.clear()
	_pending_bounds.clear()

func _publish(staged:bool=false)->void:
	# Keep the previous complete revision visible until the next one is ready.
	# Meshes, decoration, picking and supported props switch in the same frame.
	if _pending_contours!=null:
		_back_contours=contours
		contours=_pending_contours
		_pending_contours=null
		if decoration!=null:decoration.contours=contours
	_start_morph(_published_data,_build_data)
	var transitioning:bool=morph_progress<1.0
	for chunk in _pending_chunks:
		if chunks.has(chunk):
			var old:Node3D=chunks[chunk]
			if transitioning:
				_transition_role(old,1.0)
				_retiring_chunks.append(old)
			elif staged:
				old.visible=false
				_graveyard.append(old)
			else:
				remove_child(old)
				old.queue_free()
			chunks.erase(chunk)
		_pick_faces.erase(chunk)
		_pick_bounds.erase(chunk)
		var node:Node3D=_pending_chunks[chunk]
		if node!=null:
			_transition_role(node,0.0 if transitioning else 2.0)
			if staged:node.visible=true
			else:add_child(node)
			chunks[chunk]=node
		if _pending_faces.has(chunk):
			_pick_faces[chunk]=_pending_faces[chunk]
			_pick_bounds[chunk]=_pending_bounds[chunk]
	_pending_chunks.clear()
	_pending_faces.clear()
	_pending_bounds.clear()
	_published_data=_build_data
	if decoration!=null:_published_runs=decoration._previous_runs.duplicate(true)
	if not _pending_shore.is_empty():
		materials.water.set_shader_parameter("shore_field",preload("res://scripts/terrain_editor/water_shore_field.gd").texture_of(_pending_shore))
		materials.water.set_shader_parameter("shore_origin",_pending_shore.origin)
		materials.water.set_shader_parameter("shore_extent",_pending_shore.extent)
		_pending_shore={}
	props.sync(contours)
	mist.sync(contours.splash_points,contours.fall_veils,contours.land_regions)
	terrain_published.emit()

func _exit_tree()->void:
	_finish_worker()
	_flush_staging()
	_discard_pending()
	for old:Node3D in _retiring_chunks:
		if is_instance_valid(old):old.free()
	_retiring_chunks.clear()
	for old in _graveyard:
		if is_instance_valid(old):old.free()
	_graveyard.clear()

static func _tops(source:Data)->Dictionary:
	var result:Dictionary={}
	if source==null:return result
	for cell:Vector2i in source.cells:
		var record:Dictionary=source.cells[cell]
		result[cell]=record.water*.5 if record.water>=0 else float(record.height)
	return result

static func morph_ease(t:float)->float:
	var u:=clampf(t,0.0,1.0)
	return u*u*(3.0-2.0*u)

func _transition_role(node:Node,role:float)->void:
	if node is GeometryInstance3D:node.set_instance_shader_parameter("terrain_transition_role",role)
	for child:Node in node.get_children():_transition_role(child,role)

func _finish_retiring()->void:
	for old:Node3D in _retiring_chunks:
		if is_instance_valid(old):
			old.visible=false
			_graveyard.append(old)
	_retiring_chunks.clear()
	for node:Node3D in chunks.values():_transition_role(node,2.0)

func shown_top(cell:Vector2i)->float:
	if not _morph_to.has(cell):return NAN
	return lerpf(_morph_from.get(cell,float(_morph_to[cell])-MORPH_RISE),float(_morph_to[cell]),morph_ease(morph_progress))

func _start_morph(previous:Data,next:Data)->void:
	_finish_retiring()
	var to:=_tops(next)
	var old_tops:=_tops(previous)
	var snap:=_snap_next or previous==null or not animate_edits
	_snap_next=false
	var from:Dictionary={}
	var changed:bool=previous!=null and previous.rocks.samples!=next.rocks.samples
	if not snap:
		for cell:Vector2i in to:
			var shown:=shown_top(cell)
			if is_nan(shown):changed=true
			else:
				from[cell]=shown
				if absf(shown-float(to[cell]))>.001:changed=true
		for cell:Vector2i in old_tops:
			if not to.has(cell):changed=true
	_morph_to=to
	if snap or not changed:
		morph_progress=1.0
		_morph_from=to.duplicate()
		RenderingServer.global_shader_parameter_set("terrain_morph_progress",1.0)
		return
	_morph_from=from
	var lo:=Vector2i(1<<20,1<<20)
	var hi:=-lo
	var occupied:Dictionary=old_tops.duplicate()
	occupied.merge(to,true)
	for cell:Vector2i in occupied:
		lo=Vector2i(mini(lo.x,cell.x),mini(lo.y,cell.y))
		hi=Vector2i(maxi(hi.x,cell.x),maxi(hi.y,cell.y))
	lo-=Vector2i(4,4)
	hi+=Vector2i(4,4)
	var size:=hi-lo+Vector2i.ONE
	var image:=Image.create(size.x,size.y,false,Image.FORMAT_RGBAF)
	var known:Dictionary={}
	for cell:Vector2i in occupied:
		var old_top:float=float(old_tops.get(cell,float(to.get(cell,0.0))-MORPH_RISE))
		var new_top:float=float(to.get(cell,old_top-MORPH_RISE))
		var shown:float=float(from.get(cell,old_top))
		var pair:=Color(old_top,new_top,shown,1.0)
		image.set_pixelv(cell-lo,pair)
		known[cell]=pair
	for ring in 4:
		var grown:Dictionary={}
		for cell:Vector2i in known:
			for offset:Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
				var neighbor:Vector2i=cell+offset
				if known.has(neighbor):continue
				var pair:Color=known[cell]
				if grown.has(neighbor) and absf(grown[neighbor].g-grown[neighbor].r)>=absf(pair.g-pair.r):continue
				grown[neighbor]=pair
		for cell:Vector2i in grown:
			known[cell]=grown[cell]
			if Rect2i(lo,size).has_point(cell):image.set_pixelv(cell-lo,grown[cell])
	RenderingServer.global_shader_parameter_set("terrain_morph_field",ImageTexture.create_from_image(image))
	RenderingServer.global_shader_parameter_set("terrain_morph_rect",Vector4(lo.x,lo.y,size.x,size.y))
	morph_progress=0.0
	RenderingServer.global_shader_parameter_set("terrain_morph_progress",0.0)

func _process(delta:float)->void:
	if morph_progress>=1.0:return
	morph_progress=minf(1.0,morph_progress+delta/MORPH_SECONDS)
	RenderingServer.global_shader_parameter_set("terrain_morph_progress",morph_progress)
	if morph_progress>=1.0:_finish_retiring()

func pending_chunk_count()->int:
	return _build_queue.size()+(data.dirty_chunks.size() if data!=null else 0)

func has_pending_updates()->bool:
	return data!=null and ((_worker_task!=-1 and _worker_blueprint_stamp.is_empty()) or _staging_active or not _build_queue.is_empty() or not data.dirty_chunks.is_empty() or _contour_revision!=data.revision)

func rebuild_all()->void:
	_finish_worker()
	_flush_staging()
	_snap_next=true
	_discard_pending()
	_build_queue.clear()
	_contour_revision=-1
	for chunk in chunks:data.dirty_chunks[chunk]=true
	for cell:Vector2i in data.cells:
		for z in range(-1,2):
			for x in range(-1,2):data.dirty_chunks[Data.chunk_of(cell+Vector2i(x,z))]=true
	flush_dirty(1<<30)

func pick(ray_origin:Vector3,ray_direction:Vector3)->Dictionary:
	if data==null or ray_direction.length_squared()<0.001:return {}
	var direction:=ray_direction.normalized()
	var nearest:=INF
	var position_hit:=Vector3.ZERO
	var normal_hit:=Vector3.UP
	for chunk:Vector2i in _pick_faces:
		var box:AABB=_pick_bounds[chunk]
		if box.intersects_ray(ray_origin,direction)==null:continue
		var faces:PackedVector3Array=_pick_faces[chunk]
		for i in range(0,faces.size(),3):
			var hit:Variant=Geometry3D.ray_intersects_triangle(ray_origin,direction,faces[i],faces[i+1],faces[i+2])
			if hit==null:continue
			var distance:float=ray_origin.distance_squared_to(hit)
			if distance<nearest:
				nearest=distance;position_hit=hit
				normal_hit=-(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
	if not is_finite(nearest):return {}
	var cell:=Vector2i(floori(position_hit.x),floori(position_hit.z))
	if not _published_data.cells.has(cell):
		var closest:=INF
		var base_cell:=cell
		for z in range(-1,2):
			for x in range(-1,2):
				var candidate:=base_cell+Vector2i(x,z)
				if not _published_data.cells.has(candidate):continue
				var distance:=Vector2(position_hit.x,position_hit.z).distance_squared_to(Vector2(candidate)+Vector2(.5,.5))
				if distance<closest:closest=distance;cell=candidate
	# Sculpted overhangs can extend farther than one cell beyond their support.
	# If the fast neighboring-cell lookup found no owner, resolve the nearest
	# published land cell rather than returning a nonexistent cell to the brush.
	if not _published_data.cells.has(cell):
		var closest:=INF
		for candidate:Vector2i in _published_data.cells:
			var distance:=Vector2(position_hit.x,position_hit.z).distance_squared_to(Vector2(candidate)+Vector2(.5,.5))
			if distance<closest:closest=distance;cell=candidate
	return {"position":position_hit,"cell":cell,"normal":normal_hit}
