class_name TerrainDecoration
extends RefCounted
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Geometry=preload("res://scripts/terrain_editor/chunk_geometry.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Models=preload("res://scripts/terrain_editor/terrain_models.gd")
var model_library:=Models.new()
var assets:Dictionary={}
var contours:RefCounted
static func random_at(cell:Vector2i,seed_value:int,salt:int)->float:
	var value:int=(cell.x*374761393+cell.y*668265263+seed_value*69069+salt*144269)&0x7fffffff
	value=((value^(value>>13))*1274126177)&0x7fffffff
	return float(value)/2147483647.0
func load_assets()->void:
	model_library.load_assets()
	assets=model_library.assets
func placements(data:Data,chunk:Vector2i)->Dictionary:
	var field=contours
	if field==null:field=Contours.new();field.refresh(data)
	var result:Dictionary={}
	for kind in ["grass","bush","tree","surface_rock","cliff_rock","shore_rock","path","fence","reeds","lily","flower","vine"]:result[kind]=[]
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
			var house_clear:=p.distance_to(Vector2(-10,-7))<3.4
			if not house_clear and cluster>.03 and random_at(cell,data.seed,4)<.48:
				result.grass.append(_transform(origin,angle,Vector3.ONE*(1.1+random_at(cell,data.seed,5)*1.2)))
				if random_at(cell,data.seed,13)<.27:result.flower.append(_transform(origin,angle,Vector3.ONE*.65))
			if not house_clear and cluster>.22 and random_at(cell,data.seed,6)<.15:
				result.bush.append(_transform(origin-Vector3(0,.02,0),angle,Vector3(1.2,.85,1.2)))
			if not house_clear and random_at(cell,data.seed,7)<.018:result.surface_rock.append(_transform(origin-Vector3(0,.11,0),angle,Vector3.ONE*1.7))
	# Composed trees are terrain-anchored modules, and disappear when their support is edited away.
	for spec in [[Vector2(-14,-6),3.1],[Vector2(-5,-8),1.8],[Vector2(1,-5),2.6],[Vector2(15,4),3.5]]:
		var p:Vector2=spec[0]
		if Data.chunk_of(Vector2i(p.floor()))!=chunk:continue
		var sample:Dictionary=field.surface_at(p)
		if sample.is_empty() or sample.water>=0:continue
		if not _stable(field,p,float(sample.height),.6):continue
		result.tree.append(_transform(Vector3(p.x,sample.height,p.y),p.x*.13,Vector3.ONE*float(spec[1])))
	for h:float in field.land_regions:
		for loop:PackedVector2Array in field.land_regions[h]:
			for i in loop.size():
				var p:=loop[i]
				if Data.chunk_of(Vector2i(p.floor()))!=chunk:continue
				var cell:=Vector2i(p.floor())
				if random_at(cell,data.seed,80)>.77:continue
				var next:Vector2=loop[(i+1)%loop.size()]
				var out:=Vector2(next.y-p.y,p.x-next.x).normalized()
				var inside:Dictionary=field.surface_at(p-out*.45)
				if inside.is_empty() or inside.water>=0 or absf(inside.height-h)>.1:continue
				var inward:=-out*.18
				var depth:=1.0+random_at(cell,data.seed,81)*1.3
				if random_at(cell,data.seed,80)<.36:result.cliff_rock.append(_transform(Vector3(p.x+inward.x,h-depth,p.y+inward.y),random_at(cell,data.seed,82)*TAU,Vector3(1.6,1.45,1.4)))
				result.grass.append(_transform(Vector3(p.x-out.x*.22,h,p.y-out.y*.22),p.x+p.y,Vector3.ONE*1.8))
				for leaf in range(4+int(random_at(cell,data.seed,84)*5)):
					var y:=h-.12-leaf*.30
					var bend:=out*(.07-leaf*.025)
					var tangent:=Vector2(-out.y,out.x)*sin(leaf*2.9)*.18
					result.vine.append(_transform(Vector3(p.x+bend.x+tangent.x,y,p.y+bend.y+tangent.y),leaf*.81,Vector3(.55,.40,.50)))
					if leaf<3:result.bush.append(_transform(Vector3(p.x-out.x*.18+tangent.x,h-.08,p.y-out.y*.18+tangent.y),leaf*.83,Vector3(.62,.37,.58)))

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
				var angle:=atan2(next.y-p.y,next.x-p.x)
				result.shore_rock.append(_transform(Vector3(p.x,level*.5-.07,p.y),-angle,Vector3(1.4,.55,1.2)))
				var cell:=Vector2i(p.floor())
				if random_at(cell,data.seed,95)<.18:result.reeds.append(_transform(Vector3(p.x,level*.5,p.y)+Vector3(out.x*.55,0,out.y*.55),angle,Vector3.ONE*2.5))
				var lily:=p-out*.8
				var wet:Dictionary=field.surface_at(lily)
				if not wet.is_empty() and wet.water==level and random_at(cell,data.seed,96)<.22:result.lily.append(_transform(Vector3(lily.x,level*.5+.06,lily.y),angle,Vector3.ONE*1.2))
	_path(result,field,chunk)
	_fences(result,field,chunk)
	return result
func _stable(field,p:Vector2,h:float,radius:float)->bool:
	for side in Geometry.SIDES:
		var sample:Dictionary=field.surface_at(p+Vector2(side)*radius)
		if sample.is_empty() or sample.water>=0 or absf(sample.height-h)>.01:return false
	return true
func _path(result:Dictionary,field,chunk:Vector2i)->void:
	var points:=[Vector2(-10,-5),Vector2(-11,-3),Vector2(-12,0),Vector2(-10,3),Vector2(-6,5)]
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
