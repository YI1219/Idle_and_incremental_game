class_name TerrainRenderer
extends Node3D
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Geometry=preload("res://scripts/terrain_editor/chunk_geometry.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Island=preload("res://scripts/terrain_editor/heightmap_island.gd")
var contours:=Contours.new()
var island:=Island.new()
## Heightmap mode never falls back to the explicitly selected legacy sculpt path.
var use_heightmap_shell:=true
var active_shell:="heightmap"
var _shell:RefCounted
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
## Matte gray mass sample. Restores the live materials and props when cleared.
var mass_sample:=false
var _sample_material:ShaderMaterial
var decoration:RefCounted
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
	for kind in ["grass","cliff","rim_green","shore","sculpted_terrain"]:
		if not materials.has(kind):continue
		materials[kind].set_shader_parameter("grass_compression",_grass_compression)
		materials[kind].set_shader_parameter("compression_origin",_compression_bounds.position)
		materials[kind].set_shader_parameter("compression_extent",_compression_bounds.size)


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
	for material in materials.values():preload("res://scripts/terrain_editor/material_detail.gd").bind(material)
	_quiet_blocks()
	_bind_grass_compression()
	for cell:Vector2i in data.cells:
		for z in range(-1,2):
			for x in range(-1,2):data.dirty_chunks[Data.chunk_of(cell+Vector2i(x,z))]=true

func _quiet_blocks()->void:
	# Large olive / soft-grey blocks. Fine tufts and stone grain stay available,
	# turned down so the masses read before the micro-noise.
	var grass_base:=Color(0.44,0.51,0.36)
	var grass_highlight:=Color(0.62,0.66,0.49)
	for kind in ["grass","shore","rim_green"]:
		if not materials.has(kind):continue
		materials[kind].set_shader_parameter("ground_fine_strength",0.22)
		materials[kind].set_shader_parameter("grass_base",grass_base)
		materials[kind].set_shader_parameter("grass_highlight",grass_highlight)
	if materials.has("grass"):materials.grass.set_shader_parameter("cover_relief",0.16)
	for kind in ["cliff","sculpted_rock","stone_mantle","lake_bed"]:
		if materials.has(kind):materials[kind].set_shader_parameter("stone_relief_strength",0.1)

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
		_build_data.rocks.samples=data.rocks.samples.duplicate()
		_build_data.sculpt_base_profile=data.sculpt_base_profile
		_build_data.sculpt_base_enabled=not use_heightmap_shell and data.sculpt_base_enabled and data.ensure_sculpt_base()
		if _build_data.sculpt_base_enabled:_build_data.rocks.base=data.rocks.base
		for cell in data.cells:_build_data.cells[cell]=data.cells[cell].duplicate()
		var heightmap:=use_heightmap_shell
		active_shell="heightmap" if heightmap else "contour"
		_shell=island if heightmap else contours
		if heightmap:
			island.refresh(_build_data)
		else:
			contours.refresh(_build_data)
		if decoration!=null:
			decoration.load_assets()
			decoration.omit_contour_columns=heightmap
			if heightmap:
				decoration._columns.clear()
				decoration._column_cells.clear()
				decoration._mass.clear()
				decoration._outcrops.clear()
				decoration._column_field=null
				decoration._column_key=Vector2i(-1,-1)
			else:
				decoration._column_layout(contours,_build_data.seed)
		_contour_revision=data.revision
		_discard_pending()
		_pending_shore=preload("res://scripts/terrain_editor/water_shore_field.gd").build(_build_data,_shell)
		# Shell refresh still regenerates the whole island. Reconstruct both old
		# and new owning chunks under the budget, including removed geometry.
		# The triangle index avoids scanning the whole island per chunk.
		for chunk in chunks:data.dirty_chunks[chunk]=true
		for chunk in _shell.triangle_chunks:data.dirty_chunks[chunk]=true
		_build_queue=data.dirty_chunks.keys()
		data.dirty_chunks.clear()
	while not _build_queue.is_empty() and count<max_chunks:
		_rebuild(_build_queue.pop_front())
		count+=1
	if (count>0 or refreshed) and _build_queue.is_empty():_publish()
	last_rebuild_ms=(Time.get_ticks_usec()-start)/1000.0 if count>0 else 0.0
	return count

func _rebuild(chunk:Vector2i)->void:
	var field=_shell if _shell!=null else contours
	var geometry:Dictionary=field.build(chunk)
	if field==contours and not contours.lawn_boundaries.is_empty():
		geometry.grass=preload("res://scripts/terrain_editor/rim_surface_detail.gd").lawn(geometry.grass,contours.lawn_boundaries,contours.water_regions,0.0)
	_pending_chunks[chunk]=null
	_pending_faces.erase(chunk)
	_pending_bounds.erase(chunk)
	var faces:=PackedVector3Array()
	for kind in ["grass","cliff","water","waterfall","shore","stone_mantle","sculpted_rock","sculpted_terrain"]:
		if geometry.has(kind):faces.append_array(geometry[kind].get_faces())
	if decoration!=null:
		for crown:Dictionary in decoration._columns:
			if Data.chunk_of(crown.cell)!=chunk:continue
			var drawn:Mesh=crown.get('render_mesh',decoration.assets[crown.kind][0].render_mesh)
			for point:Vector3 in drawn.get_faces():faces.append(crown.pose*point)
		for rock:Dictionary in decoration._outcrops:
			var at:=Vector2(rock.pose.origin.x,rock.pose.origin.z)
			if Data.chunk_of(Vector2i(at.floor()))!=chunk:continue
			for point:Vector3 in decoration.assets[rock.kind][0].mesh.get_faces():faces.append(rock.pose*point)
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
		if mass_sample and (key=="grass" or key=="cliff"):
			instance.material_override=_mass_sample_material()
		instance.visible=not mass_sample or key=="grass" or key=="cliff"
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key in ["water","waterfall"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		node.add_child(instance)
	_pending_chunks[chunk]=node
	if decoration!=null and not mass_sample:
		decoration.contours=field
		decoration.omit_contour_columns=active_shell=="heightmap"
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
	_start_morph(_published_data,_build_data)
	_published_data=_build_data
	if not _pending_shore.is_empty():
		materials.water.set_shader_parameter("shore_field",_pending_shore.texture)
		materials.water.set_shader_parameter("shore_origin",_pending_shore.origin)
		materials.water.set_shader_parameter("shore_extent",_pending_shore.extent)
		_pending_shore.clear()
	var field=_shell if _shell!=null else contours
	props.sync(field)
	mist.sync(field.splash_points,field.fall_veils)

func _exit_tree()->void:_discard_pending()

static func _tops(source:Data)->Dictionary:
	var result:Dictionary={}
	if source==null:return result
	for cell:Vector2i in source.cells:
		var record:Dictionary=source.cells[cell]
		result[cell]=record.water*.5 if record.water>=0 else float(record.height)
	return result

static func morph_ease(t:float)->float:
	var u:=clampf(t,0.0,1.0)-1.0
	return 1.0+2.2*u*u*u+1.2*u*u

func shown_top(cell:Vector2i)->float:
	if not _morph_to.has(cell):return NAN
	return lerpf(_morph_from.get(cell,float(_morph_to[cell])-MORPH_RISE),float(_morph_to[cell]),morph_ease(morph_progress))

func _start_morph(previous:Data,next:Data)->void:
	var to:=_tops(next)
	var snap:=_snap_next or previous==null or not animate_edits
	_snap_next=false
	var from:Dictionary={}
	var changed:=false
	if not snap:
		for cell:Vector2i in to:
			var shown:=shown_top(cell)
			if is_nan(shown):changed=true
			else:
				from[cell]=shown
				if absf(shown-float(to[cell]))>.001:changed=true
	_morph_to=to
	if snap or not changed:
		morph_progress=1.0
		_morph_from=to.duplicate()
		RenderingServer.global_shader_parameter_set("terrain_morph_progress",1.0)
		return
	_morph_from=from
	var lo:=Vector2i(1<<20,1<<20)
	var hi:=-lo
	for cell:Vector2i in to:
		lo=Vector2i(mini(lo.x,cell.x),mini(lo.y,cell.y))
		hi=Vector2i(maxi(hi.x,cell.x),maxi(hi.y,cell.y))
	lo-=Vector2i(4,4)
	hi+=Vector2i(4,4)
	var size:=hi-lo+Vector2i.ONE
	var image:=Image.create(size.x,size.y,false,Image.FORMAT_RGF)
	var known:Dictionary={}
	for cell:Vector2i in to:
		var pair:=Color(float(from.get(cell,float(to[cell])-MORPH_RISE)),float(to[cell]),0,0)
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

func pending_chunk_count()->int:
	return _build_queue.size()+(data.dirty_chunks.size() if data!=null else 0)

func has_pending_updates()->bool:
	return data!=null and (not _build_queue.is_empty() or not data.dirty_chunks.is_empty() or _contour_revision!=data.revision)

func set_mass_sample(enabled:bool)->void:
	mass_sample=enabled
	if props!=null:
		props.visible=not enabled
	rebuild_all()

func _mass_sample_material()->ShaderMaterial:
	if _sample_material==null:
		_sample_material=ShaderMaterial.new()
		_sample_material.shader=load("res://shaders/terrain_editor/mass_sample.gdshader")
	return _sample_material

func rebuild_all()->void:
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
