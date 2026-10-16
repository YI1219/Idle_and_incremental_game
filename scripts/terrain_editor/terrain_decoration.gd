class_name TerrainDecoration
extends RefCounted
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Geometry=preload("res://scripts/terrain_editor/chunk_geometry.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Models=preload("res://scripts/terrain_editor/terrain_models.gd")
const COMMON_TREE_HEIGHT := 4.15
# Shore stones read as bank stones at gameplay framing, not as boulders that
# dominate the lake rim.
const SHORE_STONE_SCALE := .62
const BODY_KINDS:Array=["cliff_column","cliff_column_b","cliff_column_c","cliff_column_d"]
var model_library:=Models.new()
var assets:Dictionary={}
var contours:RefCounted
var _vine_center:=Vector3.ZERO
var _shrub_base:=PackedVector3Array()
# Standing columns for the whole outline, rebuilt per contour revision so a
# vine near a chunk edge can hang over a neighboring chunk's column.
var _columns:Array=[]
var _column_cells:Dictionary={}
var _column_field:RefCounted
var _column_key:=Vector2i(-1,-1)
# Independent tapered roots behind the crown joints; cached with their rim span.
var _mass:Array=[]
var _sculpt_buckets:Dictionary={}
var _outcrops:Array=[]
# Unchanged contour runs keep their blocks. Keyed by the run's geometry and
# the nearby heights, so an edit rebuilds only the runs it actually moves.
var _run_cache:Dictionary={}
var layout_hits:=0
var layout_misses:=0
var layout_ms:=0.0
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
	for kind in ["rim_outcrop","rim_shelf","grass","grass_clump","bush","tree","surface_rock","cliff_rock","shore_rock","shore_boulder","shore_pebble","underside_rock","underside_rock_b","cliff_column","cliff_column_b","cliff_column_c","cliff_column_d","path","fence","reeds","lily","flower","vine"]:result[kind]=[]
	_column_layout(field,data.seed)
	for rock:Dictionary in _outcrops:
		if Data.chunk_of(Vector2i(Vector2(rock.pose.origin.x,rock.pose.origin.z).floor()))==chunk:result[rock.kind].append(rock.pose)
	var crown_tufts:Array=[]
	for column:Dictionary in _columns:
		if Data.chunk_of(column.cell)!=chunk:continue
		result[column.kind].append(column.pose)
		# Grass spills over some crowns at their outer edge.
		var cell:Vector2i=column.cell
		var salt:=roundi(column.pose.origin.x*13.0+column.pose.origin.z*7.0)
		if random_at(cell,data.seed,3100+salt)<.55:
			var along:float=(random_at(cell,data.seed,3101+salt)-.5)*column.width*.6
			var at:Vector3=column.pose.origin+column.outward*(column.thickness*.5-.30)+column.tangent*along
			crown_tufts.append(_transform(at-Vector3(0,.05,0),random_at(cell,data.seed,3102+salt)*TAU,Vector3.ONE*lerpf(.75,1.05,random_at(cell,data.seed,3103+salt))))
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
				if random_at(cell,data.seed,13)<.66:
					for bloom in 4:
						var flower_at:=p+Vector2(sin(bloom*2.4+angle),cos(bloom*2.4+angle))*.24
						if _stable(field,flower_at,h,.12):result.flower.append(_transform(Vector3(flower_at.x,h,flower_at.y),angle+bloom,Vector3.ONE*(.65+bloom*.09)))
			if not house_clear and cluster>.22 and random_at(cell,data.seed,6)<.36:
				var pose:=_transform(origin-Vector3(0,.02,0),angle,Vector3(1.2,.85,1.2))
				if _supported_shrub(field,pose,h) and _clear_of_rim(pose):result.bush.append(pose)
			if not house_clear and cluster>.12 and random_at(cell,data.seed,141)<.26 and _stable(field,p,h,.52):
				result.grass_clump.append(_transform(origin,angle,Vector3.ONE*(.85+random_at(cell,data.seed,142)*.25)))
			if not house_clear and cluster>.48 and random_at(cell,data.seed,140)<.026 and _stable(field,p,h,.65):
				result.grass_clump.append(_transform(origin,angle,Vector3(1.10,1.18,1.05)))
			if not house_clear and random_at(cell,data.seed,7)<.018:result.surface_rock.append(_transform(origin-Vector3(0,.11,0),angle,Vector3.ONE*1.7))
	# Composed trees are terrain-anchored modules, and disappear when their support is edited away.
	for spec in [[Vector2(-16,-3),Vector3(1.28,1.02,1.16)],[Vector2(-5,-8),Vector3(.96,.98,1.04)],[Vector2(6.3,-3.3),Vector3(1.0,1.0,.97)],[Vector2(15.6,2),Vector3(1.03,1.01,.96)]]:
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
				if growth<-.35 or random_at(cell,data.seed,81)>.82:continue
				var tuft:=p-out*.70
				var tuft_ground:Dictionary=field.surface_at(tuft)
				if not tuft_ground.is_empty() and tuft_ground.water<0 and absf(tuft_ground.height-h)<.01 and _stable(field,tuft,h,.52):
					result.grass_clump.append(_transform(Vector3(tuft.x,h,tuft.y),p.x+p.y,Vector3.ONE*.90))
				# Compact root groups and short, unequal drapes leave quiet rock
				# between patches. The existing blade module remains unchanged.
				var wide_patch:bool=growth>.05 and random_at(cell,data.seed,82)<.70
				var tangent:=Vector2(-out.y,out.x)
				var patch_width:=.78+random_at(cell,data.seed,83)*.38
				# Rim moss owns the top join; horizontal vine sprays at the old
				# contour became loose green discs inside the merged crown lawn.
				var strands:=2 if wide_patch and random_at(cell,data.seed,84)<.18 else 1
				for strand in strands:
					var length:=11+int(random_at(cell,data.seed,85+strand)*5) if wide_patch else 4+int(random_at(cell,data.seed,85)*4)
					var offset:float=(float(strand)-float(strands-1)*.5)*patch_width*.42
					var drop:=.12+random_at(cell,data.seed,160+strand)*.08
					for leaf in length:
						var y:=h-drop
						if y<landing+.44:break
						var spread:=tangent*(offset+sin(leaf*1.7+strand*2.1)*.08)
						var anchor:Vector3=field._profile_point(p,y,out,profile)+Vector3(spread.x,0,spread.y)
						var turn:=atan2(out.x,out.y)+(random_at(cell,data.seed,150+leaf+strand*11)-.5)*.54
						var width:float=patch_width*(maxf(.30,1.12-leaf*.075) if wide_patch else maxf(.22,.80-leaf*.075))
						var draped:=_drape_vine(field,_transform(anchor,turn,Vector3(width,.70 if wide_patch else .60,.85)),out)
						if not draped.is_empty():result.vine.append(draped.pose)
						drop+=.25+random_at(cell,data.seed,170+leaf+strand*11)*.11

	for stone:Dictionary in _mass:
		if Data.chunk_of(stone.cell)!=chunk:continue
		result[stone.kind].append(stone.pose)
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
				var count:=maxi(1,ceili(edge.length()/.85))
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
							result.reeds.append(_transform(Vector3(plant.x,level*.5,plant.y),angle,Vector3.ONE*3.8))
					_shore_stones(result,field,data.seed,cell,block,bank,out,angle,level*.5)
				var cell:=Vector2i(p.floor())
				if random_at(cell,data.seed,95)<.66:result.reeds.append(_transform(Vector3(p.x,level*.5,p.y)+Vector3(out.x*.55,0,out.y*.55),angle,Vector3.ONE*4.2))
				var lily:=p-out*.8
				var wet:Dictionary=field.surface_at(lily)
				if not wet.is_empty() and wet.water==level and random_at(cell,data.seed,96)<.62:result.lily.append(_transform(Vector3(lily.x,level*.5+.06,lily.y),angle,Vector3.ONE*1.9))
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
	for kind in ["grass","grass_clump","flower","surface_rock","fence","path"]:
		var lifted:Array=result[kind]
		for i in lifted.size():
			var pose:Transform3D=lifted[i]
			pose.origin.y+=_rim_lift(field,Vector2(pose.origin.x,pose.origin.z))
			lifted[i]=pose
	result.grass_clump.append_array(crown_tufts)
	# Reed-like accents belong to supported pond banks. Squashed broad blades
	# used to read as loose green discs across the lawn; moss owns the rim now.
	for kind in ["grass_clump","reeds"]:
		var kept:Array=[]
		for pose:Transform3D in result[kind]:
			var at:=Vector2(pose.origin.x,pose.origin.z)
			if _water_distance(field,at,pose.origin.y)<=.85 and _stable(field,at,pose.origin.y,.18):kept.append(pose)
		result[kind]=kept
	var lilies:Array=[]
	for pose:Transform3D in result.lily:
		var supported:=true
		for part:Dictionary in assets.lily:
			for vertex:Vector3 in part.mesh.get_faces():
				var at:Vector3=pose*part.pose*vertex
				var wet:Dictionary=field.surface_at(Vector2(at.x,at.z))
				if wet.is_empty() or wet.water<0 or absf(wet.height-(pose.origin.y-.06))>.01:supported=false;break
		if supported:lilies.append(pose)
	result.lily=lilies
	return result
func _water_distance(field,p:Vector2,height:float)->float:
	var distance:=INF
	for level:int in field.water_regions:
		if absf(level*.5-height)>.15:continue
		for loop:PackedVector2Array in field.water_regions[level]:
			for i in loop.size():distance=minf(distance,p.distance_to(Geometry2D.get_closest_point_to_segment(p,loop[i],loop[(i+1)%loop.size()])))
	return distance
func _column_layout(field,seed_value:int)->void:
	# Crown and root placements share an editable contour span, with different
	# meshes, depths and offsets. Unchanged spans retain cached placements.
	var key:=Vector2i(field.revision,seed_value)
	if _column_field==field and _column_key==key:return
	var started:=Time.get_ticks_usec()
	_column_field=field
	_column_key=key
	_columns.clear()
	_column_cells.clear()
	_mass.clear()
	_sculpt_buckets.clear()
	if field.source.sculpt_base_enabled:
		_outcrops.clear();_run_cache.clear()
		var skin:PackedVector3Array=field.surfaces.sculpted_terrain.vertices
		for i in range(0,skin.size(),3):
			var lo:=skin[i].min(skin[i+1]).min(skin[i+2])/2.0
			var hi:=skin[i].max(skin[i+1]).max(skin[i+2])/2.0
			for z in range(floori(lo.z),floori(hi.z)+1):
				for y in range(floori(lo.y),floori(hi.y)+1):
					for x in range(floori(lo.x),floori(hi.x)+1):
						var bucket:=Vector3i(x,y,z)
						if not _sculpt_buckets.has(bucket):_sculpt_buckets[bucket]=PackedInt32Array()
						_sculpt_buckets[bucket].append(i)
		field.surfaces.rim_green=preload("res://scripts/terrain_editor/rim_surface_detail.gd").sculpt_lip(field,assets)
		field._smooth_normals(field.surfaces.rim_green);field._index_triangles()
		layout_hits=0;layout_misses=0;layout_ms=0.0
		return
	layout_hits=0
	layout_misses=0
	var seen:Dictionary={}
	for h:float in field.land_regions:
		for loop:PackedVector2Array in field.land_regions[h]:
			for run:Array in _runs(loop):
				var signature:=_run_signature(field,run[0],run[1],run[2],h,seed_value)
				seen[signature]=true
				if _run_cache.has(signature):
					layout_hits+=1
					_restore_run(_run_cache[signature])
				else:
					layout_misses+=1
					var before_c:=_columns.size()
					var before_m:=_mass.size()
					_rim_run(field,run[0],run[1],run[2],h,seed_value)
					var columns:Array=[]
					for i in range(before_c,_columns.size()):columns.append((_columns[i] as Dictionary).duplicate())
					var mass:Array=[]
					for i in range(before_m,_mass.size()):mass.append((_mass[i] as Dictionary).duplicate())
					_run_cache[signature]={"columns":columns,"mass":mass}
	var stale:Array=[]
	for signature in _run_cache:
		if not seen.has(signature):stale.append(signature)
	for signature in stale:_run_cache.erase(signature)
	preload("res://scripts/terrain_editor/rim_union.gd").apply(field,_columns,assets)
	_outcrops=preload("res://scripts/terrain_editor/rim_outcrops.gd").build(self,field,seed_value)
	field.surfaces.rim_green=preload("res://scripts/terrain_editor/rim_outcrops.gd").trim_cover(field.surfaces.rim_green,_outcrops,assets)
	field._index_triangles()
	layout_ms=(Time.get_ticks_usec()-started)/1000.0
func _run_signature(field,a:Vector2,b:Vector2,points:PackedVector2Array,h:float,seed_value:int)->String:
	# Everything _rim_run reads: the chord, the land height, nearby cells and
	# any fall veil that can shorten this run. Same signature, same poses.
	var lo:=a
	var hi:=a
	for p:Vector2 in points:
		lo=lo.min(p)
		hi=hi.max(p)
	lo-=Vector2(3.5,3.5)
	hi+=Vector2(3.5,3.5)
	var parts:=PackedStringArray()
	parts.append("%.4f|%d|%.4f,%.4f,%.4f,%.4f"%[h,seed_value,a.x,a.y,b.x,b.y])
	for p:Vector2 in points:parts.append("%.4f,%.4f"%[p.x,p.y])
	var cells:Dictionary=field.source.cells
	for z in range(floori(lo.y),floori(hi.y)+1):
		for x in range(floori(lo.x),floori(hi.x)+1):
			var record:Dictionary=cells.get(Vector2i(x,z),{})
			if record.is_empty():parts.append(".")
			else:parts.append("%.4f:%d"%[float(record.height),int(record.water)])
	for veil:Dictionary in field.fall_veils:
		var lip:Vector3=veil.lip
		if lip.x<lo.x-1.5 or lip.x>hi.x+1.5 or lip.z<lo.y-1.5 or lip.z>hi.y+1.5:continue
		var veil_out:Vector2=veil.out
		parts.append("v%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d"%[lip.x,lip.y,lip.z,float(veil.half_width),veil_out.x,veil_out.y,1 if veil.external else 0])
	return "|".join(parts)
func _restore_run(cached:Dictionary)->void:
	for source:Dictionary in cached.columns:
		var index:=_columns.size()
		_columns.append(source.duplicate())
		_bucket_column(index)
	for source:Dictionary in cached.mass:_mass.append(source.duplicate())
func _bucket_column(index:int)->void:
	var column:Dictionary=_columns[index]
	var bounds:AABB=column.pose*assets[column.kind][0].mesh.get_aabb()
	for z in range(floori(bounds.position.z/2.0),floori(bounds.end.z/2.0)+1):
		for x in range(floori(bounds.position.x/2.0),floori(bounds.end.x/2.0)+1):
			var bucket:=Vector2i(x,z)
			if not _column_cells.has(bucket):_column_cells[bucket]=[]
			_column_cells[bucket].append(index)
static func _runs(loop:PackedVector2Array)->Array:
	# Corner-bounded spans grow continuously, split above the size limit, and
	# recombine on contraction. Reconstructing from geometry keeps undo/load exact.
	var sections:Array=[]
	var points:=PackedVector2Array([loop[0]])
	var walked:=0.0
	for i in loop.size():
		var a:=loop[i];var b:=loop[(i+1)%loop.size()];var next:=loop[(i+2)%loop.size()]
		points.append(b);walked+=a.distance_to(b)
		var turn:=absf((next-b).angle_to(b-points[0])) if b.distance_squared_to(points[0])>.00001 else 0.0
		if walked>=11.0 or turn>.70 or i==loop.size()-1:
			sections.append(points);points=PackedVector2Array([b]);walked=0.0
	var runs:Array=[]
	for section:PackedVector2Array in sections:
		var total:=0.0
		for i in section.size()-1:total+=section[i].distance_to(section[i+1])
		var count:=maxi(1,ceili(total/3.8))
		var distance:=0.0
		var current:=PackedVector2Array([section[0]])
		var spacing:=total/count
		var index:=1
		var jitter:=minf(.5,(4.2-spacing)*.45)
		var phase:=section[0].dot(Vector2(.73,.51))
		var split:=spacing+jitter*sin(phase+index*2.4) if index<count else total
		for i in section.size()-1:
			var a:=section[i];var b:=section[i+1]
			var length:=a.distance_to(b)
			while split<distance+length-.00001:
				var p:=a.lerp(b,(split-distance)/length)
				current.append(p);runs.append([current[0],p,current])
				current=PackedVector2Array([p]);index+=1;split=spacing*index+jitter*sin(phase+index*2.4) if index<count else total
			current.append(b);distance+=length
			if absf(distance-split)<.00001 and i<section.size()-2:
				runs.append([current[0],b,current]);current=PackedVector2Array([b]);index+=1;split=spacing*index+jitter*sin(phase+index*2.4) if index<count else total
		if current.size()>1:runs.append([current[0],current[-1],current])
	return runs
static func _onto(points:PackedVector2Array,c:Vector2,out:Vector2)->Vector2:
	# A chord cuts a curved contour. Slide the stone centre back onto it.
	var best:=c
	var nearest:=INF
	for i in points.size()-1:
		var q:=Geometry2D.get_closest_point_to_segment(c,points[i],points[i+1])
		var dist:=c.distance_squared_to(q)
		if dist<nearest:nearest=dist;best=q
	return c+out*(best-c).dot(out)
func _curtain_span(field,a:Vector2,dir:Vector2,span:Vector2,y:float,external_only:bool)->Vector2:
	# Shorten a stone so it stops at a fall curtain instead of dropping the
	# whole run and leaving a lawn gap beside the water.
	for veil:Dictionary in field.fall_veils:
		if external_only and not veil.external:continue
		var lip:Vector3=veil.lip
		if not external_only and absf(lip.y-y)>1.4:continue
		var lip_xz:=Vector2(lip.x,lip.z)
		var mid:=a+dir*(span.x+span.y)*.5
		var along:=(mid-lip_xz).dot(veil.out)
		if along<-1.6 or along>1.5:continue
		var side:=absf(dir.dot(Vector2(-veil.out.y,veil.out.x)))
		var reach:=float(veil.half_width)/maxf(.40,side)+.18
		var at:=(lip_xz-a).dot(dir)
		var lo:=at-reach
		var hi:=at+reach
		if hi<=span.x or lo>=span.y:continue
		if lo-span.x>=span.y-hi:span.y=minf(span.y,lo)
		else:span.x=maxf(span.x,hi)
	return span if span.y-span.x>=.70 else Vector2(NAN,NAN)
func _rim_run(field,a:Vector2,b:Vector2,points:PackedVector2Array,h:float,seed_value:int)->void:
	# One bounded shoulder/foot source per adaptive span; legacy sources may
	# still use a separate root as a fallback.
	var length:=a.distance_to(b)
	if length<.25:return
	var dir:=(b-a)/length
	var out:=Vector2(dir.y,-dir.x)
	var outward:=Vector3(out.x,0,out.y)
	var tangent:=Vector3(dir.x,0,dir.y)
	var span:=_curtain_span(field,a,dir,Vector2(-.02,length+.02),h,false)
	if is_nan(span.x) or span.y-span.x<.25:return
	var c:=_onto(points,a+dir*(span.x+span.y)*.5,out)
	var profile:Dictionary=field._cliff_profile(c,out)
	if absf(profile.rock_top-h)>.01:return
	var drop:float=profile.top-profile.bottom
	var step:bool=profile.step or (not profile.base and profile.water<0 and drop>=Contours.STEP_BLOCK_DEPTH)
	if not profile.base and not step:return
	var inside:Dictionary=field.surface_at(c-out*.35)
	if inside.is_empty() or int(inside.water)>=0:return
	var cell:=Vector2i(roundi(c.x*8.0),roundi(c.y*8.0))
	var pick:=mini(BODY_KINDS.size()-1,int(random_at(cell,seed_value,3008)*BODY_KINDS.size()))
	var kind:String=BODY_KINDS[pick]
	var part:Dictionary=assets[kind][0]
	var body_h:float=float(part.body_height)
	var crown_z:float=float(part.crown_z)
	var top:float=h+lerpf(.06,.14,random_at(cell,seed_value,3001))
	# Unequal setbacks let neighboring source shoulders form ledges/clefts.
	# Soft shading must not turn the physical rim into an even perimeter.
	var proud:=lerpf(.45,1.15,pow(random_at(cell,seed_value,3004),1.05))
	# Shoulder size follows the span until it splits. Its reference height
	# stays broad; the sculpted lower foot continues into the supporting core.
	var span_x:float=maxf(.45,float(part.span_x))
	var span_z:float=maxf(.45,float(part.span_z))
	var want_w:=clampf(length*1.02,1.65,4.15)
	var want_d:=lerpf(2.05,2.70,random_at(cell,seed_value,3013))
	var sx:=want_w/span_x
	var sz:=want_d/span_z
	var sy:float
	if step:
		sx=want_w/span_x
		sz=lerpf(1.85,2.25,random_at(cell,seed_value,3015))/span_z
		sy=clampf((drop+.15)/body_h,1.0,2.8)
	else:
		var foot:Vector3=field._profile_point(c,Contours.BOTTOM,out,profile)
		var room:float=maxf(1.4,top-foot.y)
		sy=clampf(minf(room*.44,want_w*.66)*lerpf(.80,1.12,random_at(cell,seed_value,3021))/body_h,1.3,2.8)
		if float(profile.inset)<1.45:
			var fit_d:=maxf(1.65,float(profile.inset))
			sz=minf(sz,fit_d/span_z)
	# Keep width and depth from turning the solid into a thin panel.
	if sx>sz*1.85:sx=sz*1.85
	if sz>sx*1.85:sz=sx*1.85
	var open:=span.y-span.x
	if span.x>-.02 or span.y<length-.02:sx=minf(sx,maxf(1.35,open*.95))
	var yaw:=(random_at(cell,seed_value,3005)-.5)*.85
	var frame:=Basis(-tangent,Vector3.UP,outward)
	# A crown is part of the terrace volume: its back joins the lawn at h.
	# Modest lateral overlap buries internal faces at neighboring stone joints.
	var basis:=frame*Basis(Vector3.UP,yaw)*Basis.from_scale(Vector3(minf(sx*lerpf(1.25,1.36,random_at(cell,seed_value,3024)),4.8),sy,sz))
	var pose:=Transform3D(basis,Vector3(c.x,h,c.y)+outward*(proud-crown_z*sz))
	# Source shoulders can extend beyond the normalized cut cap, especially
	# after yaw. Fit their actual projected crown_extent, not the nominal span.
	var crown_extent:=Vector2(INF,-INF)
	for vertex:Vector3 in part.mesh.get_faces():
		var along:float=(pose.basis*vertex).dot(tangent)
		crown_extent.x=minf(crown_extent.x,along);crown_extent.y=maxf(crown_extent.y,along)
	var crown_clear:=_curtain_span(field,Vector2(pose.origin.x,pose.origin.z),dir,crown_extent,h,false)
	if is_nan(crown_clear.x):return
	if crown_clear!=crown_extent:
		var crown_fit:=(crown_clear.y-crown_clear.x)/(crown_extent.y-crown_extent.x)
		if crown_fit<.45:return
		for axis in 3:
			pose.basis[axis]-=tangent*pose.basis[axis].dot(tangent)*(1.0-crown_fit)
		pose.origin+=tangent*((crown_clear.x+crown_clear.y)*.5-(crown_extent.x+crown_extent.y)*.5*crown_fit)
	var index:=_columns.size()
	_columns.append({"kind":kind,"pose":pose,"edge":c,"cell":Vector2i(c.floor()),"outward":outward,"tangent":tangent,"width":sx,"thickness":crown_z*sz*2.0,"height":body_h*sy})
	_bucket_column(index)
	if profile.base and not part.get("integrated_foot",false):
		# Legacy roots hang behind crown joints, independently sized and rotated. Their
		# upper shoulders overlap the crown's foot; lower cuts converge inward.
		var root_kind:="underside_rock" if pick%2==0 else "underside_rock_b"
		var root_h:float=assets[root_kind][0].body_height
		var foot:Vector3=field._profile_point(c,Contours.BOTTOM,out,profile)
		var root_top:=top-body_h*sy*lerpf(.55,.85,random_at(cell,seed_value,3022))
		var root_height:=clampf(root_top-foot.y+.28,1.3,4.5)
		var root_basis:=frame*Basis(Vector3.UP,yaw+.12)*Basis.from_scale(Vector3(want_w*1.08,root_height/root_h,want_d*.84))
		var root_origin:=Vector3(c.x,root_top,c.y)-outward*.90+tangent*length*lerpf(.14,.30,random_at(cell,seed_value,3023))
		# Staggering must not move a root into a waterfall. Fit the actual
		# projected mesh extent into the remaining interval before publishing it.
		var extent:=Vector2(INF,-INF)
		for vertex:Vector3 in assets[root_kind][0].mesh.get_faces():
			var along:float=(root_basis*vertex).dot(tangent)
			extent.x=minf(extent.x,along);extent.y=maxf(extent.y,along)
		var clear:=_curtain_span(field,Vector2(root_origin.x,root_origin.z),dir,extent,root_top,true)
		if is_nan(clear.x):return
		if clear!=extent:
			var fit:=(clear.y-clear.x)/(extent.y-extent.x)
			if fit<.45:return
			root_basis=root_basis.scaled_local(Vector3(fit,1.0,fit))
			root_origin+=tangent*((clear.x+clear.y)*.5-(extent.x+extent.y)*.5*fit)
		_mass.append({"kind":root_kind,"pose":Transform3D(root_basis,root_origin),"cell":Vector2i(c.floor())})
static func crown_remap(vertex:Vector3,_stretch:float)->Vector3:
	# The crown is authored on the mesh. Scaling must not squash it.
	return vertex
func rim_top_at(p:Vector2)->float:
	# Crown height of the rim block covering a ground point, or -INF.
	var top:=-INF
	for index:int in _column_cells.get(Vector2i(floori(p.x/2.0),floori(p.y/2.0)),[]):
		var pose:Transform3D=_columns[index].pose
		var local:=pose.affine_inverse()*Vector3(p.x,pose.origin.y-.05,p.y)
		if absf(local.x)<=.5 and absf(local.z)<=.5:top=maxf(top,pose.origin.y)
	return top
func _rim_lift(field,p:Vector2)->float:
	# Ground modules over a rim block sit on its crown, slightly sunk into
	# the actual stone surface so they never float.
	var top:=rim_top_at(p)
	if top==-INF:return 0.0
	var ground:Dictionary=field.surface_at(p)
	if ground.is_empty():return 0.0
	return maxf(0.0,top-.04-float(ground.height))
func column_faces_near(point:Vector3)->PackedVector3Array:
	# World triangles of standing columns around a point; vines hang on these.
	var faces:=PackedVector3Array()
	var seen:Dictionary={}
	if not _sculpt_buckets.is_empty():
		var skin:PackedVector3Array=_column_field.surfaces.sculpted_terrain.vertices
		for z in range(floori((point.z-1.1)/2.0),floori((point.z+1.1)/2.0)+1):
			for y in range(floori((point.y-1.1)/2.0),floori((point.y+1.1)/2.0)+1):
				for x in range(floori((point.x-1.1)/2.0),floori((point.x+1.1)/2.0)+1):
					for i:int in _sculpt_buckets.get(Vector3i(x,y,z),PackedInt32Array()):
						if seen.has(i):continue
						seen[i]=true
						for j in 3:faces.append(skin[i+j])
		return faces
	for z in range(floori((point.z-1.0)/2.0),floori((point.z+1.0)/2.0)+1):
		for x in range(floori((point.x-1.0)/2.0),floori((point.x+1.0)/2.0)+1):
			for index:int in _column_cells.get(Vector2i(x,z),[]):
				if seen.has(index):continue
				seen[index]=true
				var column:Dictionary=_columns[index]
				var vertices:PackedVector3Array=assets[column.kind][0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for vertex:Vector3 in vertices:faces.append(column.pose*crown_remap(vertex,column.height))
	for stone:Dictionary in _mass+_outcrops:
		var mesh:Mesh=assets[stone.kind][0].mesh
		var bounds:AABB=stone.pose*mesh.get_aabb()
		if not bounds.grow(2.0).has_point(point):continue
		for vertex:Vector3 in mesh.get_faces():faces.append(stone.pose*vertex)
	# The exposed lower backing is now separate stone volumes. They must also
	# own hanging vegetation contact instead of leaving it buried in the core.
	if _column_field!=null and _column_field.surfaces.has("stone_mantle"):
		var mantle_seen:Dictionary={}
		var mantle:PackedVector3Array=_column_field.surfaces.stone_mantle.vertices
		for z in range(floori((point.z-2.0)/8.0),floori((point.z+2.0)/8.0)+1):
			for x in range(floori((point.x-2.0)/8.0),floori((point.x+2.0)/8.0)+1):
				for i:int in _column_field.triangle_chunks.get(Vector2i(x,z),{}).get("stone_mantle",[]):
					if mantle_seen.has(i):continue
					mantle_seen[i]=true
					for j in 3:faces.append(mantle[i+j])

	return faces
func _shore_stones(result:Dictionary,field,seed_value:int,cell:Vector2i,block:int,bank:Vector2,out:Vector2,angle:float,water_y:float)->void:
	# Mixed shoreline: world-anchored groups of large shouldered boulders,
	# medium stones and small clusters, some standing out in the water.
	var choose:=random_at(cell,seed_value,1100+block)
	var group:=sin(bank.x*.71+bank.y*.37)*cos(bank.y*.53-bank.x*.23)
	if choose<.05:return
	var kind:="shore_rock"
	if group>.25 and choose<.62:kind="shore_boulder"
	elif choose>.78:kind="shore_pebble"
	# Keep the plunge and its curtain clear of stones set into the lake.
	var wet_reach:=1.0
	for splash:Dictionary in field.splash_points:
		var centre:Vector2=Vector2(splash.center.x,splash.center.z)
		wet_reach=minf(wet_reach,smoothstep(1.2,2.4,bank.distance_to(centre)))
	var tangent:=Vector2(-out.y,out.x)
	var count:=1 if kind!="shore_pebble" else 2+int(random_at(cell,seed_value,1120+block)*2.0)
	for stone in count:
		var salt:=block*7+stone
		var along:=(random_at(cell,seed_value,1140+salt)-.5)*(.30 if kind!="shore_pebble" else .80)
		var across:float
		var size:Vector3
		var sink:float
		match kind:
			"shore_boulder":
				across=lerpf(-.22,.12,random_at(cell,seed_value,1160+salt))
				size=Vector3(lerpf(1.35,1.95,random_at(cell,seed_value,1180+salt)),lerpf(1.85,2.75,random_at(cell,seed_value,1200+salt)),lerpf(1.05,1.45,random_at(cell,seed_value,1220+salt)))
				sink=.12
			"shore_pebble":
				across=lerpf(-.62,-.05,random_at(cell,seed_value,1160+salt))
				size=Vector3.ONE*lerpf(.42,.78,random_at(cell,seed_value,1180+salt))*Vector3(1.0,lerpf(.9,1.5,random_at(cell,seed_value,1200+salt)),1.0)
				sink=.06
			_:
				across=lerpf(-.38,.10,random_at(cell,seed_value,1160+salt))
				size=Vector3(lerpf(.70,1.20,random_at(cell,seed_value,1180+salt)),lerpf(1.00,1.75,random_at(cell,seed_value,1200+salt)),lerpf(.62,.90,random_at(cell,seed_value,1220+salt)))
				sink=.08
		size*=SHORE_STONE_SCALE
		sink*=SHORE_STONE_SCALE
		across=across*wet_reach if across<0 else across
		var at:=bank+tangent*along+out*across
		# Stones placed into the lake sit lower, partly submerged.
		var depth:=maxf(0.0,-across)*.22
		var yaw:=-angle+(random_at(cell,seed_value,1240+salt)-.5)*(.6 if kind=="shore_rock" else TAU)
		var tilt:=(random_at(cell,seed_value,1260+salt)-.5)*.22
		var basis:=Basis(Vector3(out.x,0,out.y),tilt)*Basis(Vector3.UP,yaw).scaled(size)
		var seated:=preload("res://scripts/terrain_editor/shore_stone_support.gd").seat(field,assets[kind][0].mesh,Transform3D(basis,Vector3(at.x,water_y-sink-depth,at.y)),water_y)
		if not seated.is_empty():result[kind].append(seated.pose)
func _clear_of_rim(pose:Transform3D)->bool:
	# A shrub stays on open turf. Sitting it on a rim head would either clip
	# the stone or lift base vertices off the ground beside it.
	if rim_top_at(Vector2(pose.origin.x,pose.origin.z))!=-INF:return false
	for point:Vector3 in _shrub_base:
		var world:Vector3=pose*point
		if rim_top_at(Vector2(world.x,world.z))!=-INF:return false
	return true
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
	# A standing column in front of the wall is the visible support: the
	# spray hangs on its outer face instead of on the recessed rock behind.
	if _column_field==field:
		var faces:=column_faces_near(center)
		var front:=INF
		for i in range(0,faces.size(),3):
			var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
			var face_normal:=-(b-a).cross(c-a).normalized()
			if face_normal.dot(outward)<.25:continue
			var hit=Geometry3D.ray_intersects_triangle(origin,-outward,a,b,c)
			if hit==null:continue
			var along:float=origin.distance_to(hit)
			if along<front and center.distance_to(hit)<=1.2:front=along;contact=hit;normal=face_normal;nearest=0.0
	if nearest==INF:return {}
	# Turning the spray to a fracture face changes its outward ray. Resolve
	# a last short contact on that ray so an adjacent block cannot bury it.
	if _column_field==field:
		for resolve in 3:
			var faces:=column_faces_near(contact)
			var probe:=contact+normal*.65;var distance:=.65
			for i in range(0,faces.size(),3):
				var hit=Geometry3D.ray_intersects_triangle(probe,-normal,faces[i],faces[i+1],faces[i+2])
				if hit!=null and probe.distance_to(hit)<distance:
					var triangle_normal:Vector3=(faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).normalized()
					if absf(triangle_normal.dot(hit-faces[i]))>.003:continue
					var weights:=Geometry3D.get_triangle_barycentric_coords(hit,faces[i],faces[i+1],faces[i+2])
					if minf(weights.x,minf(weights.y,weights.z))<-.00001:continue
					distance=probe.distance_to(hit);contact=hit
	# A short ray can start inside overlapping stones. If the resolved spray
	# is still hidden, omit this leaf cluster instead of walking it across the
	# island to an unrelated face.
	if _column_field==field:
		var point:=contact+normal*.025
		var faces:=column_faces_near(point)
		for i in range(0,faces.size(),3):
			var hit=Geometry3D.ray_intersects_triangle(point+normal*.6,-normal,faces[i],faces[i+1],faces[i+2])
			if hit!=null and (point+normal*.6).distance_to(hit)<.57:return {}
	var right:=pose.basis.x.normalized()
	right=(right-normal*right.dot(normal)).normalized()
	var up:=normal.cross(right).normalized()
	if up.y<.2:
		up=(Vector3.UP-normal*normal.y).normalized()
		right=up.cross(normal).normalized()
	var basis:=Basis(right,up,normal).scaled_local(pose.basis.get_scale()*.68)
	# A small lift lets the solid blades overlap the rock without hovering.
	return {"pose":Transform3D(basis,contact+normal*.025-basis*_vine_center)}
func _stable(field,p:Vector2,h:float,radius:float)->bool:
	for side in Geometry.SIDES:
		var sample:Dictionary=field.surface_at(p+Vector2(side)*radius)
		if sample.is_empty() or sample.water>=0 or absf(sample.height-h)>.01:return false
	return true
func _path_points()->Array:
	return preload("res://scripts/terrain_editor/terrain_paths.gd").POINTS.duplicate()
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
		var count:=ceili(a.distance_to(b)/.90)
		for j in count:
			var p:=a.lerp(b,float(j)/count)
			if Data.chunk_of(Vector2i(p.floor()))!=chunk:continue
			var sample:Dictionary=field.surface_at(p)
			if sample.is_empty() or sample.water>=0:continue
			result.path.append(_transform(Vector3(p.x,sample.height+.015,p.y),i*.4+j*.13,Vector3(1.55,.65,1.70)))
func _fences(result:Dictionary,field,chunk:Vector2i)->void:
	for spec in [[Vector2(-10.4,-2.9),0.0,3],[Vector2(-10.6,-6.1),PI*.5,2],[Vector2(-16,-5),.1,3],[Vector2(-7,-9),0.0,3],[Vector2(-7,4),.18,3],[Vector2(10,-4),-.1,3],[Vector2(16,7),.7,2]]:
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
			mm.mesh=part.get("render_mesh",part.mesh)
			mm.use_colors=kind.begins_with("shore_") or kind.begins_with("underside_") or kind.begins_with("cliff_column")
			mm.instance_count=transforms.size()
			for i in transforms.size():
				mm.set_instance_transform(i,transforms[i]*part.pose)
				if mm.use_colors:mm.set_instance_color(i,_stone_tone(transforms[i].origin))
			var instance:=MultiMeshInstance3D.new()
			instance.name=kind+"_%d"%index
			instance.multimesh=mm
			instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			parent.add_child(instance)
static func _stone_tone(origin:Vector3)->Color:
	# Deterministic per-stone value and hue: warm ochre, cool slate and moss-dark.
	var a:=fposmod(sin(origin.x*12.9898+origin.z*78.233)*43758.5453,1.0)
	var b:=fposmod(sin(origin.x*39.346+origin.z*11.135)*24634.6345,1.0)
	var value:=lerpf(.68,1.08,a)
	var warm:=Color(1.04,.98,.88).lerp(Color(.88,.92,.96),b)
	if b>.82:warm=Color(.86,.92,.78)
	return Color(warm.r*value,warm.g*value,warm.b*value,1.0)
