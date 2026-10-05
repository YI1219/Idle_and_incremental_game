class_name TerrainDecoration
extends RefCounted
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Geometry=preload("res://scripts/terrain_editor/chunk_geometry.gd")
const MODEL_IDS := {"grass":"Grass_Common_Short","bush":"Bush_Common","tree":"CommonTree_1","surface_rock":"Rock_Medium_1","cliff_rock":"Rock_Medium_2"}
var assets:Dictionary={}

static func random_at(cell:Vector2i,seed_value:int,salt:int)->float:
	var value:int=(cell.x*374761393+cell.y*668265263+seed_value*69069+salt*144269)&0x7fffffff
	value=((value^(value>>13))*1274126177)&0x7fffffff
	return float(value)/2147483647.0

func load_assets()->void:
	if not assets.is_empty():return
	for kind in MODEL_IDS:
		var document:=GLTFDocument.new()
		var state:=GLTFState.new()
		var path:String="res://assets/nature/quaternius/"+MODEL_IDS[kind]+".gltf"
		if document.append_from_file(path,state)!=OK:
			push_error("Cannot load free terrain model: "+path)
			continue
		var source:Node=document.generate_scene(state)
		var parts:Array=[]
		_extract(source,Transform3D.IDENTITY,parts)
		assets[kind]=parts
		source.free()

func _extract(node:Node,parent:Transform3D,parts:Array)->void:
	var pose:=parent
	if node is Node3D:pose=parent*node.transform
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var mesh:=ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,node.mesh.surface_get_arrays(index))
			var material:Material=node.get_active_material(index)
			if material!=null:
				material=material.duplicate()
				if material is StandardMaterial3D:
					material.roughness=0.94
					material.cull_mode=BaseMaterial3D.CULL_DISABLED
					material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
					if material.resource_name.begins_with("Leaves") and material.albedo_texture!=null:
						var foliage:=ShaderMaterial.new()
						foliage.shader=load("res://shaders/terrain_editor/foliage.gdshader")
						foliage.set_shader_parameter("albedo_tex",material.albedo_texture)
						material=foliage
			mesh.surface_set_material(0,material)
			parts.append({"mesh":mesh,"pose":pose})
	for child in node.get_children():_extract(child,pose,parts)

func placements(data:Data,chunk:Vector2i)->Dictionary:
	var result:Dictionary={}
	for kind in MODEL_IDS:result[kind]=[]
	for z in range(chunk.y*8,chunk.y*8+8):
		for x in range(chunk.x*8,chunk.x*8+8):
			var cell:=Vector2i(x,z)
			if not data.cells.has(cell):continue
			var record:Dictionary=data.cells[cell]
			var h:float=record.height
			var angle:=random_at(cell,data.seed,1)*TAU
			var p:=Vector3(x+0.25+random_at(cell,data.seed,2)*0.5,h,z+0.25+random_at(cell,data.seed,3)*0.5)
			if record.water<0:
				if random_at(cell,data.seed,4)<0.62:
					result.grass.append(_transform(p,angle,Vector3(0.45,0.29,0.45)))
				if random_at(cell,data.seed,5)<0.11:
					result.bush.append(_transform(p-Vector3(0,0.025,0),angle,Vector3.ONE*(0.38+random_at(cell,data.seed,6)*0.17)))
				if random_at(cell,data.seed,7)<0.08:
					result.surface_rock.append(_transform(p-Vector3(0,0.12,0),angle,Vector3(0.27,0.25,0.27)))
				if posmod(x,4)==1 and posmod(z,4)==1 and random_at(cell,data.seed,8)<0.5 and _stable_tree(data,cell):
					result.tree.append(_transform(p,angle,Vector3.ONE*(0.56+random_at(cell,data.seed,9)*0.14)))
			for side in 4:
				var offset:Vector2i=Geometry.SIDES[side]
				var neighbor:=cell+offset
				var low:float=data.cells[neighbor].height if data.cells.has(neighbor) else Geometry.BOTTOM
				if h-low<0.7:continue
				var bands:=maxi(1,floori((h-low)/1.7))
				for band in bands:
					if random_at(cell,data.seed,10+band*7+side)>0.68:continue
					var y:=lerpf(h-0.35,low+0.35,(band+0.25+random_at(cell,data.seed,77+side+band)*0.5)/bands)
					var origin:=Vector3(x+0.5,y,z+0.5)+Vector3(offset.x,0,offset.y)*0.32
					var tangent:=Vector3(-offset.y,0,offset.x)
					origin+=tangent*(random_at(cell,data.seed,91+side+band)-0.5)*0.5
					var size:=0.46+random_at(cell,data.seed,40+side+band)*0.22
					result.cliff_rock.append(_transform(origin,angle+side,Vector3(size,size*0.92,size)))
	return result

func _stable_tree(data:Data,cell:Vector2i)->bool:
	for offset in Geometry.SIDES:
		var other:Vector2i=cell+offset
		if not data.cells.has(other) or data.cells[other].water>=0 or data.cells[other].height!=data.cells[cell].height:return false
	return true

func _transform(origin:Vector3,angle:float,size:Vector3)->Transform3D:
	return Transform3D(Basis(Vector3.UP,angle).scaled(size),origin)

func populate(parent:Node3D,data:Data,chunk:Vector2i)->void:
	load_assets()
	var groups:=placements(data,chunk)
	for kind in groups:
		var transforms:Array=groups[kind]
		if transforms.is_empty() or not assets.has(kind):continue
		for part:Dictionary in assets[kind]:
			var mm:=MultiMesh.new()
			mm.transform_format=MultiMesh.TRANSFORM_3D
			mm.mesh=part.mesh
			mm.instance_count=transforms.size()
			for i in transforms.size():mm.set_instance_transform(i,transforms[i]*part.pose)
			var instance:=MultiMeshInstance3D.new()
			instance.name=kind
			instance.multimesh=mm
			instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(instance)
