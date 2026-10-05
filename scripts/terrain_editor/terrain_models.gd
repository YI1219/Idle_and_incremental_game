class_name TerrainModels
extends RefCounted
## CC0 model parts and material palette. Canopies assemble existing oak mesh modules.
var assets:Dictionary={}
const IDS={"grass":"grass_large","bush":"tree_oak","surface_rock":"stone_largeA","cliff_rock":"stone_largeA","shore_rock":"stone_largeD","path":"stone_smallFlatA","fence":"fence_simple","reeds":"plant_flatTall","lily":"lily_large","flower":"flower_yellowA","vine":"tree_oak"}
func load_assets()->void:
	if not assets.is_empty():return
	for kind in IDS:assets[kind]=_load(IDS[kind],kind)
	var wood:Array=_load("tree_detailed","tree_wood")
	var leaf:Array=_load("tree_oak","tree_leaf")
	var tree:Array=[]
	var wood_shape:=Transform3D(Basis.IDENTITY.scaled(Vector3(1.24,1.07,1.24)),Vector3.ZERO)
	for part:Dictionary in wood:tree.append({"mesh":part.mesh,"pose":wood_shape*part.pose})
	for i in 14:
		var angle:=i*2.39996
		var radius:=.43+.09*sin(i*4.1)
		var center:=Vector3(cos(angle)*radius,.92+.13*sin(i*2.7)+.07*cos(i*.79),sin(angle)*radius*.82)
		var size:=Vector3(.82+.10*sin(i*1.7),.72+.08*cos(i*2.3),.88+.10*cos(i*1.1))
		if i==12:
			center=Vector3(.08,1.30,-.03)
			size=Vector3(.98,.76,.96)
		if i==13:
			center=Vector3(-.05,1.05,.04)
			size=Vector3(1.08,.84,1.04)
		center=Vector3(center.x*1.12,(center.y+.18)*.84,center.z*1.12)
		for part:Dictionary in leaf:
			var box:AABB=part.mesh.get_aabb()
			var basis:=Basis(Vector3.UP,angle*.43).scaled(size*Vector3(1.12,.756,1.12))
			var pose:=Transform3D(basis,center-basis*(box.position+box.size*.5))
			var tint:=Color(.94+.08*sin(i*2.1),.98+.045*cos(i*1.7),.94+.06*sin(i*.6),1)
			tree.append({"mesh":part.mesh,"pose":pose,"tint":tint})
	assets.tree=tree
	var spray:Array=[]
	for spec in [[Vector3(-.24,.17,0),-.65],[Vector3(.22,.28,.03),.65],[Vector3(-.04,.05,.06),-.1]]:
		for part:Dictionary in assets.vine:
			var box:AABB=part.mesh.get_aabb()
			var basis:=Basis(Vector3.FORWARD,float(spec[1])).scaled_local(Vector3(.62,.64,.25))
			var pose:=Transform3D(basis,spec[0]-basis*(box.position+box.size*.5))
			spray.append({"mesh":part.mesh,"pose":pose})
	assets.vine=spray
	for kind in assets:assets[kind]=[_merge(assets[kind])]
	# Apply after merging, which intentionally replaces individual source materials.
	var rock_material:=ShaderMaterial.new()
	rock_material.shader=load("res://shaders/terrain_editor/cliff_rock.gdshader")
	assets.cliff_rock[0].mesh.surface_set_material(0,rock_material)

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
			elif kind in ["surface_rock","cliff_rock","shore_rock","path"]:tint=Color("b6b8b1")
			elif kind=="tree_leaf" or kind=="bush":tint=Color("a4bb45")
			elif kind=="vine":tint=Color("668837")
			elif kind=="grass" or kind=="reeds":tint=Color("b3c541")
			elif kind=="lily":tint=Color("abc444")
			elif kind=="flower":tint=Color("e4d46d") if name_value.contains("yellow") else Color("8d9d36")
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			var count:=indices.size() if not indices.is_empty() else vertices.size()
			# GLTF material surfaces can share a vertex buffer with the trunk.
			# Only vertices referenced by this surface define its leaf bounds.
			var leaf_box:=AABB(vertices[indices[0] if not indices.is_empty() else 0],Vector3.ZERO)
			for i in count:leaf_box=leaf_box.expand(vertices[indices[i] if not indices.is_empty() else i])
			var mesh:=ArrayMesh.new()
			var builder=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
			for i in range(0,count,3):
				var a:=vertices[indices[i] if not indices.is_empty() else i]
				var b:=vertices[indices[i+1] if not indices.is_empty() else i+1]
				var c:=vertices[indices[i+2] if not indices.is_empty() else i+2]
				if kind=="tree_wood":
					a=_lift_branches(a);b=_lift_branches(b);c=_lift_branches(c)
				if kind=="shore_rock":
					a.y=minf(a.y,.27);b.y=minf(b.y,.27);c.y=minf(c.y,.27)
				var shade:=.90+.13*sin((a.x+b.x+c.x)*12.13+(a.y+b.y+c.y)*8.17+(a.z+b.z+c.z)*4.7)
				if kind=="shore_rock":shade=.97+.04*sin((a.x+b.x+c.x)*6.13+(a.z+b.z+c.z)*3.7)
				if kind in ["tree_leaf","bush","vine"]:shade=.97+.07*sin((a.x+b.x+c.x)*12.13+(a.y+b.y+c.y)*8.17+(a.z+b.z+c.z)*4.7)
				var color:=Color(tint.r*shade,tint.g*shade,tint.b*shade,1)
				if kind in ["tree_leaf","bush","vine"]:
					var box:AABB=leaf_box
					var ab:=(a+b)*.5
					var bc:=(b+c)*.5
					var ca:=(c+a)*.5
					var faces:=[[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]]
					for face in faces:
						var blend:=.48 if kind=="tree_leaf" else .68
						builder.triangle(_round_leaf(face[0],box,blend),_round_leaf(face[1],box,blend),_round_leaf(face[2],box,blend),color)
				else:builder.triangle(a,b,c,color)

			mesh=builder.mesh()
			var material:=StandardMaterial3D.new()
			material.vertex_color_use_as_albedo=true
			material.vertex_color_is_srgb=true
			material.roughness=.95
			mesh.surface_set_material(0,material)
			if kind in ["bush","vine"]:
				var box:=mesh.get_aabb()
				pose.origin=Vector3(-box.position.x-box.size.x*.5,-box.position.y,-box.position.z-box.size.z*.5)
			parts.append({"mesh":mesh,"pose":pose})
	for child in node.get_children():_extract(child,pose,parts,kind)

func _merge(parts:Array)->Dictionary:
	var builder=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	for part:Dictionary in parts:
		var arrays:Array=part.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		for i in range(0,vertices.size(),3):builder.triangle(part.pose*vertices[i],part.pose*vertices[i+1],part.pose*vertices[i+2],colors[i]*part.get("tint",Color.WHITE))
	var mesh:ArrayMesh=builder.mesh()
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.vertex_color_is_srgb=true
	material.roughness=.95
	mesh.surface_set_material(0,material)
	return {"mesh":mesh,"pose":Transform3D.IDENTITY}

func _lift_branches(point:Vector3)->Vector3:
	# Lift the two low forks of the retained CC0 detailed-tree mesh into the
	# raised crown. Base vertices at Y<=.18 stay fixed; shared vertices deform identically.
	var lift:=maxf(0,-point.z-.055)*1.50+maxf(0,point.x-.12)*.95
	point.y+=lift*smoothstep(.18,.35,point.y)
	return point

func _round_leaf(point:Vector3,box:AABB,blend:float=.68)->Vector3:
	# Derive a rounder faceted lobe from the existing CC0 leaf mesh. Source files
	# stay intact; one subdivision replaces its broad flat faces with smaller facets.
	var center:=box.position+box.size*.5
	var radius:=box.size*.5
	var unit:=(point-center)/radius.max(Vector3.ONE*.0001)
	var direction:=unit.normalized()
	var uneven:=1.0+.055*sin(direction.x*7.1+direction.y*4.3)*sin(direction.z*6.7-direction.y*3.1)
	return point.lerp(center+direction*radius*uneven,blend)
