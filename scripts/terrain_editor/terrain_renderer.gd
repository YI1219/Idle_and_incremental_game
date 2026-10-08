class_name TerrainRenderer
extends Node3D
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
var _published_data:Data
var props:Node3D
var mist:MultiMeshInstance3D
var data:Data
var chunks:Dictionary={}
var materials:Dictionary={}
var rebuild_count:=0
var last_rebuild_ms:=0.0
var decoration:RefCounted

func configure(source:Data)->void:
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
		var cliff:=ShaderMaterial.new()
		cliff.shader=load("res://shaders/terrain_editor/cliff.gdshader")
		materials.cliff=cliff
		var foam:=ShaderMaterial.new()
		foam.shader=load("res://shaders/terrain_editor/foam.gdshader")
		materials.bank=foam
		var water:=ShaderMaterial.new()
		water.shader=load("res://shaders/terrain_editor/water.gdshader")
		materials.water=water
		var fall:=ShaderMaterial.new()
		fall.shader=load("res://shaders/terrain_editor/waterfall.gdshader")
		materials.waterfall=fall
		var shore:=ShaderMaterial.new()
		shore.shader=load("res://shaders/terrain_editor/shore.gdshader")
		materials.shore=shore
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
	var start:=Time.get_ticks_usec()
	var count:=0
	var refreshed:=false
	if _build_queue.is_empty() and (_contour_revision!=data.revision or not data.dirty_chunks.is_empty()):
		refreshed=true
		_build_data=Data.new()
		_build_data.seed=data.seed
		for cell in data.cells:_build_data.cells[cell]=data.cells[cell].duplicate()
		contours.refresh(_build_data)
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
	while not _build_queue.is_empty() and count<max_chunks:
		_rebuild(_build_queue.pop_front())
		count+=1
	if (count>0 or refreshed) and _build_queue.is_empty():_publish()
	last_rebuild_ms=(Time.get_ticks_usec()-start)/1000.0 if count>0 else 0.0
	return count

func _rebuild(chunk:Vector2i)->void:
	var geometry:Dictionary=contours.build(chunk)
	_pending_chunks[chunk]=null
	_pending_faces.erase(chunk)
	_pending_bounds.erase(chunk)
	var faces:=PackedVector3Array()
	for kind in ["grass","cliff","water","waterfall","shore"]:faces.append_array(geometry[kind].get_faces())
	if not faces.is_empty():
		_pending_faces[chunk]=faces
		var bounds:=AABB(faces[0],Vector3.ZERO)
		for point in faces:bounds=bounds.expand(point)
		_pending_bounds[chunk]=bounds.grow(.001)
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
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key=="waterfall" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.add_child(instance)
	_pending_chunks[chunk]=node
	if decoration!=null:
		decoration.contours=contours
		decoration.populate(node,_build_data,chunk)
	rebuild_count+=1

func _discard_pending()->void:
	_pending_shore.clear()
	for node in _pending_chunks.values():
		if node!=null:node.free()
	_pending_chunks.clear()
	_pending_faces.clear()
	_pending_bounds.clear()

func _publish()->void:
	# Keep the previous complete revision visible until the next one is ready.
	# Meshes, decoration, picking and supported props switch in the same frame.
	for chunk in _pending_chunks:
		if chunks.has(chunk):
			var old:Node3D=chunks[chunk]
			remove_child(old)
			old.queue_free()
			chunks.erase(chunk)
		_pick_faces.erase(chunk)
		_pick_bounds.erase(chunk)
		var node:Node3D=_pending_chunks[chunk]
		if node!=null:
			add_child(node)
			chunks[chunk]=node
		if _pending_faces.has(chunk):
			_pick_faces[chunk]=_pending_faces[chunk]
			_pick_bounds[chunk]=_pending_bounds[chunk]
	_pending_chunks.clear()
	_pending_faces.clear()
	_pending_bounds.clear()
	_published_data=_build_data
	if not _pending_shore.is_empty():
		materials.water.set_shader_parameter("shore_field",_pending_shore.texture)
		materials.water.set_shader_parameter("shore_origin",_pending_shore.origin)
		materials.water.set_shader_parameter("shore_extent",_pending_shore.extent)
		_pending_shore.clear()
	props.sync(contours)
	mist.sync(contours.splash_points)

func _exit_tree()->void:_discard_pending()

func pending_chunk_count()->int:
	return _build_queue.size()+(data.dirty_chunks.size() if data!=null else 0)

func has_pending_updates()->bool:
	return data!=null and (not _build_queue.is_empty() or not data.dirty_chunks.is_empty() or _contour_revision!=data.revision)

func rebuild_all()->void:
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
	for chunk:Vector2i in _pick_faces:
		var box:AABB=_pick_bounds[chunk]
		if box.intersects_ray(ray_origin,direction)==null:continue
		var faces:PackedVector3Array=_pick_faces[chunk]
		for i in range(0,faces.size(),3):
			var hit:Variant=Geometry3D.ray_intersects_triangle(ray_origin,direction,faces[i],faces[i+1],faces[i+2])
			if hit==null:continue
			var distance:float=ray_origin.distance_squared_to(hit)
			if distance<nearest:nearest=distance;position_hit=hit
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
	return {"position":position_hit,"cell":cell}
