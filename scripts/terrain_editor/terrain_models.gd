class_name TerrainModels
extends RefCounted
## CC0 model parts and material palette. Canopies assemble existing oak mesh modules.
var assets:Dictionary={}
const IDS={"grass":"grass_large","bush":"tree_oak","surface_rock":"stone_largeA","cliff_rock":"stone_largeD","shore_rock":"stone_largeB","path":"stone_smallFlatA","fence":"fence_simple","reeds":"plant_flatTall","lily":"lily_large","flower":"flower_yellowA","vine":"tree_oak"}
func load_assets()->void:
	if not assets.is_empty():return
	for kind in IDS:assets[kind]=_load(IDS[kind],kind)
	var wood:Array=_load("tree_detailed","tree_wood")
	var leaf:Array=_load("tree_oak","tree_leaf")
	var tree:Array=wood
	for i in 13:
		var angle:=i*2.39996
		var radius:=.56+.08*sin(i*4.1)
		var center:=Vector3(0,1.38,0) if i==12 else Vector3(cos(angle)*radius,.90+float(i%3)*.16+sin(i*2.7)*.07,sin(angle)*radius*.82)
		var size:=Vector3(.76,.62,.78) if i==12 else Vector3(.77+sin(i*1.7)*.08,.62,.79)
		for part:Dictionary in leaf:
			var box:AABB=part.mesh.get_aabb()
			var basis:=Basis(Vector3.UP,angle*.43).scaled(size)
			var pose:=Transform3D(basis,center-basis*(box.position+box.size*.5))
			tree.append({"mesh":part.mesh,"pose":pose})
	assets.tree=tree
	for kind in assets:assets[kind]=[_merge(assets[kind])]

func _load(id:String,kind:String)->Array:
	var document:=GLTFDocument.new()
	var state:=GLTFState.new()
	var path:="res://assets/nature/kenney/"+id+".glb"
	if document.append_from_file(path,state)!=OK:
		push_error("Cannot load CC0 model: "+path)
		return []
	var source:=document.generate_scene(state)
	var parts:Array=[]
	_extract(source,Transform3D.IDENTITY,parts,kind)
	source.free()
	return parts

func _extract(node:Node,parent:Transform3D,parts:Array,kind:String)->void:
	var pose:=parent
	if node is Node3D:pose=parent*node.transform
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var original:Material=node.get_active_material(surface)
			var name_value:String=original.resource_name if original else ""
			if kind=="tree_wood" and not name_value.contains("wood"):continue
			if kind=="tree_leaf" and not name_value.contains("leaf"):continue
			if kind in ["bush","vine"] and not name_value.contains("leaf"):continue
			var tint:=Color("839b39")
			if kind in ["tree_wood","fence"]:tint=Color("956844") if not name_value.contains("Dark") else Color("704d35")
			elif kind in ["surface_rock","cliff_rock","shore_rock","path"]:tint=Color("b5b5a3")
			elif kind=="tree_leaf" or kind=="bush":tint=Color("8ca73f")
			elif kind=="vine":tint=Color("668837")
			elif kind=="grass" or kind=="reeds":tint=Color("9baa36")
			elif kind=="lily":tint=Color("abc444")
			elif kind=="flower":tint=Color("e4d46d") if name_value.contains("yellow") else Color("8d9d36")
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var leaf_box:=AABB(vertices[0],Vector3.ZERO)
			for point in vertices:leaf_box=leaf_box.expand(point)
			var mesh:=ArrayMesh.new()
			var builder=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
			var count:=indices.size() if not indices.is_empty() else vertices.size()
			for i in range(0,count,3):
				var a:=vertices[indices[i] if not indices.is_empty() else i]
				var b:=vertices[indices[i+1] if not indices.is_empty() else i+1]
				var c:=vertices[indices[i+2] if not indices.is_empty() else i+2]
				var shade:=.90+.13*sin((a.x+b.x+c.x)*12.13+(a.y+b.y+c.y)*8.17+(a.z+b.z+c.z)*4.7)
				var color:=Color(tint.r*shade,tint.g*shade,tint.b*shade,1)
				if kind in ["tree_leaf","bush","vine"]:
					var box:AABB=leaf_box
					var ab:=(a+b)*.5
					var bc:=(b+c)*.5
					var ca:=(c+a)*.5
					for face in [[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]]:
						builder.triangle(_round_leaf(face[0],box),_round_leaf(face[1],box),_round_leaf(face[2],box),color)
				else:builder.triangle(a,b,c,color)

			mesh=builder.mesh()
			var material:=StandardMaterial3D.new()
			material.vertex_color_use_as_albedo=true
			material.vertex_color_is_srgb=true
			material.roughness=.95
			mesh.surface_set_material(0,material)
			if kind in ["bush","vine"]:
				var box:=mesh.get_aabb()
				pose.origin=-box.position
			parts.append({"mesh":mesh,"pose":pose})
	for child in node.get_children():_extract(child,pose,parts,kind)

func _merge(parts:Array)->Dictionary:
	var builder=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	for part:Dictionary in parts:
		var arrays:Array=part.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		for i in range(0,vertices.size(),3):builder.triangle(part.pose*vertices[i],part.pose*vertices[i+1],part.pose*vertices[i+2],colors[i])
	var mesh:ArrayMesh=builder.mesh()
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=true
	material.roughness=.95
	mesh.surface_set_material(0,material)
	return {"mesh":mesh,"pose":Transform3D.IDENTITY}

func _round_leaf(point:Vector3,box:AABB)->Vector3:
	# Derive a rounder faceted lobe from the existing CC0 leaf mesh. Source files
	# stay intact; one subdivision replaces its broad flat faces with smaller facets.
	var center:=box.position+box.size*.5
	var radius:=box.size*.5
	var unit:=(point-center)/radius.max(Vector3.ONE*.0001)
	return center+unit.normalized()*radius
