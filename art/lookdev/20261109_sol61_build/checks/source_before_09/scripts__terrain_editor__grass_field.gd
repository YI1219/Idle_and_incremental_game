extends RefCounted
## Short arching meadow leaves on the shared lawn. Built per chunk on the
## terrain worker thread from that chunk's lawn triangles: deterministic world-anchored
## wind-combed clusters, one packed MultiMesh buffer, no RenderingServer readbacks.
const Geometry=preload("res://scripts/terrain_editor/chunk_geometry.gd")
const PATHS=preload("res://scripts/terrain_editor/terrain_paths.gd")
## Clumps per square metre of flat lawn. Two-tier botanical meadow tuft: 4 plush base
## turf blades + 3 taller 3-segment swaying breeze-plume blades (~126 blades/m²).
const DENSITY:=28.0
const BLADES:=7
const PATH_CLEAR:=.54
static var _clump_mesh:ArrayMesh
static var _material:ShaderMaterial

static func _hash(x:float,y:float,salt:float)->float:
	return fposmod(sin(x*127.1+y*311.7+salt*74.7)*43758.5453,1.0)

static func _organic_drift(x:float,z:float)->float:
	var wx:=x+sin(z*.52)*.48
	var wz:=z+cos(x*.46)*.48
	var d1:=sin(wx*.78+wz*.51+1.3)*cos(wz*.69-wx*.43+.7)
	var d2:=sin(wx*1.63-wz*1.19+4.1)*cos(wz*1.41+wx*.97+2.6)
	return clampf(.5+.34*d1+.18*d2,0.0,1.0)

## Two-tier low meadow rosette:
## - 4 plush base blades (0.14–0.23m, 2 segments) form a velvety moss-grass carpet
## - 3 graceful taller plume blades (0.24–0.35m, 3 segments) rise in soft arches to catch rolling breeze waves!
## COLOR.r = height along blade (0..1), COLOR.g = per-blade tone, COLOR.b = per-blade flutter phase.
static func clump_mesh()->ArrayMesh:
	if _clump_mesh!=null:return _clump_mesh
	var surface:=Geometry.Surface.new()
	for blade:int in BLADES:
		var plume:bool=blade<3
		var angle:float=TAU*float(blade)/float(BLADES)+(_hash(blade,1.0,3.0)-.5)*.42
		var dir:=Vector3(cos(angle),0,sin(angle))
		var side:=Vector3(-dir.z,0,dir.x)
		var height:float=lerpf(.13,.21,_hash(blade,2,5)) if plume else lerpf(.07,.13,_hash(blade,2,5))
		var lean:float=lerpf(.12,.19,_hash(blade,3,7)) if plume else lerpf(.08,.14,_hash(blade,3,7))
		var width:float=lerpf(.022,.032,_hash(blade,4,9)) if plume else lerpf(.025,.036,_hash(blade,4,9))
		var radius:float=lerpf(.025,.075,_hash(blade,5,11))
		var root:Vector3=dir*radius
		var tone:float=clampf(_hash(blade,7,17)+(.12 if plume else -.04),0,1)
		var phase:float=_hash(blade,8,23)
		var segments:int=4 if plume else 3
		var previous:Array[Vector3]=[root-side*width,root+Vector3.UP*width*.18,root+side*width]
		var prev_t:float=0.0
		for segment:int in range(1,segments+1):
			var t:float=float(segment)/float(segments)
			var center:Vector3=root+dir*lean*pow(t,1.35)+Vector3.UP*height*sin(t*PI*.82)
			var w:float=width*pow(1.0-t*.985,.72)
			var row:Array[Vector3]=[center-side*w,center+Vector3.UP*w*.18,center+side*w]
			for half:int in 2:
				var side_a:float=float(half)-1.0
				var side_b:float=float(half)
				var n0a:Vector3=(Vector3.UP+dir*(.10+prev_t*.70)+side*side_a*.42).normalized()
				var n0b:Vector3=(Vector3.UP+dir*(.10+prev_t*.70)+side*side_b*.42).normalized()
				var n1a:Vector3=(Vector3.UP+dir*(.10+t*.70)+side*side_a*.42).normalized()
				var n1b:Vector3=(Vector3.UP+dir*(.10+t*.70)+side*side_b*.42).normalized()
				var c0:=Color(prev_t,tone,phase,1)
				var c1:=Color(t,tone,phase,1)
				for tri:Array in [[previous[half],previous[half+1],row[half+1],c0,c0,c1,n0a,n0b,n1b],[previous[half],row[half+1],row[half],c0,c1,c1,n0a,n1b,n1a]]:
					for vertex:int in 3:
						surface.vertices.append(tri[vertex]);surface.normals.append(tri[6+vertex])
						surface.colors.append(tri[3+vertex]);surface.uv.append(Vector2(float(blade),t))
			previous=row
			prev_t=t
	_clump_mesh=surface.mesh()
	_clump_mesh.custom_aabb=AABB(Vector3(-.45,-.05,-.45),Vector3(.90,.75,.90))
	return _clump_mesh

static func material()->ShaderMaterial:
	if _material==null:
		_material=ShaderMaterial.new()
		_material.shader=load("res://shaders/terrain_editor/grass_blades.gdshader")
	return _material

static func _path_dist(p:Vector2,route:Array)->float:
	var best:=1000.0
	for i in route.size()-1:
		best=minf(best,p.distance_to(Geometry2D.get_closest_point_to_segment(p,route[i],route[i+1])))
	return best

## Returns a detached MultiMeshInstance3D (or null) for one chunk's lawn mesh.
static func build(lawn:Mesh,chunk:Vector2i,blockers:Array=[])->MultiMeshInstance3D:
	if lawn==null or lawn.get_surface_count()==0:return null
	var arrays:Array=Geometry.arrays_of(lawn,0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] is PackedColorArray else PackedColorArray()
	var has_cols:bool=(colors.size()==vertices.size())
	var route:Array=PATHS.POINTS
	var buffer:=PackedFloat32Array()
	var count:=0
	for i in range(0,vertices.size(),3):
		var a:=vertices[i];var b:=vertices[i+1];var c:=vertices[i+2]
		var n:=(b-a).cross(c-a)
		var area:=n.length()*.5
		if area<.0005:continue
		var ny:=absf(n.normalized().y)
		var lip_triangle:bool=has_cols and minf(colors[i].g,minf(colors[i+1].g,colors[i+2].g))<.982
		if ny<(.58 if lip_triangle else .78):continue
		var lip_factor:=clampf(smoothstep(.78,.97,ny),0.42,1.0)
		var tri_s:=a.x*13.71+a.z*29.37+b.x*41.13+b.z*17.89+c.x*53.23+c.z*31.61
		var expected:=area*DENSITY*lerpf(.62,1.0,lip_factor)
		var whole:=int(expected)
		if _hash(tri_s,a.y+b.y+c.y,1.0)<expected-whole:whole+=1
		for k in whole:
			var u:=_hash(tri_s+float(k)*19.17,a.z*3.1+c.x*2.7,2.0)
			var v:=_hash(tri_s*0.73+float(k)*31.41,b.x*2.3+c.z*3.7,3.0)
			if u+v>1.0:u=1.0-u;v=1.0-v
			var w0:=1.0-u-v
			var soft_lip_sample:=false
			if has_cols:
				var ca:Color=colors[i];var cb:Color=colors[i+1];var cc:Color=colors[i+2]
				var col_a:=ca.a*w0+cb.a*u+cc.a*v
				var col_g:=ca.g*w0+cb.g*u+cc.g*v
				if col_a<.945 or col_g<.72:continue
				soft_lip_sample=col_g<.982
			var p:=a+(b-a)*u+(c-a)*v
			var p2:=Vector2(p.x,p.z)
			var rim_taper:=1.0
			if has_cols:
				var col_a_v:float=colors[i].a*w0+colors[i+1].a*u+colors[i+2].a*v
				rim_taper=clampf(smoothstep(.94,.996,col_a_v),.46,1.0)
			var d_path:=_path_dist(p2,route)
			if d_path<PATH_CLEAR:continue
			var path_taper:=clampf(smoothstep(PATH_CLEAR,PATH_CLEAR+.58,d_path),.55,1.0)
			var blocked:=false
			for blocker in blockers:
				if blocker is Rect2:
					if (blocker as Rect2).has_point(p2):blocked=true;break
				elif blocker is PackedVector2Array:
					if Geometry2D.is_point_in_polygon(p2,blocker as PackedVector2Array):blocked=true;break
				elif p2.distance_squared_to(Vector2(blocker.x,blocker.z))<blocker.y*blocker.y:blocked=true;break
			if blocked:continue
			var yaw:=_hash(p.x*2.13+p.z*.71,p.z*1.93-p.x*.83,4.0)*TAU
			var drift:=_organic_drift(p.x,p.z)
			var plume_drift:=smoothstep(.36,.88,drift)
			var scale:=lerpf(.86,1.20,_hash(p.z*1.7+p.x*.5,p.x*2.3,5.0))*lerpf(.88,1.16,drift)*lerpf(.72,1.0,lip_factor)*rim_taper*path_taper
			var h_scale:=scale*lerpf(.82,1.18,_hash(p.x*1.9,p.z*2.1+p.x*.3,6.0))*lerpf(.78,1.22,plume_drift)*lerpf(.46,1.0,lip_factor)*rim_taper*path_taper
			if soft_lip_sample:
				# Unequal little fans continue the meadow over its convex edge.
				# The interior field keeps its existing transforms and density.
				var edge_patch:=smoothstep(.20,.82,drift)
				scale*=lerpf(1.08,1.38,edge_patch)
				h_scale*=lerpf(1.30,1.72,edge_patch)
			var basis:=Basis(Vector3.UP,yaw).scaled(Vector3(scale,h_scale,scale))
			if soft_lip_sample:
				# Newly planted lip roots follow the rendered triangle, not the flat crown.
				var surface_up:=n.normalized()
				if surface_up.y<0.0:surface_up=-surface_up
				basis=Basis(Quaternion(Vector3.UP,surface_up))*basis
				p-=surface_up*.008
			buffer.append_array([basis.x.x,basis.y.x,basis.z.x,p.x,basis.x.y,basis.y.y,basis.z.y,p.y,basis.x.z,basis.y.z,basis.z.z,p.z])
			count+=1
	if count==0:return null
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.mesh=clump_mesh()
	mm.instance_count=count
	mm.buffer=buffer
	var instance:=MultiMeshInstance3D.new()
	instance.name="grass_blades"
	instance.multimesh=mm
	instance.material_override=material()
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end=110.0
	return instance
