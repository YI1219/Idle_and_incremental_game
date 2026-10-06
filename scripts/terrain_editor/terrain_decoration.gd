class_name TerrainDecoration
extends RefCounted
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Geometry=preload("res://scripts/terrain_editor/chunk_geometry.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Models=preload("res://scripts/terrain_editor/terrain_models.gd")
const COMMON_TREE_HEIGHT := 4.15
var model_library:=Models.new()
var assets:Dictionary={}
var contours:RefCounted
var _vine_center:=Vector3.ZERO
var _shrub_base:=PackedVector3Array()
static func random_at(cell:Vector2i,seed_value:int,salt:int)->float:
	var value:int=(cell.x*374761393+cell.y*668265263+seed_value*69069+salt*144269)&0x7fffffff
	value=((value^(value>>13))*1274126177)&0x7fffffff
	return float(value)/2147483647.0
func load_assets()->void:
	if not assets.is_empty():return
	model_library.load_assets()
	assets=model_library.assets
	var vertices:PackedVector3Array=assets.vine[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_vine_center=Vector3.ZERO
	for point:Vector3 in vertices:_vine_center+=point
	_vine_center/=vertices.size()
	var shrub:Mesh=assets.bush[0].mesh
	var box:AABB=shrub.get_aabb()
	var unique:Dictionary={}
	_shrub_base.clear()
	for point:Vector3 in shrub.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if point.y<=box.position.y+box.size.y*.08 and not unique.has(point):
			unique[point]=true
			_shrub_base.append(point)
func placements(data:Data,chunk:Vector2i)->Dictionary:
	if assets.is_empty():load_assets()
	var field=contours
	if field==null:field=Contours.new();field.refresh(data)
	var result:Dictionary={}
	for kind in ["grass","grass_clump","bush","tree","surface_rock","cliff_rock","shore_rock","path","fence","reeds","lily","flower","vine"]:result[kind]=[]
	for z in range(chunk.y*8,chunk.y*8+8):
		for x in range(chunk.x*8,chunk.x*8+8):
			var cell:=Vector2i(x,z)
			var p:=Vector2(x+.16+random_at(cell,data.seed,2)*.68,z+.16+random_at(cell,data.seed,3)*.68)
			var surface:Dictionary=field.surface_at(p)
			if surface.is_empty() or surface.water>=0:continue
			var h:float=surface.height
			var origin:=Vector3(p.x,h,p.y)
			var angle:=random_at(cell,data.seed,1)*TAU
			var cluster:=sin(p.x*.67+p.y*.31)*sin(p.y*.79-p.x*.18)
			var house_clear:=_near_path(p) or p.distance_to(Vector2(-11,-7))<2.4 or (p.x> -10.5 and p.x< -6.9 and p.y> -6.1 and p.y< -3.1)
			if not house_clear and cluster>.12 and random_at(cell,data.seed,4)<.38:
				for tuft in 1:
					var offset:=Vector2(random_at(cell,data.seed,110+tuft*2)-.5,random_at(cell,data.seed,111+tuft*2)-.5)*.75
					var ground:Dictionary=field.surface_at(p+offset)
					if ground.is_empty() or ground.water>=0 or absf(ground.height-h)>.01:continue
					if not _stable(field,p+offset,h,.18):continue
					result.grass.append(_transform(origin+Vector3(offset.x,0,offset.y),angle+tuft*2.4,Vector3(.70,.20,.70)*(.85+random_at(cell,data.seed,120+tuft)*.45)))
				if random_at(cell,data.seed,13)<.24:result.flower.append(_transform(origin,angle,Vector3.ONE*.9))
			if not house_clear and cluster>.22 and random_at(cell,data.seed,6)<.20:
				var pose:=_transform(origin-Vector3(0,.02,0),angle,Vector3(1.2,.85,1.2))
				if _supported_shrub(field,pose,h):result.bush.append(pose)
			if not house_clear and cluster>.26 and random_at(cell,data.seed,141)<.13 and _stable(field,p,h,.52):
				result.grass_clump.append(_transform(origin,angle,Vector3.ONE*(.85+random_at(cell,data.seed,142)*.25)))
			if not house_clear and cluster>.48 and random_at(cell,data.seed,140)<.026 and _stable(field,p,h,.65):
				result.grass_clump.append(_transform(origin,angle,Vector3(1.10,1.18,1.05)))
			if not house_clear and random_at(cell,data.seed,7)<.018:result.surface_rock.append(_transform(origin-Vector3(0,.11,0),angle,Vector3.ONE*1.7))
	# Composed trees are terrain-anchored modules, and disappear when their support is edited away.
	for spec in [[Vector2(-16,-3),Vector3(1.05,1.02,1.0)],[Vector2(-5,-8),Vector3(.96,.98,1.04)],[Vector2(6.3,-3.3),Vector3(1.0,1.0,.97)],[Vector2(15.6,2),Vector3(1.03,1.01,.96)]]:
		var p:Vector2=spec[0]
		if Data.chunk_of(Vector2i(p.floor()))!=chunk:continue
		var sample:Dictionary=field.surface_at(p)
		if sample.is_empty() or sample.water>=0:continue
		if not _stable(field,p,float(sample.height),.6):continue
		var box:AABB=assets.tree[0].mesh.get_aabb()
		var size:Vector3=spec[1]*(COMMON_TREE_HEIGHT/box.size.y)
		result.tree.append(_transform(Vector3(p.x,sample.height-box.position.y*size.y,p.y),p.x*.13,size))
	var foliage_anchors:Dictionary={}
	for h:float in field.land_regions:
		for loop:PackedVector2Array in field.land_regions[h]:
			for i in loop.size():
				var p:=loop[i]
				if Data.chunk_of(Vector2i(p.floor()))!=chunk:continue
				var cell:=Vector2i(p.floor())
				if random_at(cell,data.seed,80)>.90:continue
				var next:Vector2=loop[(i+1)%loop.size()]
				var previous:Vector2=loop[(i-1+loop.size())%loop.size()]
				var out:=Vector2(next.y-previous.y,previous.x-next.x).normalized()
				var inside:Dictionary=field.surface_at(p-out*.45)
				if inside.is_empty() or inside.water>=0 or absf(inside.height-h)>.1:continue
				var profile:Dictionary=field._cliff_profile(p,out)
				var landing:float=profile.bottom
				# One world-cell anchor per elevation avoids repeating foliage when
				# adaptive contour sampling inserts extra points along the same rim.
				var anchor_key:=Vector3i(cell.x,roundi(h*2.0),cell.y)
				if foliage_anchors.has(anchor_key):continue
				foliage_anchors[anchor_key]=true
				var growth:=sin(p.x*.58+sin(p.y*.37)*1.4)*cos(p.y*.43-p.x*.17)
				if growth<.18 or random_at(cell,data.seed,81)>.56:continue
				var tuft:=p-out*.70
				var tuft_ground:Dictionary=field.surface_at(tuft)
				if not tuft_ground.is_empty() and tuft_ground.water<0 and absf(tuft_ground.height-h)<.01 and _stable(field,tuft,h,.52):
					result.grass_clump.append(_transform(Vector3(tuft.x,h,tuft.y),p.x+p.y,Vector3.ONE*.90))
				# Compact root groups and short, unequal drapes leave quiet rock
				# between patches. The existing blade module remains unchanged.
				var wide_patch:bool=growth>.48 and random_at(cell,data.seed,82)<.44
				var tangent:=Vector2(-out.y,out.x)
				var patch_width:=.78+random_at(cell,data.seed,83)*.38
				var crowns:=2 if wide_patch else 1
				for crown in crowns:
					var side:float=float(crown)-float(crowns-1)*.5
					var spread:=tangent*side*patch_width*.30
					var root_position:=Vector3(p.x-out.x*.18+spread.x,h+.025,p.y-out.y*.18+spread.y)
					var basis:=Basis(Vector3.UP,atan2(out.x,out.y)+side*.37)*Basis(Vector3.RIGHT,-PI*.5)
					result.vine.append(Transform3D(basis.scaled_local(Vector3(.94,.80,.78) if wide_patch else Vector3(.70,.65,.70)),root_position))
				var strands:=2 if wide_patch and random_at(cell,data.seed,84)<.18 else 1
				for strand in strands:
					var length:=3+int(random_at(cell,data.seed,85+strand)*3) if wide_patch else 1+int(random_at(cell,data.seed,85)*2)
					var offset:float=(float(strand)-float(strands-1)*.5)*patch_width*.42
					var drop:=.12+random_at(cell,data.seed,160+strand)*.08
					for leaf in length:
						var y:=h-drop
						if y<landing+.44:break
						var spread:=tangent*(offset+sin(leaf*1.7+strand*2.1)*.08)
						var anchor:Vector3=field._profile_point(p,y,out,profile)+Vector3(spread.x,0,spread.y)
						var turn:=atan2(out.x,out.y)+(random_at(cell,data.seed,150+leaf+strand*11)-.5)*.54
						var width:float=patch_width*((1.12-leaf*.11) if wide_patch else (.80-leaf*.13))
						var draped:=_drape_vine(field,_transform(anchor,turn,Vector3(width,.70 if wide_patch else .60,.85)),out)
						if not draped.is_empty():result.vine.append(draped.pose)
						drop+=.25+random_at(cell,data.seed,170+leaf+strand*11)*.11

	for level:int in field.water_regions:
		for loop:PackedVector2Array in field.water_regions[level]:
			for i in loop.size():
				var p:=loop[i]
				var next:Vector2=loop[(i+1)%loop.size()]
				var out:=Vector2(next.y-p.y,p.x-next.x).normalized()
				if p.distance_to(next)<.65:continue
				p+=out*.22
				if Data.chunk_of(Vector2i(p.floor()))!=chunk:continue
				var sample:Dictionary=field.surface_at(p)
				if sample.is_empty() or sample.water>=0 or absf(sample.height-level*.5)>.1:continue
				var angle:=atan2(next.y-loop[i].y,next.x-loop[i].x)
				var edge:=next-loop[i]
				var count:=maxi(1,ceili(edge.length()/.95))
				for block in count:
					var bank:=loop[i]+edge*float(block)/count+out*.22
					var support:Dictionary=field.surface_at(bank)
					if support.is_empty() or support.water>=0 or absf(support.height-level*.5)>.1:continue
					var cell:=Vector2i(bank.floor())
					# World-anchored gaps leave short grassy banks between stone
					# groups instead of drawing one uniform masonry ring.
					var outside_bank:Dictionary=field.surface_at(bank+out*1.4)
					var near_drop:bool=outside_bank.is_empty() or float(outside_bank.height)<level*.5-.1
					# The same supported bank field owns both mesh transition and
					# stone gaps. Exposed outlets retain their rock anchors.
					if field.shore_weight(bank-out*.22,level*.5)>.5 and not near_drop and field.shore_support(bank-out*.22,out,level*.5,.70):
						var plant:=bank+out*.25
						if random_at(cell,data.seed,1080+block)<.18 and _stable(field,plant,level*.5,.18):
							result.reeds.append(_transform(Vector3(plant.x,level*.5,plant.y),angle,Vector3.ONE*2.2))
						continue
					var turn:float=(random_at(cell,data.seed,1000+block)-.5)*.40
					var width:float=.68+random_at(cell,data.seed,1020+block)*.58
					var rise:float=1.15+random_at(cell,data.seed,1040+block)*.95
					var depth:float=.64+random_at(cell,data.seed,1060+block)*.20
					result.shore_rock.append(_transform(Vector3(bank.x,level*.5-.07,bank.y),-angle+turn,Vector3(width,rise,depth)))
				var cell:=Vector2i(p.floor())
				if random_at(cell,data.seed,95)<.18:result.reeds.append(_transform(Vector3(p.x,level*.5,p.y)+Vector3(out.x*.55,0,out.y*.55),angle,Vector3.ONE*2.5))
				var lily:=p-out*.8
				var wet:Dictionary=field.surface_at(lily)
				if not wet.is_empty() and wet.water==level and random_at(cell,data.seed,96)<.22:result.lily.append(_transform(Vector3(lily.x,level*.5+.06,lily.y),angle,Vector3.ONE*1.2))
	_path(result,field,chunk)
	# Three small pale flower groups at path margins, with open ground between.
	for at:Vector2 in [Vector2(-12.8,-2.9),Vector2(-12.7,1.6),Vector2(-9.4,4.5)]:
		for j in 3:
			var point:=at+Vector2(sin(j*2.4),cos(j*2.4))*.20
			if Data.chunk_of(Vector2i(point.floor()))!=chunk:continue
			var support:Dictionary=field.surface_at(point)
			if support.is_empty() or support.water>=0 or not _stable(field,point,support.height,.16):continue
			result.flower.append(_transform(Vector3(point.x,support.height,point.y),j*1.7,Vector3.ONE*(1.1+j*.13)))
	_fences(result,field,chunk)
	return result
func _supported_shrub(field,pose:Transform3D,height:float)->bool:
	# Check the actual lower mesh vertices after yaw/scale. Four cardinal
	# probes miss diagonal holes and narrow lips at pond/terrace boundaries.
	for point:Vector3 in _shrub_base:
		var world:Vector3=pose*point
		var support:Dictionary=field.surface_at(Vector2(world.x,world.z))
		if support.is_empty() or support.water>=0 or absf(support.height-height)>.01:return false
	return not _shrub_base.is_empty()
func _drape_vine(field,pose:Transform3D,out:Vector2)->Dictionary:
	# The profile is continuous, but the visible cliff is its sampled triangle
	# mesh. Fit the spray center and tangent frame to that actual surface.
	var center:Vector3=pose*_vine_center
	var outward:=Vector3(out.x,0,out.y)
	var origin:=center+outward*2
	var candidates:Dictionary={}
	for z in range(floori((center.z-2)/8),floori((center.z+2)/8)+1):
		for x in range(floori((center.x-2)/8),floori((center.x+2)/8)+1):
			for i:int in field.triangle_chunks.get(Vector2i(x,z),{}).get("cliff",[]):candidates[i]=true
	var vertices:PackedVector3Array=field.surfaces.cliff.vertices
	var nearest:=INF
	var contact:=Vector3.ZERO
	var normal:=Vector3.ZERO
	for i:int in candidates:
		var a:=vertices[i];var b:=vertices[i+1];var c:=vertices[i+2]
		if center.y<minf(a.y,minf(b.y,c.y)) or center.y>maxf(a.y,maxf(b.y,c.y)):continue
		var face_normal:=-(b-a).cross(c-a).normalized()
		if face_normal.dot(outward)<.25:continue
		var hit=Geometry3D.ray_intersects_triangle(origin,-outward,a,b,c)
		if hit==null:continue
		# Rank from the intended center, not the outward ray origin: a nearby
		# foreground wall must not steal a spray from its own cliff. Bound the
		# correction so missing local support cannot relocate it across a gap.
		var correction:float=center.distance_to(hit)
		if correction<=.60 and correction<nearest:nearest=correction;contact=hit;normal=face_normal
	if nearest==INF:return {}
	var right:=pose.basis.x.normalized()
	right=(right-normal*right.dot(normal)).normalized()
	var up:=normal.cross(right).normalized()
	if up.y<.2:
		up=(Vector3.UP-normal*normal.y).normalized()
		right=up.cross(normal).normalized()
	var basis:=Basis(right,up,normal).scaled_local(pose.basis.get_scale())
	# A small lift lets the solid blades overlap the rock without hovering.
	return {"pose":Transform3D(basis,contact+normal*.025-basis*_vine_center)}
func _stable(field,p:Vector2,h:float,radius:float)->bool:
	for side in Geometry.SIDES:
		var sample:Dictionary=field.surface_at(p+Vector2(side)*radius)
		if sample.is_empty() or sample.water>=0 or absf(sample.height-h)>.01:return false
	return true
func _path_points()->Array:
	return [Vector2(-11,-7+2.24*.82*preload("res://scripts/terrain_editor/terrain_props.gd").COTTAGE_SCALE),Vector2(-12,-3),Vector2(-13,0),Vector2(-11,3),Vector2(-7,5)]
func _near_path(p:Vector2)->bool:
	var points:=_path_points()
	for i in points.size()-1:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,points[i],points[i+1]))<.75:return true
	return false
func _path(result:Dictionary,field,chunk:Vector2i)->void:
	var points:=_path_points()
	for i in points.size()-1:
		var a:Vector2=points[i]
		var b:Vector2=points[i+1]
		var count:=ceili(a.distance_to(b)/.8)
		for j in count:
			var p:=a.lerp(b,float(j)/count)
			if Data.chunk_of(Vector2i(p.floor()))!=chunk:continue
			var sample:Dictionary=field.surface_at(p)
			if sample.is_empty() or sample.water>=0:continue
			result.path.append(_transform(Vector3(p.x,sample.height+.015,p.y),i*.4+j*.13,Vector3(1.4,.7,1.6)))
func _fences(result:Dictionary,field,chunk:Vector2i)->void:
	for spec in [[Vector2(-16,-5),.1,3],[Vector2(-7,-9),0.0,3],[Vector2(-7,4),.18,3],[Vector2(10,-4),-.1,3],[Vector2(16,7),.7,2]]:
		for i in int(spec[2]):
			var p:Vector2=spec[0]+Vector2(cos(spec[1]),sin(spec[1]))*i*1.45
			if Data.chunk_of(Vector2i(p.floor()))!=chunk:continue
			var sample:Dictionary=field.surface_at(p)
			if sample.is_empty() or sample.water>=0 or not _stable(field,p,sample.height,.5):continue
			# Kenney fence's local rail lies at z=-.46; recenter the module on its support.
			var pose:=_transform(Vector3(p.x,sample.height,p.y),-float(spec[1]),Vector3.ONE*1.5)
			pose.origin-=pose.basis*Vector3(0,0,-.46)
			result.fence.append(pose)
func _transform(origin:Vector3,angle:float,size:Vector3)->Transform3D:
	return Transform3D(Basis(Vector3.UP,angle).scaled(size),origin)
func populate(parent:Node3D,data:Data,chunk:Vector2i)->void:
	load_assets()
	var groups:=placements(data,chunk)
	for kind in groups:
		var transforms:Array=groups[kind]
		if transforms.is_empty() or not assets.has(kind):continue
		for index in assets[kind].size():
			var part:Dictionary=assets[kind][index]
			var mm:=MultiMesh.new()
			mm.transform_format=MultiMesh.TRANSFORM_3D
			mm.mesh=part.mesh
			mm.instance_count=transforms.size()
			for i in transforms.size():mm.set_instance_transform(i,transforms[i]*part.pose)
			var instance:=MultiMeshInstance3D.new()
			instance.name=kind+"_%d"%index
			instance.multimesh=mm
			instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			parent.add_child(instance)
