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
			var house_clear:=p.distance_to(Vector2(-11,-7))<3.4
			if not house_clear and cluster>-.25 and random_at(cell,data.seed,4)<.38:
				for tuft in 1:
					var offset:=Vector2(random_at(cell,data.seed,110+tuft*2)-.5,random_at(cell,data.seed,111+tuft*2)-.5)*.75
					var ground:Dictionary=field.surface_at(p+offset)
					if ground.is_empty() or ground.water>=0 or absf(ground.height-h)>.01:continue
					if not _stable(field,p+offset,h,.18):continue
					result.grass.append(_transform(origin+Vector3(offset.x,0,offset.y),angle+tuft*2.4,Vector3(.70,.20,.70)*(.85+random_at(cell,data.seed,120+tuft)*.45)))
				if random_at(cell,data.seed,13)<.40:result.flower.append(_transform(origin,angle,Vector3.ONE*.9))
			if not house_clear and cluster>.22 and random_at(cell,data.seed,6)<.20:
				result.bush.append(_transform(origin-Vector3(0,.02,0),angle,Vector3(1.2,.85,1.2)))
			if not house_clear and cluster>-.20 and random_at(cell,data.seed,141)<.13 and _stable(field,p,h,.52):
				result.grass_clump.append(_transform(origin,angle,Vector3.ONE*(.85+random_at(cell,data.seed,142)*.25)))
			if not house_clear and random_at(cell,data.seed,140)<.030 and _stable(field,p,h,.65):
				result.grass_clump.append(_transform(origin,angle,Vector3(1.35,1.65,1.35)))
			if not house_clear and random_at(cell,data.seed,7)<.018:result.surface_rock.append(_transform(origin-Vector3(0,.11,0),angle,Vector3.ONE*1.7))
	# Composed trees are terrain-anchored modules, and disappear when their support is edited away.
	for spec in [[Vector2(-16,-3),3.5],[Vector2(-5,-8),1.8],[Vector2(6.3,-3.3),2.6],[Vector2(15.6,2),3.5]]:
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
				if random_at(cell,data.seed,80)>.90:continue
				var next:Vector2=loop[(i+1)%loop.size()]
				var previous:Vector2=loop[(i-1+loop.size())%loop.size()]
				var out:=Vector2(next.y-previous.y,previous.x-next.x).normalized()
				var inside:Dictionary=field.surface_at(p-out*.45)
				if inside.is_empty() or inside.water>=0 or absf(inside.height-h)>.1:continue
				var profile:Dictionary=field._cliff_profile(p,out)
				var landing:float=profile.bottom
				if random_at(cell,data.seed,80)<.24:
					var y:float=h-1.1-random_at(cell,data.seed,81)*.30
					var layer:=0
					while y>landing+.6 and layer<1:
						var thickness:float=clampf(profile.inset, .25,1.0) if profile.base else 1.0
						var anchor:Vector3=field._profile_point(p,y,out,profile)-Vector3(out.x,0,out.y)*.50*thickness
						var tangent:=Vector3(out.y,0,-out.x)
						var normal:=Vector3(out.x,0,out.y)
						var basis:=Basis(tangent,normal,Vector3.DOWN)
						basis=basis*Basis(Vector3.UP,(random_at(cell,data.seed,82+layer)-.5)*.65)
						var size:=Vector3(2.8+random_at(cell,data.seed,91+layer)*.6,3.0,1.8+random_at(cell,data.seed,101+layer)*.3)
						size.x*=thickness
						size.y*=thickness
						result.cliff_rock.append(Transform3D(basis.scaled_local(size),anchor))
						y-=1.8+random_at(cell,data.seed,130+layer)*.35
						layer+=1
				if random_at(cell,data.seed,80)>.65:continue
				result.grass.append(_transform(Vector3(p.x-out.x*.22,h,p.y-out.y*.22),p.x+p.y,Vector3(.65,.19,.65)))
				var tuft:=p-out*.70
				var tuft_ground:Dictionary=field.surface_at(tuft)
				if random_at(cell,data.seed,80)<.20 and not tuft_ground.is_empty() and tuft_ground.water<0 and absf(tuft_ground.height-h)<.01 and _stable(field,tuft,h,.52):
					result.grass_clump.append(_transform(Vector3(tuft.x,h,tuft.y),p.x+p.y,Vector3.ONE*.95))
				for crown in 2:
					var spread:=Vector2(-out.y,out.x)*(float(crown)-.5)*.34
					var root_position:=Vector3(p.x-out.x*.18+spread.x,h+.025,p.y-out.y*.18+spread.y)
					var basis:=Basis(Vector3.UP,atan2(out.x,out.y)+(float(crown)-.5)*.55)*Basis(Vector3.RIGHT,-PI*.5)
					result.vine.append(Transform3D(basis.scaled_local(Vector3(.95,.95,.85)),root_position))
				for leaf in range(4+int(random_at(cell,data.seed,84)*5)):
					var y:=h-.12-leaf*.23
					if y<landing+.36:break
					var bend:=out*(.07-leaf*.025)
					var tangent:=Vector2(-out.y,out.x)*sin(leaf*2.9)*.18
					var anchor:Vector3=field._profile_point(p,y,out,profile)+Vector3(bend.x+tangent.x,0,bend.y+tangent.y)
					var turn:=atan2(out.x,out.y)+(random_at(cell,data.seed,150+leaf)-.5)*.30
					var width:=1.0-leaf*.055
					result.vine.append(_transform(anchor,turn,Vector3(.95*width,.65,.90)))

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
					var gap:=sin(bank.x*.82+sin(bank.y*.65)*1.2)
					if gap>.92 and random_at(cell,data.seed,1080+block)<.15:
						var plant:=bank+out*.25
						if _stable(field,plant,level*.5,.18):
							result.reeds.append(_transform(Vector3(plant.x,level*.5,plant.y),angle,Vector3.ONE*2.2))
						continue
					var turn:float=(random_at(cell,data.seed,1000+block)-.5)*.40
					var width:float=.82+random_at(cell,data.seed,1020+block)*.35
					var rise:float=1.45+random_at(cell,data.seed,1040+block)*.60
					var depth:float=.64+random_at(cell,data.seed,1060+block)*.20
					result.shore_rock.append(_transform(Vector3(bank.x,level*.5-.07,bank.y),-angle+turn,Vector3(width,rise,depth)))
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
	var points:=[Vector2(-11,-5),Vector2(-12,-3),Vector2(-13,0),Vector2(-11,3),Vector2(-7,5)]
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
