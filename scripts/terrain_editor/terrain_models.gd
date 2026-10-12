class_name TerrainModels
extends RefCounted
## CC0 model parts and material palette. Canopies assemble existing oak mesh modules.
var assets:Dictionary={}
## Microseconds to bake the six rim/underside block meshes. They are instanced after that.
var block_bake_us:=0
const IDS={"bush":"tree_oak","surface_rock":"stone_largeA","cliff_rock":"stone_largeA","shore_rock":"stone_largeD","shore_boulder":"stone_largeB","shore_pebble":"stone_largeA","path":"stone_smallFlatA","fence":"fence_simple","reeds":"plant_flatTall","lily":"lily_large","flower":"flower_yellowA","vine":"tree_oak"}
func load_assets()->void:
	if not assets.is_empty():return
	for kind in IDS:assets[kind]=_load(IDS[kind],kind)
	assets.bush=_shrub_clusters(assets.bush)
	assets.grass=_grass_models()
	assets.grass_clump=_grass_clump_models()
	assets.turf=_turf_models()
	assets.reeds=_reed_models()
	assets.lily=_lily_models()
	assets.path=_path_models()
	# Four carved crowns and two tapered roots. Closed procedural solids, baked once.
	var bake:=Time.get_ticks_usec()
	assets.cliff_column=_rock_body_models(11)
	assets.cliff_column_b=_rock_body_models(23)
	assets.cliff_column_c=_rock_body_models(37)
	assets.cliff_column_d=_rock_body_models(41)
	assets.underside_rock=_rock_body_models(53,true)
	assets.underside_rock_b=_rock_body_models(67,true)
	block_bake_us=Time.get_ticks_usec()-bake
	var wood:Array=_load("tree_detailed","tree_wood")
	var leaf:Array=_load("tree_oak","tree_leaf")
	var tree:Array=[]
	var wood_shape:=Transform3D(Basis.IDENTITY.scaled(Vector3(1.24,1.07,1.24)),Vector3.ZERO)
	for part:Dictionary in wood:tree.append({"mesh":part.mesh,"pose":wood_shape*part.pose})
	# Four compact masses derive from the retained oak surface: a dominant
	# raised crown, unequal lower fork masses and a small rear support.
	# Their lower edges expose branch space rather than filling every shoulder.
	var crown:Array=[
		[Vector3(-.02,1.16,.01),Vector3(1.16,.66,.92)],
		[Vector3(-.50,1.04,-.06),Vector3(.82,.38,.68)],
		[Vector3(.48,1.03,.05),Vector3(.78,.36,.64)],
		[Vector3(.02,.99,-.30),Vector3(.56,.30,.50)],
	]
	var crown_parts:Array=[]
	for i in crown.size():
		var center:Vector3=crown[i][0]
		var size:Vector3=crown[i][1]
		var rotation:=Basis.from_euler(Vector3(.10*sin(i*1.9),i*.83,.10*cos(i*2.7)))
		for part:Dictionary in leaf:
			var box:AABB=part.mesh.get_aabb()
			var basis:=rotation.scaled_local(size/box.size.max(Vector3.ONE*.0001))
			var pose:=Transform3D(basis,center-basis*(box.position+box.size*.5))
			var tint:Color=[Color(1.0,1.02,.98),Color(.96,1.0,.96),Color(.98,1.01,.97),Color(.94,.98,.95)][i]
			crown_parts.append({"mesh":part.mesh,"pose":pose,"tint":tint})
	tree.append_array(_join_crown(crown_parts))
	assets.tree=tree
	var spray:Array=[]
	# Wide sage drapes. The old blades tapered to needles and read as spikes
	# against the grey cut; overlapping blunt leaves hang as one soft mass.
	var blades:Array=[
		[Vector3(0.00,-0.02,0.03),-0.10,Vector3(0.72,0.30,0.26)],
		[Vector3(-0.12,-0.08,0.02),-0.46,Vector3(0.60,0.26,0.22)],
		[Vector3(0.12,-0.10,0.02),0.42,Vector3(0.56,0.24,0.20)],
		[Vector3(-0.04,-0.16,0.016),-0.18,Vector3(0.50,0.20,0.18)],
		[Vector3(0.06,-0.18,0.016),0.22,Vector3(0.46,0.18,0.16)],
	]
	for i in blades.size():
		var spec:Array=blades[i]
		for part:Dictionary in assets.vine:
			var box:AABB=part.mesh.get_aabb()
			var basis:=Basis(Vector3.FORWARD,float(spec[1])).scaled_local(spec[2]/box.size.max(Vector3.ONE*.0001))
			var pose:=Transform3D(basis,spec[0]-basis*(box.position+box.size*.5))
			spray.append({"mesh":part.mesh,"pose":pose,"tint":Color(.98,1.02,.96,1)})
	assets.vine=spray
	for kind in assets:
		# Retain the curved grass mesh's UVs/normals and palette texture.
		if kind not in ["grass","grass_clump","turf","reeds","underside_rock","underside_rock_b","cliff_column","cliff_column_b","cliff_column_c","cliff_column_d"]:assets[kind]=[_merge(assets[kind])]
	# Apply after merging, which intentionally replaces individual source materials.
	var rock_material:=ShaderMaterial.new()
	rock_material.shader=load("res://shaders/terrain_editor/cliff_rock.gdshader")
	preload("res://scripts/terrain_editor/material_detail.gd").bind(rock_material)
	for kind in ["cliff_rock","surface_rock","shore_rock","shore_boulder","shore_pebble"]:
		var material:=rock_material.duplicate()
		material.set_shader_parameter("bank_stone",1.0 if kind.begins_with("shore_") else 0.0)
		assets[kind][0].mesh.surface_set_material(0,material)
	for kind in ["tree","bush","vine"]:
		if not assets.has(kind) or assets[kind].is_empty():continue
		var soft:=.84 if kind=="tree" else (.88 if kind=="bush" else .90)
		var belly:=.34 if kind=="tree" else (.22 if kind=="bush" else .10)
		var lift:=1.02 if kind=="tree" else (1.06 if kind=="bush" else 1.08)
		assets[kind][0].mesh.surface_set_material(0,_canopy_material(soft,belly,lift))

func _shrub_clusters(source:Array)->Array:
	# Assemble existing CC0 leaf parts into a low, unequal leafy group.
	# Ground each transformed part using its actual vertices, not its AABB.
	var clusters:Array=[
		[Vector2(-.08,.00),Vector3(.66,.42,.58)],
		[Vector2(.16,.02),Vector3(.58,.36,.52)],
		[Vector2(-.02,.08),Vector3(.46,.40,.42)],
		[Vector2(-.30,.06),Vector3(.34,.26,.32)],
		[Vector2(.24,-.12),Vector3(.32,.22,.30)],
	]
	var result:Array=[]
	for i in clusters.size():
		var center:Vector2=clusters[i][0]
		var size:Vector3=clusters[i][1]
		var rotation:=Basis.from_euler(Vector3(.12*sin(i*1.9),i*1.031,.16*cos(i*2.7)))
		for part:Dictionary in source:
			var box:AABB=part.mesh.get_aabb()
			var basis:=rotation.scaled_local(size/box.size.max(Vector3.ONE*.0001))
			var pose:=Transform3D(basis,Vector3(center.x,0,center.y)-basis*(box.position+box.size*.5))
			var vertices:PackedVector3Array=part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var lowest:=INF
			for point:Vector3 in vertices:lowest=minf(lowest,(pose*point).y)
			pose.origin.y-=lowest
			var tint:=Color(.87+.09*sin(i*2.1),.94+.06*cos(i*1.7),.98,1)
			result.append({"mesh":part.mesh,"pose":pose,"tint":tint})
	return result

func _join_crown(parts:Array)->Array:
	# The current oak source has one active foliage surface per arranged mass.
	# Preserve an unfamiliar source assembly rather than assume its indexing.
	if parts.size()!=4:return parts
	# One convex hull of the four masses was a faceted umbrella. Overlapping
	# rounded lobes keep every oak point inside some closed surface and break
	# that single gem outline into an irregular canopy.
	var gathered:Dictionary=_crown_points(parts)
	var masses:Array=_canopy_masses(gathered.points,gathered.shades)
	if masses.is_empty():return [_crown_hull(parts)]
	return masses

func _crown_points(parts:Array)->Dictionary:
	var points:=PackedVector3Array()
	var shades:=PackedColorArray()
	var seen:Dictionary={}
	for part:Dictionary in parts:
		var arrays:Array=part.mesh.surface_get_arrays(0)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		for i in vertices.size():
			var point:Vector3=part.pose*vertices[i]
			if seen.has(point):continue
			seen[point]=points.size()
			points.append(point)
			shades.append(colors[i]*part.get("tint",Color.WHITE))
	return {"points":points,"shades":shades}

func _canopy_masses(points:PackedVector3Array,shades:PackedColorArray)->Array:
	if points.size()<4:return []
	var center:=Vector3.ZERO
	var low:=INF
	var high:=-INF
	for point:Vector3 in points:
		center+=point
		low=minf(low,point.y)
		high=maxf(high,point.y)
	center/=points.size()
	var radius:=.15
	for point:Vector3 in points:radius=maxf(radius,Vector2(point.x-center.x,point.z-center.z).length())
	var span:=maxf(high-low,.25)
	# Shells centred on the oak cloud inflate into one ellipsoid. Each mass
	# owns a wedge and is pushed outward, so the union outline is lobed.
	var specs:Array=[
		{"ang":0.4,"push":.32,"rad":1.02,"y":.20,"ys":.70,"wedge":1.55,"tint":Color(.34,.45,.22),"spin":.3},
		{"ang":2.4,"push":.38,"rad":.98,"y":.36,"ys":.62,"wedge":1.45,"tint":Color(.40,.51,.26),"spin":1.5},
		{"ang":4.2,"push":.28,"rad":.96,"y":.12,"ys":.66,"wedge":1.50,"tint":Color(.36,.46,.23),"spin":2.3},
		{"ang":5.5,"push":.20,"rad":.74,"y":.60,"ys":.52,"wedge":1.35,"tint":Color(.45,.55,.29),"spin":3.2},
	]
	var lobes:Array=[]
	var covered:Dictionary={}
	for spec:Dictionary in specs:
		var ang:=float(spec.ang)
		var dir:=Vector3(cos(ang),0.0,sin(ang))
		var shell_c:=center+dir*radius*float(spec.push)
		shell_c.y=lerpf(low,high,float(spec.y))
		var indices:Array=[]
		for i in points.size():
			var offset:Vector3=points[i]-center
			var flat:=Vector2(offset.x,offset.z)
			var delta:=0.0 if flat.length()<.02 else absf(angle_difference(atan2(offset.z,offset.x),ang))
			if delta<=float(spec.wedge):
				indices.append(i)
				covered[i]=true
		if indices.size()<3:
			var nearest:=0
			var best:=INF
			for i in points.size():
				var dist:float=points[i].distance_squared_to(shell_c)
				if dist<best:best=dist;nearest=i
			indices=[nearest,nearest,nearest]
		var radii:=Vector3(radius*float(spec.rad),span*float(spec.ys)+.1,radius*float(spec.rad)*.9)
		var cloud:Dictionary=_shell(shell_c,radii,spec.tint,float(spec.spin))
		for index:int in indices:
			cloud.points.append(points[index])
			cloud.shades.append(spec.tint)
		var lobe:Dictionary=_hull_cloud(cloud)
		if not lobe.is_empty():lobes.append(lobe)
	var rest:Array=[]
	for i in points.size():
		if not covered.has(i):rest.append(i)
	if rest.size()>0:
		while rest.size()<3:rest.append(rest[0])
		var lobe:Dictionary=_fit_lobe(points,rest,Color(.38,.48,.25),1.16,.8,1.2,center,.2)
		if not lobe.is_empty():lobes.append(lobe)
	return lobes

func _fit_lobe(points:PackedVector3Array,indices:Array,tint:Color,margin:float,y_stretch:float,spin:float,pull:Vector3=Vector3.ZERO,pull_weight:float=0.0)->Dictionary:
	var center:=Vector3.ZERO
	for index:int in indices:center+=points[index]
	center/=indices.size()
	if pull_weight>0.0:center=center.lerp(pull,pull_weight)
	var extent:=Vector3(.08,.08,.08)
	for index:int in indices:
		var delta:Vector3=(points[index]-center).abs()
		extent.x=maxf(extent.x,delta.x)
		extent.y=maxf(extent.y,delta.y)
		extent.z=maxf(extent.z,delta.z)
	var scale:=1.0
	for index:int in indices:
		var delta:Vector3=points[index]-center
		var ellipse:=sqrt(pow(delta.x/extent.x,2.0)+pow(delta.y/extent.y,2.0)+pow(delta.z/extent.z,2.0))
		scale=maxf(scale,ellipse/.82)
	var radii:=extent*scale*margin
	radii.y*=y_stretch
	var cloud:Dictionary=_shell(center,radii,tint,spin)
	for index:int in indices:
		cloud.points.append(points[index])
		cloud.shades.append(tint)
	return _hull_cloud(cloud)

func _shell(center:Vector3,radii:Vector3,tint:Color,spin:float)->Dictionary:
	var points:=PackedVector3Array()
	var shades:=PackedColorArray()
	var rot:=Basis.from_euler(Vector3(spin*.12,spin,spin*.05))
	var lit:=Color(minf(tint.r*1.14,1.0),minf(tint.g*1.08,1.0),minf(tint.b*.98,1.0))
	for dir:Vector3 in _ico_dirs(2):
		# Low-frequency scallop. The convex hull keeps the mass closed; the
		# outline is no longer a perfect ellipsoid.
		var horizontal:=1.0-absf(dir.y)
		var lobe:=absf(sin(dir.x*2.4+spin*1.6))*absf(sin(dir.z*2.1-spin*.7))
		var wobble:=lerpf(1.0,.80+.30*lobe,horizontal)
		var lifted:=0.94+.06*lobe
		points.append(center+rot*Vector3(dir.x*radii.x*wobble,dir.y*radii.y*lifted,dir.z*radii.z*wobble))
		shades.append(tint.lerp(lit,clampf(dir.y*.5+.5,0.0,1.0)*.6))
	return {"points":points,"shades":shades}

func _ico_dirs(subdiv:int)->PackedVector3Array:
	var phi:=(1.0+sqrt(5.0))*.5
	var verts:Array=[
		Vector3(-1,phi,0),Vector3(1,phi,0),Vector3(-1,-phi,0),Vector3(1,-phi,0),
		Vector3(0,-1,phi),Vector3(0,1,phi),Vector3(0,-1,-phi),Vector3(0,1,-phi),
		Vector3(phi,0,-1),Vector3(phi,0,1),Vector3(-phi,0,-1),Vector3(-phi,0,1),
	]
	var faces:Array=[
		[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],
		[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],
		[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],
		[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1],
	]
	for _step in subdiv:
		var cache:Dictionary={}
		var next:Array=[]
		for face:Array in faces:
			var ab:int=_ico_mid(verts,cache,face[0],face[1])
			var bc:int=_ico_mid(verts,cache,face[1],face[2])
			var ca:int=_ico_mid(verts,cache,face[2],face[0])
			next.append([face[0],ab,ca])
			next.append([face[1],bc,ab])
			next.append([face[2],ca,bc])
			next.append([ab,bc,ca])
		faces=next
	var dirs:=PackedVector3Array()
	for point:Vector3 in verts:dirs.append(point.normalized())
	return dirs

func _ico_mid(verts:Array,cache:Dictionary,i:int,j:int)->int:
	var key:=mini(i,j)*8192+maxi(i,j)
	if cache.has(key):return int(cache[key])
	var point:Vector3=((verts[i] as Vector3)+(verts[j] as Vector3)).normalized()
	var id:=verts.size()
	verts.append(point)
	cache[key]=id
	return id

func _crown_hull(parts:Array)->Dictionary:
	var gathered:Dictionary=_crown_points(parts)
	var hull:Dictionary=_hull_cloud(gathered)
	if hull.is_empty():return _merge(parts)
	return hull

func _hull_cloud(cloud:Dictionary)->Dictionary:
	var points:PackedVector3Array=cloud.points
	var shades:PackedColorArray=cloud.shades
	if points.size()<4:return {}
	# The native convex shape provides an indexed solid surface alongside its
	# debug lines. Copy only the solid triangles into the render resource.
	var shape:=ConvexPolygonShape3D.new()
	shape.points=points
	var hull:Mesh=shape.get_debug_mesh()
	var builder=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	for surface in hull.get_surface_count():
		if hull.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:continue
		var arrays:Array=hull.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
		var count:int=indices.size() if not indices.is_empty() else vertices.size()
		var center:=Vector3.ZERO
		for vertex:Vector3 in vertices:center+=vertex
		center/=vertices.size()
		var inflation:=1.0
		for i in range(0,count,3):
			var a:int=indices[i] if not indices.is_empty() else i
			var b:int=indices[i+1] if not indices.is_empty() else i+1
			var c:int=indices[i+2] if not indices.is_empty() else i+2
			var normal:Vector3=-(vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).normalized()
			var distance:float=normal.dot(vertices[a]-center)
			if distance<=.00001:continue
			for point:Vector3 in points:inflation=maxf(inflation,normal.dot(point-center)/distance)
		if inflation>1.0:
			for i in vertices.size():vertices[i]=center+(vertices[i]-center)*(inflation+.000001)
		var hull_shades:=PackedColorArray()
		for vertex:Vector3 in vertices:
			var nearest:=0;var distance:=INF
			for i in points.size():
				var candidate:float=vertex.distance_squared_to(points[i])
				if candidate<distance:nearest=i;distance=candidate
			hull_shades.append(shades[nearest])
		for i in range(0,count,3):
			var a:int=indices[i] if not indices.is_empty() else i
			var b:int=indices[i+1] if not indices.is_empty() else i+1
			var c:int=indices[i+2] if not indices.is_empty() else i+2
			builder.triangle(vertices[a],vertices[b],vertices[c],(hull_shades[a]+hull_shades[b]+hull_shades[c])/3.0)
	if builder.vertices.is_empty():return {}
	return {"mesh":builder.mesh(),"pose":Transform3D.IDENTITY}

func _canopy_material(soft:float,belly:float,lift:float=1.0)->ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=load("res://shaders/terrain_editor/canopy.gdshader")
	material.set_shader_parameter("foliage_soft",soft)
	material.set_shader_parameter("foliage_belly",belly)
	material.set_shader_parameter("foliage_lift",lift)
	return material

func _push_turf(vertices:PackedVector3Array,normals:PackedVector3Array,colors:PackedColorArray,uv:PackedVector2Array,a:Vector3,b:Vector3,c:Vector3,ua:float,ub:float,uc:float)->void:
	var facing:=(b-a).cross(c-a)
	if facing.y<0.0:facing=-facing
	# Almost upward. The pad is only a few millimetres tall, and a facet
	# normal would redraw that thickness as a shard.
	var normal:=Vector3.UP if facing.length_squared()<1e-10 else facing.normalized().lerp(Vector3.UP,.92).normalized()
	var white:=Color(1,1,1,1)
	vertices.append(a);vertices.append(b);vertices.append(c)
	normals.append(normal);normals.append(normal);normals.append(normal)
	colors.append(white);colors.append(white);colors.append(white)
	uv.append(Vector2(.5,ua));uv.append(Vector2(.5,ub));uv.append(Vector2(.5,uc))

func _turf_pad(vertices:PackedVector3Array,normals:PackedVector3Array,colors:PackedColorArray,uv:PackedVector2Array,center:Vector3,radius:float,height:float,spin:float,sx:float,sz:float)->void:
	# A wide, lobed sheet a millimetre proud of the sod. The outline is not
	# a disc, so a close crop does not read a pad tile.
	var sides:=16
	var rings:=4
	var pts:Array=[]
	for ring in rings:
		var t:=float(ring)/float(rings-1)
		var y:=height*pow(cos(t*PI*0.5),2.0)
		var rad:=radius*t
		var ring_pts:Array[Vector3]=[]
		var count:=1 if ring==0 else sides
		for i in count:
			var angle:=spin+TAU*float(i)/float(sides)
			var wobble:=1.0
			if ring==rings-1:wobble=.62+.42*absf(sin(float(i)*2.15+spin*2.4))
			ring_pts.append(center+Vector3(cos(angle)*rad*wobble*sx,y,sin(angle)*rad*wobble*sz))
		pts.append(ring_pts)
	for ring in range(rings-1):
		var inner:Array=pts[ring]
		var outer:Array=pts[ring+1]
		if inner.size()==1:
			var uy:=clampf(inner[0].y/height,0.0,1.0)
			for i in outer.size():
				var j:=(i+1)%outer.size()
				_push_turf(vertices,normals,colors,uv,inner[0],outer[i],outer[j],uy,clampf(outer[i].y/height,0.0,1.0),clampf(outer[j].y/height,0.0,1.0))
		else:
			for i in outer.size():
				var j:=(i+1)%outer.size()
				var ui:=clampf(inner[i].y/height,0.0,1.0)
				var uj:=clampf(inner[j].y/height,0.0,1.0)
				var oi:=clampf(outer[i].y/height,0.0,1.0)
				var oj:=clampf(outer[j].y/height,0.0,1.0)
				_push_turf(vertices,normals,colors,uv,inner[i],outer[i],outer[j],ui,oi,oj)
				_push_turf(vertices,normals,colors,uv,inner[i],outer[j],inner[j],ui,oj,uj)

func _turf_models()->Array:
	# Three overlapping pads make one soft clump. Neighbouring clumps overlap
	# into a carpet. Height stays a few millimetres so a close crop does not
	# resolve a faceted mound or an upright shard.
	var vertices:=PackedVector3Array()
	var normals:=PackedVector3Array()
	var colors:=PackedColorArray()
	var uv:=PackedVector2Array()
	_turf_pad(vertices,normals,colors,uv,Vector3(0.0,.0003,0.0),.072,.0010,.4,1.05,.78)
	_turf_pad(vertices,normals,colors,uv,Vector3(.028,.0002,.010),.046,.0008,1.7,.86,1.18)
	_turf_pad(vertices,normals,colors,uv,Vector3(-.024,.0002,.014),.042,.00075,2.8,1.22,.74)
	_turf_pad(vertices,normals,colors,uv,Vector3(.006,.00025,-.026),.038,.0007,4.2,.70,1.28)
	var arrays:Array=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_TEX_UV]=uv
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material:=ShaderMaterial.new()
	material.shader=load("res://shaders/terrain_editor/turf.gdshader")
	mesh.surface_set_material(0,material)
	return [{"mesh":mesh,"pose":Transform3D.IDENTITY}]

func _grass_clump_models()->Array:
	# Reuse the retained broad common blades as a low compact accent. Fine
	# wispy fans read as wiry noise at gameplay framing; source files stay intact.
	var parts:=_grass_models("Grass_Common_Short")
	for part:Dictionary in parts:
		var box:AABB=part.pose*part.mesh.get_aabb()
		var basis:=Basis.IDENTITY.scaled(Vector3(.85,.32,.75)/box.size.max(Vector3.ONE*.0001))
		var foot:=Vector3(box.position.x+box.size.x*.5,box.position.y,box.position.z+box.size.z*.5)
		part.pose=Transform3D(basis,-(basis*foot))*part.pose
		var material:ShaderMaterial=part.mesh.surface_get_material(0)
		material.set_shader_parameter("dark_color",Vector3(.17,.19,.12))
		material.set_shader_parameter("light_color",Vector3(.38,.39,.27))
	return parts

func _rock_body_models(seed_value:int,root:bool=false)->Array:
	# Crown and root use different fracture cuts; metadata supplies actual bounds.
	var built:Dictionary=preload("res://scripts/terrain_editor/procedural_stone.gd").build(seed_value,root)
	var mesh:ArrayMesh=built.mesh
	var material:=ShaderMaterial.new()
	material.shader=load("res://shaders/terrain_editor/cliff_column.gdshader")
	preload("res://scripts/terrain_editor/material_detail.gd").bind(material)
	material.set_shader_parameter("crown_cover",0.0 if root else 1.0)
	mesh.surface_set_material(0,material)
	built.render_mesh.surface_set_material(0,material)
	return [{"mesh":mesh,"render_mesh":built.render_mesh,"pose":Transform3D.IDENTITY,"body_height":built.height,"crown_z":built.crown_z,"span_x":built.span_x,"span_z":built.span_z}]


func _facing_triangle(builder,a:Vector3,b:Vector3,c:Vector3,color:Color,outward:Vector3)->void:
	var normal:=-(b-a).cross(c-a)
	if normal.dot(outward)<0.0:builder.triangle(a,c,b,color)
	else:builder.triangle(a,b,c,color)

func _facing_quad(builder,a:Vector3,b:Vector3,c:Vector3,d:Vector3,color:Color,outward:Vector3)->void:
	var normal:=-(b-a).cross(c-a)
	if normal.dot(outward)<0.0:builder.quad(a,d,c,b,color)
	else:builder.quad(a,b,c,d,color)

static func _block_shade(seed_value:int,salt:int)->Color:
	# Around the .66 grey the rim shader treats as an untinted facet.
	var value:int=(seed_value*374761393+salt*668265263)&0x7fffffff
	value=((value^(value>>13))*1274126177)&0x7fffffff
	var shade:=.58+.16*(float(value)/2147483647.0)
	return Color(shade,shade,shade,1)

static func _global_pose(node:Node,root:Node)->Transform3D:
	var pose:=Transform3D.IDENTITY
	var current:=node
	while current!=null and current!=root:
		if current is Node3D:pose=(current as Node3D).transform*pose
		current=current.get_parent()
	return pose

func _grass_models(id:String="Grass_Common_Short")->Array:
	var source:Node=load("res://assets/nature/quaternius/"+id+".gltf").instantiate()
	var parts:Array=[]
	_grass_parts(source,Transform3D.IDENTITY,parts)
	source.free()
	return parts

func _grass_parts(node:Node,parent:Transform3D,parts:Array)->void:
	var pose:=parent
	if node is Node3D:pose=parent*node.transform
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var mesh:=ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,node.mesh.surface_get_arrays(surface))
			var material:=ShaderMaterial.new()
			material.shader=load("res://shaders/terrain_editor/foliage.gdshader")
			material.set_shader_parameter("albedo_tex",load("res://assets/nature/quaternius/Grass.png"))
			mesh.surface_set_material(0,material)
			var grounded:=pose
			grounded.origin.y-=(pose*mesh.get_aabb()).position.y
			parts.append({"mesh":mesh,"pose":grounded})
	for child in node.get_children():_grass_parts(child,pose,parts)

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
			var tint:=Color("697547")
			if kind in ["tree_wood","fence"]:tint=Color("79634e") if not name_value.contains("Dark") else Color("615447")
			elif kind in ["surface_rock","cliff_rock","shore_rock","shore_boulder","shore_pebble","path"]:tint=Color("aaa89b")
			elif kind=="tree_leaf":tint=Color("697547")
			elif kind=="bush":tint=Color("73844e")
			elif kind=="vine":tint=Color("9cba86")
			elif kind=="grass" or kind=="reeds":tint=Color("939b72")
			elif kind=="lily":tint=Color("a8ad55")
			elif kind=="flower":tint=Color("e4d3b6") if name_value.to_lower().contains("yellow") else Color("7d8f62")
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
					a.y=minf(a.y,.30)+maxf(a.y-.30,0.0)*.72
					b.y=minf(b.y,.30)+maxf(b.y-.30,0.0)*.72
					c.y=minf(c.y,.30)+maxf(c.y-.30,0.0)*.72
				var shade:=.96+.04*sin((a.x+b.x+c.x)*12.13+(a.y+b.y+c.y)*8.17+(a.z+b.z+c.z)*4.7) if kind=="flower" else .90+.13*sin((a.x+b.x+c.x)*12.13+(a.y+b.y+c.y)*8.17+(a.z+b.z+c.z)*4.7)
				# Per-facet value steps keep shore stones faceted under soft light.
				if kind in ["shore_rock","shore_boulder","shore_pebble"]:shade=.91+.09*sin((a.x+b.x+c.x)*9.13+(a.y+b.y+c.y)*5.3+(a.z+b.z+c.z)*7.7)
				if kind=="tree_leaf":shade=.96+.06*sin((a.x+b.x+c.x)*6.2+(a.y+b.y+c.y)*4.1+(a.z+b.z+c.z)*3.4)
				elif kind in ["bush","vine"]:shade=.95+.07*sin((a.x+b.x+c.x)*8.4+(a.y+b.y+c.y)*5.2+(a.z+b.z+c.z)*3.8)
				var color:=Color(tint.r*shade,tint.g*shade,tint.b*shade,1)
				if kind=="flower" and name_value.to_lower().contains("yellow"):
					a=_flatten_bloom(a,leaf_box)
					b=_flatten_bloom(b,leaf_box)
					c=_flatten_bloom(c,leaf_box)
				if kind in ["tree_leaf","bush","vine"]:
					var box:AABB=leaf_box
					var ab:=(a+b)*.5
					var bc:=(b+c)*.5
					var ca:=(c+a)*.5
					var faces:=[[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]]
					for face in faces:
						var blend:=.76 if kind=="tree_leaf" else .70
						if kind=="vine":
							builder.triangle(_vine_leaf(face[0],box),_vine_leaf(face[1],box),_vine_leaf(face[2],box),color)
						else:
							var irregularity:=.035 if kind=="tree_leaf" else .03
							builder.triangle(_round_leaf(face[0],box,blend,irregularity),_round_leaf(face[1],box,blend,irregularity),_round_leaf(face[2],box,blend,irregularity),color)
				else:builder.triangle(a,b,c,color)

			mesh=builder.mesh()
			mesh.surface_set_material(0,_vertex_color_material())
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
	mesh.surface_set_material(0,_vertex_color_material())
	return {"mesh":mesh,"pose":Transform3D.IDENTITY}

func _lift_branches(point:Vector3)->Vector3:
	# Lift the two low forks of the retained CC0 detailed-tree mesh into the
	# raised crown. Base vertices at Y<=.18 stay fixed; shared vertices deform identically.
	var lift:=maxf(0,-point.z-.055)*1.80+maxf(0,point.x-.12)*1.35
	point.y+=lift*smoothstep(.18,.35,point.y)
	return point

func _round_leaf(point:Vector3,box:AABB,blend:float=.68,irregularity:float=.055)->Vector3:
	# Derive a rounder faceted lobe from the existing CC0 leaf mesh. Source files
	# stay intact; one subdivision replaces its broad flat faces with smaller facets.
	var center:=box.position+box.size*.5
	var radius:=box.size*.5
	var unit:=(point-center)/radius.max(Vector3.ONE*.0001)
	var direction:=unit.normalized()
	# Keep the lower branch-covering region stable while the upper crown
	# gains irregular planar shoulders. Default shrub/vine shape is unchanged.
	var strength:=lerpf(.055,irregularity,smoothstep(-.20,.35,direction.y))
	var uneven:=1.0+strength*sin(direction.x*7.1+direction.y*4.3)*sin(direction.z*6.7-direction.y*3.1)
	return point.lerp(center+direction*radius*uneven,blend)

func _flatten_bloom(point:Vector3,box:AABB)->Vector3:
	# The retained bloom is an upright faceted cup. Sit it in the nap as a
	# low petal so a close lawn does not read a row of stone stubs.
	var center:=box.get_center()
	var radius:=box.size*.5
	var unit:=(point-center)/radius.max(Vector3.ONE*.0001)
	var radial:=clampf(Vector2(unit.x,unit.z).length(),0.0,1.4)
	var y:=box.position.y+box.size.y*(.05+.09*(1.0-smoothstep(0.0,1.05,radial)))
	return Vector3(center.x+unit.x*radius.x*.9,y,center.z+unit.z*radius.z*.9)

func _vine_leaf(point:Vector3,box:AABB)->Vector3:
	var center:=box.position+box.size*.5
	var radius:=box.size*.5
	var leaf:=_round_leaf(point,box,.62)-center
	var along:=clampf((leaf.y+radius.y)/maxf(radius.y*2.0,.0001),0,1)
	# Squat pad. The oak leaf's corners still read as paper spikes on the cut.
	var unit:=leaf/radius.max(Vector3.ONE*.0001)
	var dir:=unit.normalized() if unit.length_squared()>1e-8 else Vector3.UP
	var uneven:=.94+.06*sin(dir.x*3.1+dir.z*2.4)
	return center+Vector3(dir.x*radius.x*uneven,dir.y*radius.y*.38,dir.z*radius.z*.76*uneven)

func _reed_models()->Array:
	# Soft bank tufts. Alpha-cut grass blades stayed as dark spikes in the
	# wallpaper read; short leaning ribbons share the olive nap instead.
	var surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	# Placement multiplies by about 3. These local sizes stay a low bank tuft,
	# not a spread of flat leaves and not a stand of spikes.
	for blade in 8:
		var yaw:=blade*.78+.15
		var dir:=Vector3(cos(yaw),0,sin(yaw))
		var right:=Vector3(-dir.z,0,dir.x)
		var lean:=.032+.012*float(blade%3)
		var height:=.048+.016*float(blade%4)
		var width:=.015+.005*float(blade%3)
		var segments:=4
		for segment in segments:
			var t0:=float(segment)/float(segments)
			var t1:=float(segment+1)/float(segments)
			var c0:=_reed_point(dir,lean,height,t0)
			var c1:=_reed_point(dir,lean,height,t1)
			var w0:=maxf(width*(1.0-.28*t0),width*.7)
			var w1:=maxf(width*(1.0-.28*t1),width*.7)
			var col:=Color(.40,.48,.26).lerp(Color(.50,.56,.32),t0)
			var a:=c0-right*w0
			var b:=c0+right*w0
			var c:=c1+right*w1
			var d:=c1-right*w1
			surface.quad(a,b,c,d,col)
			surface.quad(a,d,c,b,col)
	var mesh:ArrayMesh=surface.mesh()
	mesh.surface_set_material(0,_vertex_color_material())
	return [{"mesh":mesh,"pose":Transform3D.IDENTITY}]

func _reed_point(dir:Vector3,lean:float,height:float,t:float)->Vector3:
	var bow:=t*t
	return Vector3(dir.x*lean*bow,height*t*(1.0-.12*bow),dir.z*lean*bow)

func _lily_models()->Array:
	var surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	for pad in 5:
		var center:=Vector3(sin(pad*2.4)*.18,0,cos(pad*2.4)*.19)
		var radius:=.065+pad*.012
		for side in range(1,12):
			var a:=TAU*side/12.0+pad
			var b:=TAU*(side+1)/12.0+pad
			surface.triangle(center,center+Vector3(cos(a),0,sin(a))*radius,center+Vector3(cos(b),0,sin(b))*radius,Color("8a9a68"),true)
	var mesh:ArrayMesh=surface.mesh()
	return [{"mesh":mesh,"pose":Transform3D.IDENTITY}]

func _path_models()->Array:
	var surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	var top:=PackedVector3Array()
	var bottom:=PackedVector3Array()
	for i in 8:
		var a:=TAU*i/8.0
		var r:=.28*(1+.08*sin(i*2.7))
		top.append(Vector3(cos(a)*r,.065,sin(a)*r*.84))
		bottom.append(Vector3(cos(a)*(r+.018),0,sin(a)*(r+.018)*.84))
	for i in 8:
		var j:=(i+1)%8
		surface.triangle(Vector3(0,.065,0),top[i],top[j],Color("a4a18d"),true)
		surface.quad(top[j],top[i],bottom[i],bottom[j],Color("969384"))
	return [{"mesh":surface.mesh(),"pose":Transform3D.IDENTITY}]

static func _vertex_color_material()->ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/terrain_editor/decor_vertex_color.gdshader")
	return material
