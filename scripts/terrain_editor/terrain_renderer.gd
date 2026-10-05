class_name TerrainRenderer
extends Node3D
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Geometry=preload("res://scripts/terrain_editor/chunk_geometry.gd")
var data:Data
var chunks:Dictionary={}
var materials:Dictionary={}
var rebuild_count:=0
var last_rebuild_ms:=0.0
var decoration:RefCounted

func configure(source:Data)->void:
	data=source
	if materials.is_empty():
		var ground:=ShaderMaterial.new()
		ground.shader=load("res://shaders/terrain_editor/ground.gdshader")
		materials.grass=ground
		materials.cliff=_solid(Color.WHITE,true)
		materials.bank=_solid(Color("a9b29a"))
		var water:=ShaderMaterial.new()
		water.shader=load("res://shaders/terrain_editor/water.gdshader")
		materials.water=water
		var fall:=water.duplicate()
		fall.set_shader_parameter("fall",true)
		materials.waterfall=fall
	for cell:Vector2i in data.cells: data.dirty_chunks[Data.chunk_of(cell)]=true

func _solid(color:Color,vertex:bool=false)->StandardMaterial3D:
	var result:=StandardMaterial3D.new()
	result.albedo_color=color
	result.vertex_color_use_as_albedo=vertex
	result.roughness=0.95
	result.cull_mode=BaseMaterial3D.CULL_DISABLED
	return result

func flush_dirty(max_chunks:int=2)->int:
	if data==null:return 0
	var start:=Time.get_ticks_usec()
	var count:=0
	for chunk:Vector2i in data.dirty_chunks.keys():
		if count>=max_chunks:break
		data.dirty_chunks.erase(chunk)
		_rebuild(chunk)
		count+=1
	last_rebuild_ms=(Time.get_ticks_usec()-start)/1000.0 if count>0 else 0.0
	return count

func _rebuild(chunk:Vector2i)->void:
	if chunks.has(chunk):
		var old:Node3D=chunks[chunk]
		remove_child(old)
		old.queue_free()
		chunks.erase(chunk)
	var geometry:Dictionary=Geometry.build(data,chunk)
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
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(instance)
	add_child(node)
	chunks[chunk]=node
	if decoration!=null:decoration.populate(node,data,chunk)
	rebuild_count+=1

func rebuild_all()->void:
	for chunk in chunks:data.dirty_chunks[chunk]=true
	for cell:Vector2i in data.cells:data.dirty_chunks[Data.chunk_of(cell)]=true
	flush_dirty(data.dirty_chunks.size())

func pick(ray_origin:Vector3,ray_direction:Vector3)->Dictionary:
	if data==null or ray_direction.length_squared()<0.001:return {}
	var direction:=ray_direction.normalized()
	# Exact grid traversal: sampling the ray can skip narrow corner crossings.
	var cell:=Vector2i(floori(ray_origin.x),floori(ray_origin.z))
	var step_x:=1 if direction.x>0 else -1
	var step_z:=1 if direction.z>0 else -1
	var delta_x:=absf(1.0/direction.x) if absf(direction.x)>0.000001 else INF
	var delta_z:=absf(1.0/direction.z) if absf(direction.z)>0.000001 else INF
	var next_x:=((cell.x+1 if step_x>0 else cell.x)-ray_origin.x)/direction.x if is_finite(delta_x) else INF
	var next_z:=((cell.y+1 if step_z>0 else cell.y)-ray_origin.z)/direction.z if is_finite(delta_z) else INF
	var distance:=0.0
	while distance<=500.0:
		if data.cells.has(cell):
			var record:Dictionary=data.cells[cell]
			var top:float=record.water*0.5 if record.water>=0 else record.height
			var box:=AABB(Vector3(cell.x,Geometry.BOTTOM,cell.y),Vector3(1,top-Geometry.BOTTOM,1))
			var hit:Variant=box.intersects_ray(ray_origin,direction)
			if hit is Vector3:return {"position":hit,"cell":cell}
		if not is_finite(next_x) and not is_finite(next_z):break
		if next_x<next_z:
			distance=next_x
			next_x+=delta_x
			cell.x+=step_x
		elif next_z<next_x:
			distance=next_z
			next_z+=delta_z
			cell.y+=step_z
		else:
			distance=next_x
			next_x+=delta_x
			next_z+=delta_z
			cell+=Vector2i(step_x,step_z)
	return {}
