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
	# Unequal overlapping core masses, then smaller edge clusters. Normalize
	# source bounds so the retained leaf mesh does not impose flat repeated tiers.
	var crown:Array=[
		[Vector3(-.29,.94,.10),Vector3(.77,.64,.77)],
		[Vector3(.28,1.02,.02),Vector3(.81,.69,.78)],
		[Vector3(-.10,1.22,-.08),Vector3(.68,.64,.70)],
		[Vector3(-.22,1.10,-.35),Vector3(.62,.60,.63)],
		[Vector3(.22,.90,.34),Vector3(.61,.57,.62)],
		[Vector3(-.14,.84,.29),Vector3(.61,.54,.62)],
		[Vector3(.27,1.21,-.25),Vector3(.48,.48,.52)],
	]
	for i in 10:
		var angle:=i*2.39996
		var radius:=.54+.07*sin(i*3.7)
		var center:=Vector3(cos(angle)*radius,1.02+.19*sin(i*2.1),sin(angle)*radius*.86)
		var size:=Vector3(.42+.07*sin(i*1.7),.43+.06*cos(i*2.3),.45+.07*cos(i*1.1))
		crown.append([center,size])
	for i in crown.size():
		var center:Vector3=crown[i][0]
		var size:Vector3=crown[i][1]
		var rotation:=Basis.from_euler(Vector3(.21*sin(i*1.9),i*1.031,.25*cos(i*2.7)))
		for part:Dictionary in leaf:
			var box:AABB=part.mesh.get_aabb()
			var basis:=rotation.scaled_local(size/box.size.max(Vector3.ONE*.0001))
			var pose:=Transform3D(basis,center-basis*(box.position+box.size*.5))
			var light:=clampf((center.y-.82)/.5,0.0,1.0)
			var tint:=Color(.84+.16*light+.04*sin(i*2.1),.94+.08*light+.035*cos(i*1.7),.90+.04*sin(i*.6),1)
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
					# Keep the retained stone's shoulders and crown facets. A hard
					# height clamp collapsed its upper faces into a thin paving slab.
					a.y=minf(a.y,.30)+maxf(a.y-.30,0.0)*.12
					b.y=minf(b.y,.30)+maxf(b.y-.30,0.0)*.12
					c.y=minf(c.y,.30)+maxf(c.y-.30,0.0)*.12
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
