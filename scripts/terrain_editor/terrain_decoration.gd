class_name TerrainDecoration
extends RefCounted
const Data=preload("res://scripts/terrain_editor/terrain_data.gd")
const Geometry=preload("res://scripts/terrain_editor/chunk_geometry.gd")
const Contours=preload("res://scripts/terrain_editor/contour_terrain.gd")
const Models=preload("res://scripts/terrain_editor/terrain_models.gd")
const COMMON_TREE_HEIGHT := 4.15
# Shore stones read as bank stones at gameplay framing, not as boulders that
# dominate the lake rim.
const SHORE_STONE_SCALE := .78
const BODY_KINDS:Array=["cliff_column","cliff_column_b","cliff_column_c","cliff_column_d","cliff_column_e","cliff_column_f","cliff_column_g","cliff_column_h"]
const UNDERSIDE_KINDS:Array=["underside_rock","underside_rock_b","underside_rock_c","underside_rock_d"]
## An outer pillar on a contour run shorter than this is a corner chamfer. It
## merges into the broad slabs beside it when both can close over its span.
const NARROW_OUTER_RUN:=2.65
## A slab that absorbs a narrow pillar passes the pillar centre by this much.
const MERGE_OVERLAP:=.45
## A pillar standing further than this in front of the rim line of a slab is
## an outward bump the slab cannot cover, so it keeps its own pillar.
const MERGE_PROUD:=.35
## Thin fingers of land keep a pillar on every face; merging needs this much
## land behind the pillar.
const MERGE_MIN_LAND:=2.8
## Front-back stagger of outer faces (_stagger_outer_faces).
## Neighbours: facing within about 53 degrees, tops within this many metres,
## centres closer than this share of their two widths.
const STAGGER_FACING:=.60
const STAGGER_LEVEL:=1.6
const STAGGER_LINK:=.62
## A primary takes over a neighbour within about 12 degrees of its facing and
## this close to its plane, up to this total width.
const STAGGER_ABSORB_FACING:=.978
const STAGGER_ABSORB_OFFSET:=.5
const STAGGER_MAX_FACE:=10.4
## Metres forward for a primary, back for a secondary (never closer to the
## contour than STAGGER_MIN_PROUD), and the total play of the rest.
const STAGGER_PRIMARY:=Vector2(.80,1.25)
const STAGGER_SECONDARY:=Vector2(.30,.50)
const STAGGER_PLAIN:=.24
const STAGGER_MIN_PROUD:=.46
## The slabs beside a secondary overlap its ends by this much.
const STAGGER_SEAT:=.18
## A share of the broad outer runs that the shoulder chance left bare still
## offer a rock group. One is kept only where no shoulder of the first kind was
## offered within this radius and it outranks every other offered group within
## it, so a long wall need not stay a plain row and no wall turns busy.
const STAGGER_FILL_SHARE:=.37
const STAGGER_FILL_RADIUS:=5.25
## Their tops come this far below the lip at most, as a share of the wall
## height and in metres: lower than that a group reads as a pedestal.
const STAGGER_FILL_DROP:=Vector2(.34,3.6)
## A group needs land this far to either side (x) and this far in (y);
## without it the wall is turning round a nose, where a group reads as a shelf.
const STAGGER_FILL_FLANK:=Vector2(4.5,2.6)
## A slab's rank is its width in metres plus a fixed per-slab number worth up
## to STAGGER_SCORE_PLAY. At or under x it is a secondary, at or over y a primary.
const STAGGER_SCORE_PLAY:=1.2
const STAGGER_RANKS:=Vector2(5.5,6.5)
## Yaw given to a primary or secondary face, in radians either way.
const STAGGER_YAW:=Vector2(.05,.11)
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
var _outline_run_cache:Dictionary={}
var _previous_runs:Dictionary={}
var _run_seed:int=0
var _chunk_cache:Dictionary={}
## Reversible art candidate. Full rebuild publishes picking with the fitted core.
var fit_core_to_feet:bool=false:
	set(value):
		fit_core_to_feet=value
		_column_key=Vector2i(-1,-1)
var blend_core_joints:bool=false:
	set(value):
		blend_core_joints=value
		_column_key=Vector2i(-1,-1)
var layout_hits:=0
var layout_misses:=0
var layout_ms:=0.0
var layout_stages:Dictionary={}
static func random_at(cell:Vector2i,seed_value:int,salt:int)->float:
	var value:int=(cell.x*374761393+cell.y*668265263+seed_value*69069+salt*144269)&0x7fffffff
	value=((value^(value>>13))*1274126177)&0x7fffffff
	return float(value)/2147483647.0
func load_assets()->void:
	if not assets.is_empty():return
	model_library.load_assets()
	assets=model_library.assets
	var vertices:PackedVector3Array=preload("res://scripts/terrain_editor/chunk_geometry.gd").arrays_of(assets.vine[0].mesh,0)[Mesh.ARRAY_VERTEX]
	_vine_center=Vector3.ZERO
	for point:Vector3 in vertices:_vine_center+=point
	_vine_center/=vertices.size()
	var shrub:Mesh=assets.bush[0].mesh
	var box:AABB=shrub.get_aabb()
	var unique:Dictionary={}
	_shrub_base.clear()
	for point:Vector3 in preload("res://scripts/terrain_editor/chunk_geometry.gd").arrays_of(shrub,0)[Mesh.ARRAY_VERTEX]:
		if point.y<=box.position.y+box.size.y*.08 and not unique.has(point):
			unique[point]=true
			_shrub_base.append(point)
func _chunk_signature(data:Data,chunk:Vector2i)->String:
	var parts:=PackedStringArray(["%d|%d,%d|%d"%[data.seed,chunk.x,chunk.y,1 if data.sculpt_base_enabled else 0]])
	for z in range(chunk.y*8-3,chunk.y*8+11):
		for x in range(chunk.x*8-3,chunk.x*8+11):
			var rec:Dictionary=data.cells.get(Vector2i(x,z),{})
			if rec.is_empty():parts.append(".")
			else:parts.append("%.2f:%d"%[float(rec.height),int(rec.water)])
	for col:Dictionary in _columns:
		if Data.chunk_of(col.cell)==chunk:
			parts.append("c%.2f,%.2f,%.2f"%[col.pose.origin.x,col.pose.origin.y,col.pose.origin.z])
	for st:Dictionary in _mass:
		if Data.chunk_of(st.cell)==chunk:
			parts.append("m%.2f,%.2f,%.2f"%[st.pose.origin.x,st.pose.origin.y,st.pose.origin.z])
			if st.has("mesh"):parts.append("heel%d"%st.mesh.get_meta("join_signature"))
	for oc:Dictionary in _outcrops:
		var oc_cell:=Vector2i(Vector2(oc.pose.origin.x,oc.pose.origin.z).floor())
		if Data.chunk_of(oc_cell)==chunk:
			parts.append("o%.2f,%.2f,%.2f"%[oc.pose.origin.x,oc.pose.origin.y,oc.pose.origin.z])
	return "|".join(parts)
func placements(data:Data,chunk:Vector2i)->Dictionary:
	if assets.is_empty():load_assets()
	var field=contours
	if field==null:field=Contours.new();field.refresh(data)
	_column_layout(field,data.seed)
	var chunk_sig:=_chunk_signature(data,chunk)
	if _chunk_cache.has(chunk) and _chunk_cache[chunk].sig==chunk_sig:
		return _chunk_cache[chunk].result
	var result:Dictionary={}
	for kind in ["rim_outcrop","rim_shelf","grass","grass_clump","bush","tree","tree_b","surface_rock","cliff_rock","shore_rock","shore_boulder","shore_pebble","underside_rock","underside_rock_b","underside_rock_c","underside_rock_d","cliff_column","cliff_column_b","cliff_column_c","cliff_column_d","cliff_column_e","cliff_column_f","cliff_column_g","cliff_column_h","path","fence","reeds","lily","flower","vine"]:result[kind]=[]
	for rock:Dictionary in _outcrops:
		if Data.chunk_of(Vector2i(Vector2(rock.pose.origin.x,rock.pose.origin.z).floor()))==chunk:result[rock.kind].append(rock.pose)
	var crown_tufts:Array=[]
	for column:Dictionary in _columns:
		if Data.chunk_of(column.cell)!=chunk:continue
		result[column.kind].append(column.pose)
		# Crevice moss, shrub cushions & cliff-brow fern tufts at outer rim clefts (Tiny Glade / Refs 01–04):
		var cell:Vector2i=column.cell
		var salt:=roundi(column.pose.origin.x*13.0+column.pose.origin.z*7.0)
		if not column.get("is_step",false) and ((column.edge-Vector2(-4.85,8.45))/Vector2(4.25,2.15)).length()>1.05 and random_at(cell,data.seed,3110+salt)<.42:
			var cleft_dir:float=1.0 if random_at(cell,data.seed,3111+salt)<.5 else -1.0
			var cleft_2d:Vector2=column.edge-Vector2(column.outward.x,column.outward.z)*.24+Vector2(column.tangent.x,column.tangent.z)*(column.width*.34*cleft_dir)
			var cleft_surf:Dictionary=field.surface_at(cleft_2d)
			if not cleft_surf.is_empty() and int(cleft_surf.water)<0 and absf(float(cleft_surf.height)-column.pose.origin.y)<.12 and not _near_path(cleft_2d) and not _in_outcrop_hull(cleft_2d):
				var c_scale:=lerpf(.92,1.24,random_at(cell,data.seed,3112+salt))
				result.bush.append(_transform(Vector3(cleft_2d.x,column.pose.origin.y-.02,cleft_2d.y),random_at(cell,data.seed,3113+salt)*TAU,Vector3(c_scale,c_scale*.92,c_scale)))
				if random_at(cell,data.seed,3114+salt)<.72:
					var tuft_2d:Vector2=cleft_2d+Vector2(column.tangent.x,column.tangent.z)*(cleft_dir*-.28)-Vector2(column.outward.x,column.outward.z)*.12
					var t_surf:Dictionary=field.surface_at(tuft_2d)
					if not t_surf.is_empty() and int(t_surf.water)<0 and absf(float(t_surf.height)-column.pose.origin.y)<.08 and not _in_outcrop_hull(tuft_2d):
						crown_tufts.append(_transform(Vector3(tuft_2d.x,column.pose.origin.y,tuft_2d.y),random_at(cell,data.seed,3115+salt)*TAU,Vector3.ONE*lerpf(.84,1.12,random_at(cell,data.seed,3116+salt))))
		# Keep cliff walls & waterfall lips clean and sculptural without blocky low-poly vine triangles:
		if false and column.height>=2.0 and random_at(cell,data.seed,3180+salt)<(.14 if column.get("is_step",false) else .03):
			var v_side:float=1.0 if random_at(cell,data.seed,3181+salt)<.5 else -1.0
			var v_along:float=column.width*lerpf(.34,.46,random_at(cell,data.seed,3182+salt))*v_side
			var v_check:Vector2=column.edge-Vector2(column.outward.x,column.outward.z)*.24+Vector2(column.tangent.x,column.tangent.z)*v_along
			var v_surf:Dictionary=field.surface_at(v_check)
			if not v_surf.is_empty() and int(v_surf.water)<0 and absf(float(v_surf.height)-column.pose.origin.y)<.12:
				var v_out:Vector3=column.outward
				var v_tan:Vector3=column.tangent
				var v_yaw:=(random_at(cell,data.seed,3183+salt)-.5)*.20
				var v_sc:=lerpf(1.16,1.52,random_at(cell,data.seed,3184+salt))
				var v_frame:=Basis(-v_tan,Vector3.UP,v_out)*Basis(Vector3.UP,v_yaw)*Basis(Vector3.RIGHT,-.08)
				var v_top:=Vector3(column.edge.x,column.pose.origin.y-.09,column.edge.y)+v_out*.74+v_tan*v_along
				result.vine.append(Transform3D(v_frame*Basis.from_scale(Vector3(v_sc,v_sc*1.38,v_sc)),v_top))
				if column.height>=2.4 and random_at(cell,data.seed,3185+salt)<.78:
					var v_low:=v_top-Vector3(0.0,.52*v_sc,0.0)-v_out*.04+v_tan*(v_side*.05)
					result.vine.append(Transform3D(v_frame*Basis(Vector3.FORWARD,(random_at(cell,data.seed,3186+salt)-.5)*.16)*Basis.from_scale(Vector3(v_sc*.85,v_sc*1.20,v_sc*.86)),v_low))
		# At the base of inner terrace steps (01-04), seat lush grouped shrubs, ferns & wildflowers
		# and a corner rock outcrop against the foot of the terrace cliff wall.
		if column.get("is_step",false):
			var foot_2d:Vector2=column.edge+Vector2(column.outward.x,column.outward.z)*1.12
			var foot_surf:Dictionary=field.surface_at(foot_2d)
			if not foot_surf.is_empty() and int(foot_surf.water)<0 and float(foot_surf.height)<column.pose.origin.y-.4:
				var f_y:float=float(foot_surf.height)
				if random_at(cell,data.seed,3150+salt)<.76:
					var s_scale:=lerpf(.92,1.26,random_at(cell,data.seed,3151+salt))
					result.bush.append(_transform(Vector3(foot_2d.x,f_y-.02,foot_2d.y),random_at(cell,data.seed,3152+salt)*TAU,Vector3(s_scale,s_scale*.94,s_scale)))
					var tan2:=Vector2(column.tangent.x,column.tangent.z)
					var sub_2d:=foot_2d+tan2*.42
					var sub_s:Dictionary=field.surface_at(sub_2d)
					if not sub_s.is_empty() and int(sub_s.water)<0 and absf(float(sub_s.height)-f_y)<.05 and random_at(cell,data.seed,3157+salt)<.62:
						var sub_sc:=s_scale*.68
						result.bush.append(_transform(Vector3(sub_2d.x,f_y-.02,sub_2d.y),random_at(cell,data.seed,3158+salt)*TAU,Vector3(sub_sc,sub_sc*.88,sub_sc)))
					if ((foot_2d-Vector2(-4.85,8.45))/Vector2(4.35,2.25)).length()>1.08 and random_at(cell,data.seed,3154+salt)<.68:
						crown_tufts.append(_transform(Vector3(foot_2d.x+.30,f_y,foot_2d.y+.20),random_at(cell,data.seed,3153+salt)*TAU,Vector3.ONE*lerpf(.88,1.12,random_at(cell,data.seed,3159+salt))))
						if random_at(cell,data.seed,3160+salt)<.52 and _stable(field,foot_2d-tan2*.30,f_y,.14):
							result.flower.append(_transform(Vector3(foot_2d.x-tan2.x*.30,f_y,foot_2d.y-tan2.y*.30),random_at(cell,data.seed,3161+salt)*TAU,Vector3.ONE*lerpf(.86,1.08,random_at(cell,data.seed,3162+salt))))
				if column.edge.y>1.2 and column.edge.x<-1.2 and random_at(cell,data.seed,3155+salt)<.85:
					var r_pos:Vector2=foot_2d+Vector2(column.tangent.x,column.tangent.z)*.32
					var r_surf:Dictionary=field.surface_at(r_pos)
					if not r_surf.is_empty() and int(r_surf.water)<0 and absf(float(r_surf.height)-f_y)<.05:
						result.cliff_rock.append(_transform(Vector3(r_pos.x,float(r_surf.height)-.06,r_pos.y),random_at(cell,data.seed,3156+salt)*TAU,Vector3(1.22,1.02,1.16)))
	for veil:Dictionary in field.fall_veils:
		var lip:Vector3=veil.lip
		var v_out2:Vector2=veil.out
		var v_side2:=Vector2(-v_out2.y,v_out2.x)
		var hw:float=float(veil.half_width)
		for side_sign:float in [-1.0,1.0]:
			var flank_2d:Vector2=Vector2.ZERO
			var f_surf:Dictionary={}
			for side_off:float in [.42,.66,.92]:
				for back_off:float in [.18,.36,.56]:
					var cand:Vector2=Vector2(lip.x,lip.z)+v_side2*(hw+side_off)*side_sign-v_out2*back_off
					var s_cand:Dictionary=field.surface_at(cand)
					if not s_cand.is_empty() and int(s_cand.water)<0:
						flank_2d=cand;f_surf=s_cand;break
				if not f_surf.is_empty():break
			if f_surf.is_empty() or Data.chunk_of(Vector2i(flank_2d.floor()))!=chunk:continue
			var fy:float=float(f_surf.height)
			var out3:=Vector3(v_out2.x,0.0,v_out2.y)
			var side3:=Vector3(v_side2.x*side_sign,0.0,v_side2.y*side_sign)
			result.cliff_rock.append(_transform(Vector3(flank_2d.x,fy-.08,flank_2d.y)-out3*.06,lip.z+side_sign*1.1,Vector3(1.06,.82,1.00)))
			result.shore_boulder.append(_transform(Vector3(flank_2d.x,fy-.07,flank_2d.y)+side3*.44-out3*.14,lip.x-side_sign*.8,Vector3(.82,.64,.78)))
			# Mist-fed waterfall-lip shrub & arching fern tuft nestled behind the lip boulders (Ref 04 / Tiny Glade):
			var wf_bush_2d:Vector2=flank_2d+v_side2*(side_sign*.32)-v_out2*.36
			var wf_s:Dictionary=field.surface_at(wf_bush_2d)
			if not wf_s.is_empty() and int(wf_s.water)<0 and absf(float(wf_s.height)-fy)<.06 and not _near_path(wf_bush_2d):
				result.bush.append(_transform(Vector3(wf_bush_2d.x,fy-.02,wf_bush_2d.y),lip.x+side_sign*1.7,Vector3(.86,.82,.84)))
				crown_tufts.append(_transform(Vector3(wf_bush_2d.x,fy,wf_bush_2d.y)+side3*.24,lip.z-side_sign*.9,Vector3.ONE*.96))
	# Signature chiseled garden & bluff-foot limestone boulders with nestled botanical clusters (Tiny Glade / Regreening):
	var rock_idx:=0
	for RockSpec in [
		[Vector2(-15.5,.4),Vector3(1.30,1.02,1.22),.55,"surface_rock"],
		[Vector2(-13.8,.9),Vector3(.82,.66,.78),1.85,"surface_rock"],
		[Vector2(-11.4,3.6),Vector3(1.36,1.10,1.28),1.12,"surface_rock"],
		[Vector2(-11.2,-6.7),Vector3(1.16,.94,1.12),.42,"surface_rock"],
		[Vector2(1.4,-6.4),Vector3(1.16,.92,1.10),2.05,"surface_rock"],
		[Vector2(2.4,-2.2),Vector3(.98,.78,.94),.88,"surface_rock"],
		[Vector2(-1.25,4.65),Vector3(1.36,1.14,1.26),.64,"cliff_rock"],
		[Vector2(-1.72,5.72),Vector3(1.08,.90,1.02),1.92,"cliff_rock"],
		[Vector2(13.8,3.1),Vector3(1.42,1.10,1.32),.48,"surface_rock"],
		[Vector2(15.5,4.0),Vector3(1.54,1.22,1.42),1.74,"surface_rock"],
	]:
		rock_idx+=1
		var rp:Vector2=RockSpec[0]
		if Data.chunk_of(Vector2i(rp.floor()))==chunk:
			var r_surf:Dictionary=field.surface_at(rp)
			if not r_surf.is_empty() and int(r_surf.water)<0 and _stable(field,rp,float(r_surf.height),.38):
				var rh:float=float(r_surf.height)
				var r_yaw:float=float(RockSpec[2])
				result[RockSpec[3]].append(_transform(Vector3(rp.x,rh-.07,rp.y),r_yaw,RockSpec[1]))
				# Tucked companion shrub + fern tuft + mountain-orchid spray hugging boulder base (Tiny Glade grouping):
				var b_ang:=r_yaw+2.15+float(rock_idx)*.72
				var b_dir:=Vector2(cos(b_ang),sin(b_ang))
				var b_side:=Vector2(-b_dir.y,b_dir.x)
				var r_rad:float=maxf((RockSpec[1] as Vector3).x,(RockSpec[1] as Vector3).z)*.48
				var sh_p:Vector2=rp+b_dir*(r_rad+.22)
				if rock_idx%3!=0 and not _near_path(sh_p):
					var sh_s:Dictionary=field.surface_at(sh_p)
					if not sh_s.is_empty() and int(sh_s.water)<0 and absf(float(sh_s.height)-rh)<.04:
						var sh_pose:=_transform(Vector3(sh_p.x,rh-.02,sh_p.y),b_ang+.6,Vector3(.82,.78,.80)*(0.88+0.18*float(rock_idx%2)))
						if _supported_shrub(field,sh_pose,rh):result.bush.append(sh_pose)
				var fn_p:Vector2=rp-b_dir*(r_rad+.14)+b_side*.24
				if not _near_path(fn_p) and _stable(field,fn_p,rh,.18):
					result.grass_clump.append(_transform(Vector3(fn_p.x,rh,fn_p.y),b_ang*1.7,Vector3.ONE*(.88+.16*float(rock_idx%2))))
				var fl_p:Vector2=rp+b_dir*(r_rad+.16)-b_side*.32
				if rock_idx%2==1 and not _near_path(fl_p) and _stable(field,fl_p,rh,.14):
					result.flower.append(_transform(Vector3(fl_p.x,rh,fl_p.y),b_ang-.8,Vector3.ONE*(.92+.12*float(rock_idx%3))))
	# Composed shrubs near path curves, stone bench, Taihu stone & bamboo (leaving central meadows open & serene!):
	for LawnSpec in [
		[Vector2(-10.1,4.2),Vector3(.98,.88,.96),.4,true],
		[Vector2(-8.2,-4.7),Vector3(.92,.84,.90),1.5,true],
		[Vector2(-6.6,3.7),Vector3(.86,.80,.86),1.9,false],
		[Vector2(-.5,4.8),Vector3(1.04,.92,1.02),1.1,true],
		[Vector2(.15,5.55),Vector3(.74,.70,.74),2.4,false],
		[Vector2(10.6,1.3),Vector3(.90,.82,.88),2.6,true],
		[Vector2(12.8,-1.8),Vector3(.84,.78,.84),1.2,true],
		[Vector2(12.2,5.2),Vector3(.98,.86,.96),.7,false],
		[Vector2(16.6,2.8),Vector3(.88,.80,.86),2.1,false],
	]:
		var lp:Vector2=LawnSpec[0]
		if Data.chunk_of(Vector2i(lp.floor()))==chunk:
			var l_surf:Dictionary=field.surface_at(lp)
			if not l_surf.is_empty() and int(l_surf.water)<0 and _stable(field,lp,float(l_surf.height),.42):
				var lh:float=float(l_surf.height)
				var l_scale:Vector3=LawnSpec[1]
				var l_yaw:float=float(LawnSpec[2])
				var l_pose:Transform3D=_transform(Vector3(lp.x,lh-.02,lp.y),l_yaw,l_scale)
				if _supported_shrub(field,l_pose,lh):
					result.bush.append(l_pose)
					if bool(LawnSpec[3]):
						var fl_off:=lp+Vector2(cos(l_yaw+1.1),sin(l_yaw+1.1))*.44
						if not _near_path(fl_off) and _stable(field,fl_off,lh,.14):
							result.flower.append(_transform(Vector3(fl_off.x,lh,fl_off.y),l_yaw+1.9,Vector3.ONE*.94))
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
			var house_clear:=_near_path(p) or _in_outcrop_hull(p) or ((p-Vector2(-4.85,8.45))/Vector2(4.35,2.25)).length()<1.05 or p.distance_to(Vector2(-11,-7))<2.0 or p.distance_to(Vector2(-9.6,-5.4))<1.95 or p.distance_to(Vector2(-7.2,-6.5))<1.75
			# Broad lawn stays a quiet velvety colour block (留白), with tightly grouped wildflower & shrub pockets only in high-cluster zones!
			if not house_clear and cluster>.66 and random_at(cell,data.seed,4)<.11:
				for bloom in 2:
					var flower_at:=p+Vector2(sin(bloom*2.4+angle),cos(bloom*2.4+angle))*.24
					if _stable(field,flower_at,h,.14):result.flower.append(_transform(Vector3(flower_at.x,h,flower_at.y),angle+bloom*1.3,Vector3.ONE*(.84+bloom*.14)))
			if not house_clear and cluster>.64 and random_at(cell,data.seed,6)<.055:
				var b_sc:=lerpf(.80,1.04,random_at(cell,data.seed,61))
				var pose:=_transform(origin-Vector3(0,.02,0),angle,Vector3(b_sc,b_sc*.88,b_sc))
				if _supported_shrub(field,pose,h) and _clear_of_rim(pose):
					result.bush.append(pose)
					var sub_p:=p+Vector2(cos(angle+1.8),sin(angle+1.8))*.42
					if _stable(field,sub_p,h,.18):
						result.grass_clump.append(_transform(Vector3(sub_p.x,h,sub_p.y),angle+.7,Vector3.ONE*.90))
			if not house_clear and cluster>.70 and random_at(cell,data.seed,141)<.035 and _stable(field,p,h,.52):
				result.grass_clump.append(_transform(origin,angle,Vector3.ONE*(.82+random_at(cell,data.seed,142)*.24)))
			if not house_clear and random_at(cell,data.seed,7)<.010 and (p.length()>9.5 or p.y<-3.0) and _stable(field,p,h,.95):
				var r_scale:=lerpf(.96,1.18,random_at(cell,data.seed,145))
				var pose:=_transform(origin-Vector3(0,.09,0),angle,Vector3(1.04,.80,1.00)*r_scale)
				if data.sculpt_base_enabled:
					var seated:=preload("res://scripts/terrain_editor/surface_stone_support.gd").seat(field,assets.surface_rock[0].mesh,pose)
					if not seated.is_empty():result.surface_rock.append(seated.pose)
				else:result.surface_rock.append(pose)
	# Composed trees are terrain-anchored modules, and disappear when their support is edited away.
	# A main grove climbs the rear shelves; a smaller waterside pair balances
	# it. The single rear pine is a quiet accent, leaving the pond and route open.
	for spec in [
		[Vector2(-15.6,-3.2),Vector3(.90,1.00,.90),"tree",6.00],
		[Vector2(-17.4,-7.1),Vector3(.96,.94,.96),"tree_b",4.20],
		[Vector2(-13.8,-8.6),Vector3(.94,.92,.94),"tree_b",3.40],
		[Vector2(-3.8,-7.8),Vector3(.96,.94,.96),"tree_b",4.40],
		[Vector2(15.4,1.8),Vector3(.96,.94,.96),"tree",5.05],
		[Vector2(14.8,-.9),Vector3(.94,.92,.94),"tree_b",3.20],
	]:
		var p:Vector2=spec[0]
		if Data.chunk_of(Vector2i(p.floor()))!=chunk:continue
		var sample:Dictionary=field.surface_at(p)
		if sample.is_empty() or sample.water>=0 or _near_path(p):continue
		if not _stable(field,p,float(sample.height),.6):continue
		var tree_kind:String=spec[2]
		var box:AABB=assets[tree_kind][0].mesh.get_aabb()
		var size:Vector3=spec[1]*(float(spec[3])/box.size.y)
		var th:float=float(sample.height)
		var yaw:float=(.28+PI*.5+(random_at(Vector2i(p.floor()),data.seed,77)-.5)*.6) if tree_kind=="tree_b" else p.x*1.37+p.y*.71
		result[tree_kind].append(_transform(Vector3(p.x,th-box.position.y*size.y-.04,p.y),yaw,size))
		# Layered Tiny-Glade root-collar garden around each hero tree (big + small shrubs, fern tufts & wildflower sprays):
		var collar_specs:Array=[
			[0.0, .82, Vector3(1.06,.94,1.04), true],
			[0.52, .68, Vector3(.74,.68,.72), false],
			[2.35, .78, Vector3(.90,.82,.88), true],
		]
		for tb_i in collar_specs.size():
			var cs:Array=collar_specs[tb_i]
			var tb_a:=p.x*.5+float(cs[0])
			var tb_p:=p+Vector2(cos(tb_a),sin(tb_a))*float(cs[1])
			var tb_s:Dictionary=field.surface_at(tb_p)
			if not tb_s.is_empty() and int(tb_s.water)<0 and absf(float(tb_s.height)-th)<.05 and not _near_path(tb_p):
				var tb_pose:=_transform(Vector3(tb_p.x,th-.02,tb_p.y),tb_a+float(tb_i),cs[2])
				if _supported_shrub(field,tb_pose,th):
					result.bush.append(tb_pose)
					if bool(cs[3]):
						var fl_at:=tb_p+Vector2(cos(tb_a+.9),sin(tb_a+.9))*.38
						if not _near_path(fl_at) and _stable(field,fl_at,th,.14):
							result.flower.append(_transform(Vector3(fl_at.x,th,fl_at.y),tb_a*1.7,Vector3.ONE*.95))
						var fn_at:=tb_p+Vector2(cos(tb_a-.8),sin(tb_a-.8))*.34
						if not _near_path(fn_at) and _stable(field,fn_at,th,.18):
							result.grass_clump.append(_transform(Vector3(fn_at.x,th,fn_at.y),tb_a*2.1,Vector3.ONE*.92))
	# Two nestled limestone boulders at the East foot of the front-left promontory step (Ref 1):
	for b_spec in [[Vector2(-1.10,6.50),Vector3(1.42,1.18,1.32),.62],[Vector2(-.48,5.62),Vector3(1.02,.88,.96),2.15]]:
		var bp:Vector2=b_spec[0]
		if Data.chunk_of(Vector2i(bp.floor()))!=chunk:continue
		var bs:Dictionary=field.surface_at(bp)
		var b_up:Dictionary=field.surface_at(Vector2(-2.6,6.4))
		if not bs.is_empty() and int(bs.water)<0 and not b_up.is_empty() and float(b_up.height)-float(bs.height)>1.2:
			result.surface_rock.append(_transform(Vector3(bp.x,float(bs.height)-.08,bp.y),float(b_spec[2]),b_spec[1]))
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
				var legacy_growth:bool=growth>=.45 and ((p-Vector2(-5.90,7.95))/Vector2(6.65,4.65)).length()>1.10 and random_at(cell,data.seed,81)<=.08
				if legacy_growth:
					var tuft:=p-out*.70
					var tuft_ground:Dictionary=field.surface_at(tuft)
					if not tuft_ground.is_empty() and tuft_ground.water<0 and absf(tuft_ground.height-h)<.01 and _stable(field,tuft,h,.52):
						result.grass_clump.append(_transform(Vector3(tuft.x,h,tuft.y),p.x+p.y,Vector3.ONE*.90))
				# Reference 01-04 keeps cliff faces clean and chiseled without heavy
				# raycast vine chains; crevice shrubs on _columns provide the ledge greenery.
				var patch:Dictionary=_vine_patch(p,h,data.seed)
				if patch.is_empty() or patch.get("omit",false):continue

	for stone:Dictionary in _mass:
		if Data.chunk_of(stone.cell)!=chunk:continue
		if not stone.has("mesh"):result[stone.kind].append(stone.pose)
		# Seat clustered cliff-ledge shrubs & companion rocks on protruding terrace shelves.
		if stone.get("is_shoulder",false) and stone.get("has_ledge_bush",false):
			var sh_cell:Vector2i=stone.cell
			var sh_salt:=roundi(stone.pose.origin.x*11.0+stone.pose.origin.z*7.0)
			var ledge_pos:Vector3=stone.ledge_point
			var sh_scale:=lerpf(1.04,1.36,random_at(sh_cell,data.seed,3201+sh_salt))
			result.bush.append(_transform(ledge_pos,random_at(sh_cell,data.seed,3202+sh_salt)*TAU,Vector3(sh_scale*.96,sh_scale*1.04,sh_scale*.92)))
			if stone.has("ledge_tangent"):
				var l_tan:Vector3=stone.ledge_tangent
				var c_scale:=sh_scale*.72
				result.bush.append(_transform(ledge_pos+l_tan*.46-Vector3(0.0,.06,0.0),random_at(sh_cell,data.seed,3203+sh_salt)*TAU,Vector3(c_scale*.96,c_scale*1.0,c_scale*.92)))
				result.grass_clump.append(_transform(ledge_pos-l_tan*.36+Vector3(0.0,.04,0.0),random_at(sh_cell,data.seed,3205+sh_salt)*TAU,Vector3.ONE*lerpf(.96,1.22,random_at(sh_cell,data.seed,3206+sh_salt))))
	var shore_regions:Dictionary=field.water_anchor_regions if not field.water_anchor_regions.is_empty() else field.water_regions
	for level:int in shore_regions:
		for loop:PackedVector2Array in shore_regions[level]:
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
						var plant:=bank+out*.24
						var reed_group:=sin(bank.x*.52+bank.y*.41+1.1)*cos(bank.y*.46-bank.x*.27)
						if reed_group>.18 and random_at(cell,data.seed,1080+block)<.095 and _stable(field,plant,level*.5,.18) and not _near_path(plant):
							var r_sc:=lerpf(.92,1.22,random_at(cell,data.seed,1081+block))
							result.reeds.append(_transform(Vector3(plant.x,level*.5,plant.y),angle+random_at(cell,data.seed,1082+block)*.8,Vector3.ONE*r_sc))
					_shore_stones(result,field,data.seed,cell,block,bank,out,angle,level*.5)
				var cell:=Vector2i(p.floor())
				var bank_cluster:=sin(p.x*.48+p.y*.39)*cos(p.y*.51-p.x*.23)
				if bank_cluster>.24 and random_at(cell,data.seed,95)<.085:
					var rp2:=p+out*.36
					if not _near_path(rp2) and _stable(field,rp2,level*.5,.20):
						result.reeds.append(_transform(Vector3(rp2.x,level*.5,rp2.y),angle,Vector3.ONE*lerpf(.95,1.25,random_at(cell,data.seed,97))))
						if random_at(cell,data.seed,98)<.45 and _stable(field,rp2+out*.28,level*.5,.16):
							result.flower.append(_transform(Vector3(rp2.x+out.x*.28,level*.5,rp2.y+out.y*.28),angle+1.2,Vector3.ONE*.92))
				var lily:=p-out*.75
				var wet:Dictionary=field.surface_at(lily)
				if not wet.is_empty() and wet.water==level and random_at(cell,data.seed,96)<.52:result.lily.append(_transform(Vector3(lily.x,level*.5+.06,lily.y),angle,Vector3.ONE*1.58))
	_path(result,field,chunk)
	_fences(result,field,chunk)
	for kind in ["grass","grass_clump","flower","surface_rock","fence","path"]:
		var lifted:Array=result[kind]
		for i in lifted.size():
			var pose:Transform3D=lifted[i]
			pose.origin.y+=_rim_lift(field,Vector2(pose.origin.x,pose.origin.z))
			lifted[i]=pose
	# Reed-like accents belong to supported pond banks; grass_clump tufts stay on lawn and cliff rims.
	for kind in ["reeds"]:
		var kept:Array=[]
		for pose:Transform3D in result[kind]:
			var at:=Vector2(pose.origin.x,pose.origin.z)
			if _water_distance(field,at,pose.origin.y)<=.85 and _stable(field,at,pose.origin.y,.18):kept.append(pose)
		result[kind]=kept
	result.grass_clump.append_array(crown_tufts)
	# Apply corridor clearance after every planting source, including the
	# terrace-foot and tree-collar pockets. Each instance remains independent.
	for kind:String in ["bush","flower","grass_clump"]:
		var kept:Array=[]
		var root_radius:float={"bush":.5,"flower":.18,"grass_clump":.22}[kind]
		for pose:Transform3D in result[kind]:
			var radius:float=root_radius*maxf(pose.basis.x.length(),pose.basis.z.length())
			if not _near_path(Vector2(pose.origin.x,pose.origin.z),.72+radius):kept.append(pose)
		result[kind]=kept
	var lilies:Array=[]
	for pose:Transform3D in result.lily:
		var supported:=true
		for part:Dictionary in assets.lily:
			for vertex:Vector3 in preload("res://scripts/terrain_editor/chunk_geometry.gd").faces_of(part.mesh):
				var at:Vector3=pose*part.pose*vertex
				var wet:Dictionary=field.surface_at(Vector2(at.x,at.z))
				if wet.is_empty() or wet.water<0 or absf(wet.height-(pose.origin.y-.06))>.01:supported=false;break
		if supported:lilies.append(pose)
	result.lily=lilies
	_chunk_cache[chunk]={"sig":chunk_sig,"result":result}
	return result
func _vine_patch(_p:Vector2,_height:float,_seed_value:int)->Dictionary:
	return {}
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
	layout_stages={}
	var t_stage:=Time.get_ticks_usec()
	var seen:Dictionary={}
	if _run_seed!=seed_value:
		_previous_runs.clear()
		_outline_run_cache.clear()
		_run_seed=seed_value
	var next_runs:Dictionary={}
	for h:float in field.land_regions:
		next_runs[h]=[]
		for loop:PackedVector2Array in field.land_regions[h]:
			var runs:Array=_stable_runs(loop,h)
			next_runs[h].append_array(runs)
			for run:Array in runs:
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
	_previous_runs=next_runs
	var stale:Array=[]
	for signature in _run_cache:
		if not seen.has(signature):stale.append(signature)
	for signature in stale:_run_cache.erase(signature)
	_merge_narrow_columns()
	_stagger_outer_faces()
	_prune_uncovered_step_sides(field)
	_prune_overlapping_buttresses()
	layout_stages.runs=(Time.get_ticks_usec()-t_stage)/1000.0;t_stage=Time.get_ticks_usec()
	preload("res://scripts/terrain_editor/rim_union.gd").apply(field,_columns,assets,fit_core_to_feet,blend_core_joints)
	field.close_unclad_dry_steps(_columns,assets)
	layout_stages.union=(Time.get_ticks_usec()-t_stage)/1000.0;t_stage=Time.get_ticks_usec()
	# Leave loose rim boulder prop placement to the player ("那种放置物件的完全可以交给玩家自己摆放").
	_outcrops=[]
	layout_stages.outcrops=0.0
	layout_stages.trim=0.0
	field._index_triangles()
	layout_stages.index=(Time.get_ticks_usec()-t_stage)/1000.0
	layout_ms=(Time.get_ticks_usec()-started)/1000.0
func _merge_shortfall(index:int,centre:Vector2)->Vector2:
	# x: which end of the slab faces the point; y: how far that end stops short of it.
	var pose:Transform3D=_columns[index].pose
	var box:AABB=assets[_columns[index].kind][0].mesh.get_aabb()
	var s:float=(Vector3(centre.x,pose.origin.y,centre.y)-pose.origin).dot(pose.basis.x.normalized())
	return Vector2(signf(s),absf(s)-pose.basis.x.length()*(box.end.x if s>0.0 else -box.position.x))
func _merge_narrow_columns()->void:
	# A narrow pillar between broad slabs reads as a splinter. It is dropped
	# when the broad slabs beside it can close over its span:
	# - a same-level slab on each side: both grow to just past the pillar centre;
	# - a same-level slab on one side and any other outer pillar on the far side:
	#   the same-level slab grows across the whole span.
	# A growing slab keeps its far end, so only the shared corner changes. The
	# pillar stays when it stands proud of the rim line of that slab (an outward
	# bump such as a small peninsula), when no broad slab is adjacent, or when
	# it carries a shoulder, or stands on a thin finger of land. Passes repeat so
	# two narrow pillars in a row both
	# fold into the slabs around them. Each decision uses the pillar and its
	# nearest neighbours only, so a distant edit cannot change it.
	var hosts:Dictionary={}
	for body:Dictionary in _mass:
		if body.has("host_edge"):hosts[body.host_edge]=true
	var changed:=false
	for pass_index:int in 4:
		var merged:Dictionary={}
		var growth:Array=[]
		var claimed:Dictionary={}
		for n:int in _columns.size():
			var narrow:Dictionary=_columns[n]
			var run:float=float(narrow.get("narrow_run",0.0))
			if run<=0.0 or hosts.has(narrow.edge) or float(narrow.get("land_span",0.0))<MERGE_MIN_LAND:continue
			var centre:Vector2=narrow.edge
			var along:Vector2=narrow.run_dir
			var same:Array[int]=[-1,-1]
			var near:Array[int]=[-1,-1]
			var same_d:Array[float]=[INF,INF]
			var near_d:Array[float]=[INF,INF]
			for i:int in _columns.size():
				var candidate:Dictionary=_columns[i]
				if i==n or candidate.is_step:continue
				var offset:Vector2=(candidate.edge as Vector2)-centre
				var lean:float=offset.dot(along)
				if is_zero_approx(lean):continue
				var side:int=0 if lean<0.0 else 1
				var d:=offset.length()
				if d<near_d[side]-.0001 or (near[side]!=-1 and absf(d-near_d[side])<=.0001 and _lex_lt(candidate.edge,_columns[near[side]].edge)):
					near[side]=i;near_d[side]=d
				if float(candidate.get("narrow_run",0.0))>0.0 or absf(float(candidate.pose.origin.y)-float(narrow.pose.origin.y))>.01:continue
				if d<same_d[side]-.0001 or (same[side]!=-1 and absf(d-same_d[side])<=.0001 and _lex_lt(candidate.edge,_columns[same[side]].edge)):
					same[side]=i;same_d[side]=d
			var limit:float=run*.5+.4
			var fits:Array[bool]=[false,false]
			var borders:Array[bool]=[false,false]
			var ends:Array[Vector2]=[Vector2.ZERO,Vector2.ZERO]
			for side:int in 2:
				if same[side]!=-1 and not claimed.has(same[side]):
					var slab:Dictionary=_columns[same[side]]
					var slab_out:Vector3=slab.outward
					ends[side]=_merge_shortfall(same[side],centre)
					fits[side]=ends[side].y<=limit and (centre-(slab.edge as Vector2)).dot(Vector2(slab_out.x,slab_out.z))<=MERGE_PROUD
				if near[side]!=-1 and not merged.has(near[side]):
					borders[side]=_merge_shortfall(near[side],centre).y<=limit
			if fits[0] and fits[1]:
				for side:int in 2:
					growth.append([same[side],ends[side].x,maxf(ends[side].y+MERGE_OVERLAP,0.0)])
					claimed[same[side]]=true
			elif fits[0]!=fits[1]:
				var side:int=0 if fits[0] else 1
				if not borders[1-side]:continue
				growth.append([same[side],ends[side].x,maxf(ends[side].y+run*.5+MERGE_OVERLAP*.5,0.0)])
				claimed[same[side]]=true
			else:
				continue
			merged[n]=true
		if merged.is_empty():break
		changed=true
		for step:Array in growth:
			var need:float=step[2]
			if need<=0.0:continue
			var column:Dictionary=_columns[int(step[0])]
			var pose:Transform3D=column.pose
			var axis:Vector3=pose.basis.x.normalized()
			var full:float=pose.basis.x.length()*assets[column.kind][0].mesh.get_aabb().size.x
			var factor:float=(full+need)/full
			pose.basis.x*=factor
			pose.origin+=axis*float(step[1])*need*.5
			column.pose=pose
			column.width=float(column.width)*factor
		var kept:Array=[]
		for i:int in _columns.size():
			if not merged.has(i):kept.append(_columns[i])
		_columns=kept
	if not changed:return
	_column_cells.clear()
	for i:int in _columns.size():_bucket_column(i)
func _column_proud(column:Dictionary)->float:
	# How far the slab face stands in front of the contour point it was placed on.
	var pose:Transform3D=column.pose
	var flat:=Vector3(column.edge.x,pose.origin.y,column.edge.y)
	return (pose.origin-flat).dot(column.outward)+float(assets[column.kind][0].crown_z)*pose.basis.z.length()
func _column_world_width(column:Dictionary)->float:
	return (column.pose as Transform3D).basis.x.length()*assets[column.kind][0].mesh.get_aabb().size.x
func _column_end(index:int,toward:Vector2)->Vector2:
	# The end of the slab that faces the point, in world XZ.
	var pose:Transform3D=_columns[index].pose
	var box:AABB=assets[_columns[index].kind][0].mesh.get_aabb()
	var s:float=(Vector3(toward.x,pose.origin.y,toward.y)-pose.origin).dot(pose.basis.x.normalized())
	var p:Vector3=pose.origin+pose.basis.x*(box.end.x if s>0.0 else box.position.x)
	return Vector2(p.x,p.z)
func _resize_column(index:int,side:float,amount:float)->void:
	# Moves one end of the slab along its own axis (positive lengthens). The other end stays.
	var column:Dictionary=_columns[index]
	var pose:Transform3D=column.pose
	var axis:Vector3=pose.basis.x.normalized()
	var full:float=pose.basis.x.length()*assets[column.kind][0].mesh.get_aabb().size.x
	var factor:float=(full+amount)/full
	pose.basis.x*=factor
	pose.origin+=axis*side*amount*.5
	column.pose=pose
	column.width=float(column.width)*factor
func _outer_neighbours(n:int)->Array[int]:
	# The outer slab next to this one on either side of its run: the nearest
	# one that faces roughly the same way, stands at a similar level and is
	# close enough to touch it. -1 where the wall ends.
	var column:Dictionary=_columns[n]
	var centre:Vector2=column.edge
	var along:Vector2=column.run_dir
	var out:Vector3=column.outward
	var width:float=_column_world_width(column)
	var found:Array[int]=[-1,-1]
	var found_d:Array[float]=[INF,INF]
	for i:int in _columns.size():
		var other:Dictionary=_columns[i]
		if i==n or other.is_step:continue
		if (other.outward as Vector3).dot(out)<STAGGER_FACING or absf(float(other.pose.origin.y)-float(column.pose.origin.y))>STAGGER_LEVEL:continue
		var offset:Vector2=(other.edge as Vector2)-centre
		var lean:float=offset.dot(along)
		if is_zero_approx(lean):continue
		var d:=offset.length()
		if d>STAGGER_LINK*(width+_column_world_width(other)):continue
		var side:int=0 if lean<0.0 else 1
		if d<found_d[side]-.0001 or (found[side]!=-1 and absf(d-found_d[side])<=.0001 and _lex_lt(other.edge,_columns[found[side]].edge)):
			found[side]=i;found_d[side]=d
	return found
func _stagger_outer_faces()->void:
	# A stretch of outer slabs standing on one face line at one width reads as
	# a guard wall. Each slab takes a role from its own width and a fixed
	# number of its own (worth up to STAGGER_SCORE_PLAY metres), so an edit
	# elsewhere cannot change it:
	# - primary: a broad slab. It steps forward and turns a few degrees, and a
	#   plain neighbour that continues its plane and offers itself to that side
	#   is taken over, so one broad face replaces two alike ones;
	# - secondary: a narrow slab. It steps back and turns, and the slabs beside
	#   it stop at its ends, so it shows as a recessed face and not as a slot;
	# - the rest shift a little either way.
	# Every step looks one slab to either side and no further, and reads the
	# slabs as they stood before the pass. Slabs that offer a shoulder hold
	# their place whether or not the shoulder is kept; so do step walls, slabs
	# cut by a fall, corner chamfers and thin fingers of land.
	if _columns.size()<2:return
	var carriers:Dictionary={}
	for body:Dictionary in _mass:
		if body.has("host_edge"):carriers[body.host_edge]=true
	var count:=_columns.size()
	var locked:=PackedByteArray();locked.resize(count)
	var role:=PackedByteArray();role.resize(count) # 0 plain, 1 primary, 2 secondary
	var beside:Array=[]
	var none:Array[int]=[-1,-1]
	for n:int in count:
		var column:Dictionary=_columns[n]
		locked[n]=1 if (column.is_step or column.get("veil",false) or float(column.get("narrow_run",0.0))>0.0 or float(column.get("land_span",0.0))<MERGE_MIN_LAND or carriers.has(column.edge)) else 0
		beside.append(_outer_neighbours(n) if not column.is_step else none)
		if locked[n]==1:continue
		var cell:Vector2i=Vector2i(roundi(column.edge.x*2.0),roundi(column.edge.y*2.0))
		var rank:float=_column_world_width(column)+random_at(cell,_run_seed,3071)*STAGGER_SCORE_PLAY
		if rank>=STAGGER_RANKS.y:role[n]=1
		elif rank<=STAGGER_RANKS.x:role[n]=2
	# A rock group is the protrusion of its stretch of wall: the faces beside a
	# slab that offers one do not step forward as well.
	for n:int in count:
		if role[n]!=1:continue
		for side:int in 2:
			var other:int=beside[n][side]
			if other!=-1 and carriers.has(_columns[other].edge):role[n]=0
	var taken:Dictionary={}
	var growth:Array=[]
	for n:int in count:
		if locked[n]==1 or role[n]!=0:continue
		var plain:Dictionary=_columns[n]
		var cell:Vector2i=Vector2i(roundi(plain.edge.x*2.0),roundi(plain.edge.y*2.0))
		var side:int=0 if random_at(cell,_run_seed,3078)<.5 else 1
		var host_index:int=beside[n][side]
		if host_index==-1 or locked[host_index]==1 or role[host_index]!=1:continue
		var host:Dictionary=_columns[host_index]
		if absf(float(plain.pose.origin.y)-float(host.pose.origin.y))>.01:continue
		if (plain.outward as Vector3).dot(host.outward)<STAGGER_ABSORB_FACING:continue
		if absf(((plain.edge as Vector2)-(host.edge as Vector2)).dot(Vector2(host.outward.x,host.outward.z)))>STAGGER_ABSORB_OFFSET:continue
		var away:Vector2=(plain.edge as Vector2)*2.0-(host.edge as Vector2)
		var reach:=_merge_shortfall(host_index,_column_end(n,away))
		if reach.y<=0.0 or _column_world_width(host)+reach.y>STAGGER_MAX_FACE:continue
		growth.append([host_index,reach.x,reach.y])
		taken[n]=true
	# The slabs beside a secondary stop at its ends.
	for n:int in count:
		if locked[n]==1 or role[n]!=2:continue
		var guest:Dictionary=_columns[n]
		var half:float=float(guest.get("run_len",0.0))*.5
		if half<=0.0:continue
		for side:int in 2:
			var other:int=beside[n][side]
			if other==-1 or locked[other]==1 or role[other]==2 or taken.has(other):continue
			var toward:Vector2=(guest.run_dir as Vector2)*(1.0 if side==1 else -1.0)
			var junction:Vector2=(guest.edge as Vector2)+toward*half
			var past:float=(junction-_column_end(other,guest.edge)).dot(toward)
			var trim:float=minf(past-STAGGER_SEAT,_column_world_width(_columns[other])*.3)
			if trim>.05:growth.append([other,_merge_shortfall(other,guest.edge).x,-trim])
	for step:Array in growth:_resize_column(int(step[0]),float(step[1]),float(step[2]))
	# Front-back steps and turns.
	for n:int in count:
		if locked[n]==1 or taken.has(n):continue
		var column:Dictionary=_columns[n]
		var cell:Vector2i=Vector2i(roundi(column.edge.x*2.0),roundi(column.edge.y*2.0))
		var amount:float=random_at(cell,_run_seed,3072)
		var shift:float=(amount-.5)*STAGGER_PLAIN
		if role[n]==1:shift=lerpf(STAGGER_PRIMARY.x,STAGGER_PRIMARY.y,amount)
		elif role[n]==2:shift=-minf(lerpf(STAGGER_SECONDARY.x,STAGGER_SECONDARY.y,amount),maxf(0.0,_column_proud(column)-STAGGER_MIN_PROUD))
		var pose:Transform3D=column.pose
		pose.origin+=(column.outward as Vector3)*shift
		if role[n]!=0:
			var turn:float=lerpf(STAGGER_YAW.x,STAGGER_YAW.y,random_at(cell,_run_seed,3076))*(1.0 if random_at(cell,_run_seed,3077)<.5 else -1.0)
			pose.basis=Basis(Vector3.UP,turn)*pose.basis
		column.pose=pose
		column.role=["plain","primary","secondary"][role[n]]
	if not taken.is_empty():
		var kept:Array=[]
		for i:int in count:
			if not taken.has(i):kept.append(_columns[i])
		_columns=kept
	_column_cells.clear()
	for i:int in _columns.size():_bucket_column(i)
func _prune_uncovered_step_sides(field)->void:
	# A source wall is usable only while its whole visible side has a crown
	# above it. Lowered holes and open notches otherwise expose its side/back
	# as a sheet. The authoritative generated wall already closes those runs.
	var removed:Dictionary={}
	var changed:=true
	while changed:
		changed=false
		var crowns:Dictionary={}
		for column:Dictionary in _columns:
			var height:float=column.pose.origin.y
			var polygon:=PackedVector2Array()
			for p:Vector2 in assets[column.kind][0].cap_polygon:
				var point:Vector3=column.pose*Vector3(p.x,0.0,p.y)
				polygon.append(Vector2(point.x,point.z))
			if not crowns.has(height):crowns[height]=[]
			crowns[height].append(polygon)
		var kept:Array=[]
		for column:Dictionary in _columns:
			if column.is_step and _has_uncovered_step_side(field,column,crowns[column.pose.origin.y]):
				removed[column.edge]=true
				changed=true
			else:kept.append(column)
		_columns=kept
	if removed.is_empty():return
	_column_cells.clear()
	for i:int in _columns.size():_bucket_column(i)
	var kept_mass:Array=[]
	for body:Dictionary in _mass:
		if body.get("is_interior",false) and removed.has(body.get("crown_edge",Vector2(INF,INF))):continue
		kept_mass.append(body)
	_mass=kept_mass
func _has_uncovered_step_side(field,column:Dictionary,crowns:Array)->bool:
	var height:float=column.pose.origin.y
	var faces:PackedVector3Array=assets[column.kind][0].faces
	for i:int in range(0,faces.size(),3):
		var a:Vector3=column.pose*faces[i]
		var b:Vector3=column.pose*faces[i+1]
		var c:Vector3=column.pose*faces[i+2]
		for point:Vector3 in [a,b,c,(a+b)*.5,(b+c)*.5,(c+a)*.5,(a+b+c)/3.0]:
			var p:=Vector2(point.x,point.z)
			if Contours.contains(field.land_regions[height],p):continue
			var receiver:Dictionary=field.surface_at(p)
			# Through-holes and the exterior retain their existing source shell.
			if receiver.is_empty() or int(receiver.water)>=0 or point.y<=float(receiver.height)+.15:continue
			var covered:=false
			for polygon:PackedVector2Array in crowns:
				if Geometry2D.is_point_in_polygon(p,polygon):covered=true;break
			# The original hole remains cut out of the joined lawn even where
			# a crown projects across it. It cannot cover this source wall.
			for hole:PackedVector2Array in field.land_regions[height]:
				if Contours._area(hole)<0.0 and Geometry2D.is_point_in_polygon(p,hole):covered=false;break
			if not covered:return true
	return false
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
func chunk_deco_digest()->Dictionary:
	var digest:Dictionary={}
	for col:Dictionary in _columns:
		var ck:=Data.chunk_of(col.cell)
		if not digest.has(ck):digest[ck]=[]
		digest[ck].append(["c",col.kind,col.pose])
	for st:Dictionary in _mass:
		var ck:=Data.chunk_of(st.cell)
		if not digest.has(ck):digest[ck]=[]
		digest[ck].append(["m",st.kind,st.pose,int(st.mesh.get_meta("join_signature",0)) if st.has("mesh") else 0])
	for oc:Dictionary in _outcrops:
		var oc_cell:=Vector2i(Vector2(oc.pose.origin.x,oc.pose.origin.z).floor())
		var ck:=Data.chunk_of(oc_cell)
		if not digest.has(ck):digest[ck]=[]
		digest[ck].append(["o",oc.kind,oc.pose])
	return digest
func _layout_terrace_accents(field,seed_value:int)->void:
	# Scatter grounded layered stone boulders along open dry interior terrace steps
	# without leaving enclosed pit bottoms or obstructing paths / lower lawn cells.
	var candidates:Array=[]
	for h:float in field.levels:
		if not field.levels.is_empty() and is_equal_approx(h,field.levels[0]):continue
		for loop:PackedVector2Array in field.land_regions.get(h,[]):
			if Contours._area(loop)<=0.0 or loop.size()<4:continue
			var n:=loop.size()
			var acc:=0.0
			for i in n:
				var a:Vector2=loop[i]
				var b:Vector2=loop[(i+1)%n]
				var seg_len:=a.distance_to(b)
				acc+=seg_len
				if seg_len<.35 or acc<2.4:continue
				var dir:=(b-a)/seg_len
				var out:=Vector2(dir.y,-dir.x)
				var mid:=(a+b)*.5
				var up:Dictionary=field.surface_at(mid-out*.25)
				var rec:Dictionary=field.surface_at(mid+out*.30)
				if up.is_empty() or rec.is_empty() or int(up.water)>=0 or int(rec.water)>=0:continue
				var bot:float=float(rec.height)
				var drop:=h-bot
				if drop<.85 or drop>2.8:continue
				# Keep accents on open terrace shelves clear of paths, water and narrow pockets.
				var shelf_ok:=true
				for dist_p:float in [1.15,1.95]:
					var s_p:Dictionary=field.surface_at(mid+out*dist_p)
					if s_p.is_empty() or int(s_p.water)>=0 or float(s_p.height)>bot+.05:
						shelf_ok=false;break
				if not shelf_ok or _near_path(mid,1.35) or _near_path(mid+out*.85,1.25):continue
				if _water_distance(field,mid,h)<1.55 or _water_distance(field,mid+out*.6,bot)<1.35:continue
				var veil_near:=false
				for v:Dictionary in field.fall_veils:
					var vl:Vector3=v.lip
					if mid.distance_to(Vector2(vl.x,vl.z))<float(v.half_width)+1.45:
						veil_near=true;break
				if veil_near:continue
				var geo_c:=Vector2i(floori(mid.x/2.6),floori(mid.y/2.6))
				var roll:=random_at(geo_c,seed_value,3061)
				if roll>=.58:continue
				var idx:=int(random_at(geo_c,seed_value,3062)*4.0)%4
				var kind:String=UNDERSIDE_KINDS[idx]
				var part:Dictionary=assets[kind][0]
				var st_h:float=float(part.body_height)
				var st_crown_z:float=float(part.crown_z)
				var st_drop:float=clampf(drop*lerpf(.18,.40,random_at(geo_c,seed_value,3063)),.20,.88)
				var st_top:float=h-st_drop
				var st_height:float=clampf((drop-st_drop+.18)*lerpf(.88,1.02,random_at(geo_c,seed_value,3064)),.88,1.76)
				var st_w:float=lerpf(1.55,2.45,random_at(geo_c,seed_value,3065))
				var st_d:float=lerpf(1.15,1.58,random_at(geo_c,seed_value,3066))
				var st_proud:float=lerpf(.22,.45,random_at(geo_c,seed_value,3068))
				var tan3:=Vector3(dir.x,0.0,dir.y)
				var out3:=Vector3(out.x,0.0,out.y)
				var frame:=Basis(-tan3,Vector3.UP,out3)
				var st_yaw:=(random_at(geo_c,seed_value,3067)-.5)*.10
				var st_basis:=frame*Basis(Vector3.UP,st_yaw)*Basis(Vector3.RIGHT,.06)*Basis.from_scale(Vector3(st_w,st_height/st_h,st_d))
				var st_origin:=Vector3(mid.x,st_top,mid.y)+out3*(st_proud-st_crown_z*st_d)
				var comp_item:Dictionary={}
				if drop>=1.0:
					var side_sign:=-1.0 if random_at(geo_c,seed_value,3070)<.5 else 1.0
					var mid2:Vector2=mid+dir*(side_sign*lerpf(.72,1.15,random_at(geo_c,seed_value,3071)))
					var up2:Dictionary=field.surface_at(mid2-out*.25)
					var rec2:Dictionary=field.surface_at(mid2+out*.30)
					if not up2.is_empty() and not rec2.is_empty() and int(up2.water)<0 and int(rec2.water)<0 and absf(float(up2.height)-h)<=.05 and float(rec2.height)<=bot+.05 and not _near_path(mid2,1.35) and not _near_path(mid2+out*.85,1.25) and _water_distance(field,mid2,h)>=1.55:
						var kind2:String=UNDERSIDE_KINDS[(idx+1+int(random_at(geo_c,seed_value,3072)*3.0))%4]
						var part2:Dictionary=assets[kind2][0]
						var st2_h:float=float(part2.body_height)
						var st2_crown_z:float=float(part2.crown_z)
						var st2_drop:float=clampf(st_drop*lerpf(.35,.55,random_at(geo_c,seed_value,3073)),.10,.36)
						var st2_top:float=h-st2_drop
						var st2_height:float=clampf((drop-st2_drop+.10)*lerpf(.78,.94,random_at(geo_c,seed_value,3074)),.78,1.48)
						var st2_w:float=lerpf(1.18,1.72,random_at(geo_c,seed_value,3075))
						var st2_d:float=lerpf(.92,1.28,random_at(geo_c,seed_value,3076))
						var st2_proud:float=lerpf(.14,.32,random_at(geo_c,seed_value,3077))
						var st2_basis:=frame*Basis(Vector3.UP,-st_yaw*.7)*Basis(Vector3.RIGHT,.05)*Basis.from_scale(Vector3(st2_w,st2_height/st2_h,st2_d))
						var st2_origin:=Vector3(mid2.x,st2_top,mid2.y)+out3*(st2_proud-st2_crown_z*st2_d)
						comp_item={"kind":kind2,"pose":Transform3D(st2_basis,st2_origin),"cell":Vector2i(mid2.floor()),"is_shoulder":true,"is_interior":true,"has_ledge_bush":false,"crown_edge":mid2}
				var score:=1.0-roll+drop*.15
				candidates.append({"kind":kind,"pose":Transform3D(st_basis,st_origin),"cell":Vector2i(mid.floor()),"is_shoulder":true,"is_interior":true,"has_ledge_bush":false,"crown_edge":mid,"score":score,"companion":comp_item})
				acc=0.0
	for i in candidates.size():
		var c_i:Dictionary=candidates[i]
		var p_i:Vector2=Vector2((c_i.pose as Transform3D).origin.x,(c_i.pose as Transform3D).origin.z)
		var win:=true
		for j in candidates.size():
			if i==j:continue
			var c_j:Dictionary=candidates[j]
			var p_j:Vector2=Vector2((c_j.pose as Transform3D).origin.x,(c_j.pose as Transform3D).origin.z)
			if p_i.distance_to(p_j)<5.4 and float(c_j.score)>float(c_i.score):
				win=false;break
		if win:
			var kept_item:Dictionary=c_i.duplicate()
			var comp_keep:Dictionary=kept_item.get("companion",{})
			kept_item.erase("score")
			kept_item.erase("companion")
			_mass.append(kept_item)
			if not comp_keep.is_empty():
				_mass.append(comp_keep)
func _prune_overlapping_buttresses()->void:
	# Purely local 2-hop neighborhood winner selection (propagation strictly <= 7.5m, zero global domino cascade),
	# allowing staggered high Tier-2 and low Tier-3 shoulders >= 0.65m apart in Y to nest down to 2.25m XZ:
	var kept:Array=[]
	var ext_shoulders:Array=[]
	var ext_roots:Array=[]
	var fillers:Array=[]
	for item:Dictionary in _mass:
		if item.get("is_interior",false):
			kept.append(item)
		elif item.get("filler",false):
			fillers.append(item)
		elif item.get("is_shoulder",false):
			ext_shoulders.append(item)
		else:
			ext_roots.append(item)
	var n_sh:=ext_shoulders.size()
	var sh_pos:Array[Vector2]=[]
	var sh_y:=PackedFloat32Array()
	var sh_prio:=PackedFloat32Array()
	for sh:Dictionary in ext_shoulders:
		var orig:Vector3=(sh.pose as Transform3D).origin
		sh_pos.append(Vector2(orig.x,orig.z))
		sh_y.append(orig.y)
		var tie:=1e-4*fposmod(sin(orig.x*12.9898+orig.z*78.233)*43758.5453,1.0)
		sh_prio.append(float(sh.get("priority",0.0))+tie)
	var state:=PackedInt32Array();state.resize(n_sh) # 0=undecided, 1=kept, -1=suppressed
	var sh_anchors:Array[Vector2]=[]
	for pass_i in 2:
		var round_winners:Array[int]=[]
		for i in n_sh:
			if state[i]!=0:continue
			var blocked:=false
			for j in n_sh:
				if i==j or state[j]==-1:continue
				var conflict_r:float=5.25
				if sh_pos[i].distance_to(sh_pos[j])<conflict_r and (state[j]==1 or sh_prio[j]>sh_prio[i]):
					blocked=true;break
			if not blocked:round_winners.append(i)
		for i:int in round_winners:
			state[i]=1
			sh_anchors.append(sh_pos[i])
			kept.append(ext_shoulders[i])
		for i in n_sh:
			if state[i]!=0:continue
			for w:int in round_winners:
				var conflict_r:float=5.25
				if sh_pos[i].distance_to(sh_pos[w])<conflict_r:
					state[i]=-1;break
	# Groups offered by otherwise bare runs are chosen in one hop, so an edit
	# cannot change one further away than STAGGER_FILL_RADIUS from the run it
	# touched. The shoulders above never depend on them.
	for i:int in fillers.size():
		var origin:Vector3=(fillers[i].pose as Transform3D).origin
		var at:=Vector2(origin.x,origin.z)
		var rank:float=float(fillers[i].get("priority",0.0))
		var wins:=true
		for p:Vector2 in sh_pos:
			if p.distance_to(at)<STAGGER_FILL_RADIUS:wins=false;break
		if wins:
			for j:int in fillers.size():
				if j==i:continue
				var other:Vector3=(fillers[j].pose as Transform3D).origin
				var other_at:=Vector2(other.x,other.z)
				if other_at.distance_to(at)>=STAGGER_FILL_RADIUS:continue
				var other_rank:float=float(fillers[j].get("priority",0.0))
				if other_rank>rank or (other_rank==rank and _lex_lt(other_at,at)):wins=false;break
		if wins:
			sh_anchors.append(at)
			kept.append(fillers[i])
	var root_anchors:Array[Vector2]=[]
	for rt:Dictionary in ext_roots:
		var orig:Vector3=(rt.pose as Transform3D).origin
		var p2:=Vector2(orig.x,orig.z)
		var near_kept_sh:=false
		for a2:Vector2 in sh_anchors:
			if a2.distance_to(p2)<2.2:
				near_kept_sh=true;break
		if not near_kept_sh:continue
		var ok:=true
		for r2:Vector2 in root_anchors:
			if r2.distance_to(p2)<7.2:
				ok=false;break
		if ok:
			root_anchors.append(p2)
			kept.append(rt)
	_mass=kept
static func _append_sagitta_safe(runs:Array,sub:PackedVector2Array)->void:
	if sub.size()<2:return
	var a:=sub[0];var b:=sub[-1]
	var chord:=a.distance_to(b)
	if chord>4.45 and sub.size()>=3:
		var ab:=b-a;var l2:=maxf(.0001,ab.length_squared())
		var max_sag:=0.0;var best_i:=sub.size()/2
		for k in range(1,sub.size()-1):
			var t:=clampf((sub[k]-a).dot(ab)/l2,0.0,1.0)
			var d:=sub[k].distance_to(a+ab*t)
			if d>max_sag:max_sag=d;best_i=k
		if max_sag>.53:
			var left:=sub.slice(0,best_i+1)
			var right:=sub.slice(best_i)
			_append_sagitta_safe(runs,left)
			_append_sagitta_safe(runs,right)
			return
	runs.append([a,b,sub])
func _stable_runs(loop:PackedVector2Array,height:float)->Array:
	var cache_key:Array=[height,loop]
	if _outline_run_cache.has(cache_key):return _outline_run_cache[cache_key]
	var kept:Array=_runs(loop,true)
	if _outline_run_cache.size()>=256:_outline_run_cache.erase(_outline_run_cache.keys()[0])
	_outline_run_cache[cache_key]=kept
	return kept

static func _loop_distance(point:Vector2,loop:PackedVector2Array,lengths:Array[float])->Vector2:
	var result:=Vector2(0.0,INF)
	for i:int in loop.size():
		var nearest:Vector2=Geometry2D.get_closest_point_to_segment(point,loop[i],loop[(i+1)%loop.size()])
		var distance:float=point.distance_squared_to(nearest)
		if distance<result.y:result=Vector2(lengths[i]+loop[i].distance_to(nearest),distance)
	return result

static func _loop_slice(loop:PackedVector2Array,lengths:Array[float],start:float,finish:float)->PackedVector2Array:
	var result:=PackedVector2Array()
	for i:int in loop.size():
		var low:float=maxf(start,lengths[i])
		var high:float=minf(finish,lengths[i+1])
		if high<=low+.000001:continue
		var a:Vector2=loop[i]
		var b:Vector2=loop[(i+1)%loop.size()]
		var length:float=maxf(.000001,lengths[i+1]-lengths[i])
		var first:Vector2=a.lerp(b,(low-lengths[i])/length)
		if result.is_empty() or result[-1].distance_squared_to(first)>.000001:result.append(first)
		result.append(a.lerp(b,(high-lengths[i])/length))
	return result

static func _world_gate(p:Vector2)->Vector2i:
	var wx:=p.x+.34*sin(p.y*.24)
	var wz:=p.y+.34*cos(p.x*.24)
	return Vector2i(floori(wx/8.6),floori(wz/8.6))

static func _poly_len(pts:PackedVector2Array)->float:
	var total:=0.0
	for i in pts.size()-1:total+=pts[i].distance_to(pts[i+1])
	return total

static func _lex_lt(a:Vector2,b:Vector2)->bool:
	return a.x<b.x-0.00001 or (absf(a.x-b.x)<=0.00001 and a.y<b.y)

static func _ring_arc(ring:PackedVector2Array,idx_a:int,idx_b:int)->PackedVector2Array:
	var n:=ring.size()
	var pts:=PackedVector2Array()
	var k:=idx_a
	while true:
		pts.append(ring[k])
		if k==idx_b:break
		k=(k+1)%n
	return pts

static func _split_unequal_arc(pts:PackedVector2Array,max_len:float)->Array:
	var total:=_poly_len(pts)
	if total<=max_len or pts.size()<3:return [pts]
	var a0:=pts[0];var b0:=pts[-1]
	var h_val:=fposmod(sin((a0.x+b0.x)*12.9898+(a0.y+b0.y)*78.233)*43758.5453,1.0)
	var ratio:=lerpf(.38,.62,h_val)
	var target:=clampf(total*ratio,2.8,total-2.8)
	if target<=0.5 or target>=total-0.5:return [pts]
	var acc:=0.0
	var left:=PackedVector2Array([pts[0]])
	var right:=PackedVector2Array()
	for i in pts.size()-1:
		var p:=pts[i];var q:=pts[i+1]
		var seg_l:=p.distance_to(q)
		if right.is_empty():
			if acc+seg_l<target-0.0001:
				acc+=seg_l
				if left[-1].distance_squared_to(q)>0.000001:left.append(q)
			else:
				var t:=clampf((target-acc)/maxf(0.000001,seg_l),0.0,1.0)
				var split_pt:=p.lerp(q,t)
				if left[-1].distance_squared_to(split_pt)>0.000001:left.append(split_pt)
				right.append(split_pt)
				if right[-1].distance_squared_to(q)>0.000001:right.append(q)
		else:
			if right[-1].distance_squared_to(q)>0.000001:right.append(q)
	if left.size()<2 or right.size()<2:return [pts]
	var out:Array=[]
	out.append_array(_split_unequal_arc(left,max_len))
	out.append_array(_split_unequal_arc(right,max_len))
	return out

static func _runs(loop:PackedVector2Array,closed:bool=true)->Array:
	# Canonical world-lattice-anchored local contour partition:
	# Warm incremental edits and cold rebuilds always produce the exact same splits,
	# while distant runs stay pinned to local sharp corners and world grid gates.
	var runs:Array=[]
	if loop.size()<2:return runs
	var ring:=PackedVector2Array()
	for p:Vector2 in loop:
		if ring.is_empty() or ring[-1].distance_squared_to(p)>0.000001:
			ring.append(p)
	if closed and ring.size()>1 and ring[0].distance_squared_to(ring[-1])<=0.000001:
		ring.remove_at(ring.size()-1)
	var n:=ring.size()
	if n<2:return runs
	if not closed:
		var turns:Array[float]=[]
		turns.resize(n)
		turns.fill(0.0)
		var anchors:Array[int]=[0]
		for i in range(1,n-1):
			var prev_p:=ring[i-1];var cur_p:=ring[i];var next_p:=ring[i+1]
			turns[i]=absf((next_p-cur_p).angle_to(cur_p-prev_p))
			if turns[i]>0.94 or _world_gate(cur_p)!=_world_gate(prev_p):
				anchors.append(i)
		anchors.append(n-1)
		while anchors.size()>2:
			var m:=anchors.size()-1
			var seg_lens:Array[float]=[]
			for s in m:seg_lens.append(_poly_len(ring.slice(anchors[s],anchors[s+1]+1)))
			var best_s:=-1
			var best_len:=3.45
			var best_pt:=Vector2(INF,INF)
			for s in m:
				var l:=seg_lens[s]
				if l>=3.45:continue
				var li:=anchors[s];var ri:=anchors[s+1]
				if s>0 and s+1<m and turns[li]>0.94 and turns[ri]>0.94 and l>=1.25:continue
				var p:=ring[li]
				if l<best_len-0.0001 or (absf(l-best_len)<=0.0001 and _lex_lt(p,best_pt)):
					best_s=s;best_len=l;best_pt=p
			if best_s==-1:break
			var drop_idx:=-1
			if best_s==0:
				drop_idx=1
			elif best_s+1==m:
				drop_idx=best_s
			else:
				var l_sharp:=turns[anchors[best_s]]>0.94
				var r_sharp:=turns[anchors[best_s+1]]>0.94
				if l_sharp and not r_sharp:drop_idx=best_s+1
				elif r_sharp and not l_sharp:drop_idx=best_s
				else:
					var prev_len:=seg_lens[best_s-1]
					var next_len:=seg_lens[best_s+1]
					if absf(prev_len-next_len)>0.0001:drop_idx=best_s if prev_len<next_len else best_s+1
					else:drop_idx=best_s if _lex_lt(ring[anchors[best_s]],ring[anchors[best_s+1]]) else best_s+1
			anchors.remove_at(drop_idx)
		for s in anchors.size()-1:
			var sub:=ring.slice(anchors[s],anchors[s+1]+1)
			for part:PackedVector2Array in _split_unequal_arc(sub,12.2):
				_append_sagitta_safe(runs,part)
		return runs

	var turns:Array[float]=[]
	turns.resize(n)
	var anchors:Array[int]=[]
	for i in n:
		var prev_p:=ring[(i-1+n)%n];var cur_p:=ring[i];var next_p:=ring[(i+1)%n]
		turns[i]=absf((next_p-cur_p).angle_to(cur_p-prev_p))
		if turns[i]>0.94 or _world_gate(cur_p)!=_world_gate(prev_p):
			anchors.append(i)
	if anchors.size()<2:
		var cum:Array[float]=[0.0]
		for i in n:cum.append(cum[-1]+ring[i].distance_to(ring[(i+1)%n]))
		var perim:float=cum[-1]
		var a0:=0
		if anchors.is_empty():
			for i in range(1,n):
				if _lex_lt(ring[i],ring[a0]):a0=i
		else:
			a0=anchors[0]
		var a1:=(a0+1)%n
		var best_opp:=INF
		for i in n:
			if i==a0:continue
			var d_arc:=absf(absf(cum[i]-cum[a0])-0.5*perim)
			if d_arc<best_opp:best_opp=d_arc;a1=i
		anchors=[mini(a0,a1),maxi(a0,a1)]
	while anchors.size()>2:
		var m:=anchors.size()
		var seg_lens:Array[float]=[]
		for s in m:seg_lens.append(_poly_len(_ring_arc(ring,anchors[s],anchors[(s+1)%m])))
		var best_s:=-1
		var best_len:=3.45
		var best_pt:=Vector2(INF,INF)
		for s in m:
			var l:=seg_lens[s]
			if l>=3.45:continue
			var li:=anchors[s];var ri:=anchors[(s+1)%m]
			if turns[li]>0.94 and turns[ri]>0.94 and l>=1.25:continue
			var p:=ring[li]
			if l<best_len-0.0001 or (absf(l-best_len)<=0.0001 and _lex_lt(p,best_pt)):
				best_s=s;best_len=l;best_pt=p
		if best_s==-1:break
		var left_idx:=best_s
		var right_idx:=(best_s+1)%m
		var l_sharp:=turns[anchors[left_idx]]>0.94
		var r_sharp:=turns[anchors[right_idx]]>0.94
		var drop_idx:=right_idx
		if l_sharp and not r_sharp:drop_idx=right_idx
		elif r_sharp and not l_sharp:drop_idx=left_idx
		else:
			var prev_len:=seg_lens[(best_s-1+m)%m]
			var next_len:=seg_lens[(best_s+1)%m]
			if absf(prev_len-next_len)>0.0001:drop_idx=left_idx if prev_len<next_len else right_idx
			else:drop_idx=left_idx if _lex_lt(ring[anchors[left_idx]],ring[anchors[right_idx]]) else right_idx
		anchors.remove_at(drop_idx)
	var min_k:=0
	for k in range(1,anchors.size()):
		if _lex_lt(ring[anchors[k]],ring[anchors[min_k]]):min_k=k
	if min_k>0:
		var rot:Array[int]=[]
		for k in anchors.size():rot.append(anchors[(min_k+k)%anchors.size()])
		anchors=rot
	for s in anchors.size():
		var sub:=_ring_arc(ring,anchors[s],anchors[(s+1)%anchors.size()])
		for part:PackedVector2Array in _split_unequal_arc(sub,12.2):
			_append_sagitta_safe(runs,part)
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
	var trimmed:=false
	for veil:Dictionary in field.fall_veils:
		if external_only and not veil.external:continue
		var lip:Vector3=veil.lip
		if not external_only and absf(lip.y-y)>1.4:continue
		var lip_xz:=Vector2(lip.x,lip.z)
		var seg_a:=a+dir*span.x
		var seg_b:=a+dir*span.y
		if Geometry2D.get_closest_point_to_segment(lip_xz,seg_a,seg_b).distance_to(lip_xz)>float(veil.half_width)+.85:continue
		var mid:=(seg_a+seg_b)*.5
		var along:=(mid-lip_xz).dot(veil.out)
		if along<-2.2 or along>2.6:continue
		var side:=absf(dir.dot(Vector2(-veil.out.y,veil.out.x)))
		var reach:=float(veil.half_width)/maxf(.45,side)+(.24 if veil.external else .08)
		var at:=(lip_xz-a).dot(dir)
		var lo:=at-reach
		var hi:=at+reach
		if hi<=span.x or lo>=span.y:continue
		trimmed=true
		if lo-span.x>=span.y-hi:span.y=minf(span.y,lo)
		else:span.x=maxf(span.x,hi)
	return span if span.y-span.x>=(.55 if trimmed else .25) else Vector2(NAN,NAN)
func _rim_run(field,a:Vector2,b:Vector2,points:PackedVector2Array,h:float,seed_value:int,mode_filter:int=-1)->void:
	# Unified 4-archetype monumental cliff assembly (Reference 01-04):
	# 1) Smoothly knitted top crown contour (zero sawtooth cogwheel notches on the grass rim)
	# 2) Tall broad vertical cliff monoliths (01) + clean full-height terrace walls
	# 3) Massive interlocking angular shoulder-buttresses (02 & 04) in cohesive geological clusters
	# 4) Colossal deep V-shaped tapering mountain roots (03) plunging into the keel
	var length:=a.distance_to(b)
	if length<.25:return
	var dir:=(b-a)/length
	var out:=Vector2(dir.y,-dir.x)
	var outward:=Vector3(out.x,0,out.y)
	var tangent:=Vector3(dir.x,0,dir.y)
	var raw_span:=Vector2(-.02,length+.02)
	var span:=_curtain_span(field,a,dir,raw_span,h,false)
	if is_nan(span.x) or span.y-span.x<.25:return
	var curtain_trimmed:bool=span!=raw_span
	# If a contour run straddles a higher terrace boundary or transitions between
	# an outer cliff (base=true) and an interior terrace step (base=false), split
	# or trim the span so each wall segment receives its full-height monolith.
	var valid_lo:=INF
	var valid_hi:=-INF
	var has_base:=false
	var has_step:=false
	var terrace_trimmed:=false
	const SAMPLES:=10
	var step_t:=(span.y-span.x)/float(SAMPLES)
	for s_idx in SAMPLES+1:
		var t:=lerpf(span.x,span.y,float(s_idx)/float(SAMPLES))
		var p_sample:=_onto(points,a+dir*clampf(t,0.0,length),out)
		var prof_sample:Dictionary=field._cliff_profile(p_sample,out)
		if absf(prof_sample.rock_top-h)<=.01:
			var is_interior_step:bool=h>.5 and float(prof_sample.top)<h-.25 and out.x>.10 and p_sample.x>-4.5 and p_sample.x<-1.5 and p_sample.y>-1.5
			var is_base:bool=bool(prof_sample.base) and not is_interior_step
			if not is_base:
				if field.surface_at(p_sample+dir*.78+out*.35).is_empty() or field.surface_at(p_sample-dir*.78+out*.35).is_empty():
					terrace_trimmed=true
					continue
			if mode_filter==-1:
				if is_base:has_base=true
				else:has_step=true
			elif mode_filter==2:
				if is_base:continue
			elif (mode_filter==1)!=is_base:
				continue
			valid_lo=minf(valid_lo,t-step_t*.85)
			valid_hi=maxf(valid_hi,t+step_t*.85)
		else:
			terrace_trimmed=true
	if mode_filter==-1 and has_base and has_step:
		_rim_run(field,a,b,points,h,seed_value,1)
		_rim_run(field,a,b,points,h,seed_value,0)
		return
	if valid_lo>valid_hi:return
	span.x=maxf(span.x,valid_lo)
	span.y=minf(span.y,valid_hi)
	if span.y-span.x<.22:return
	var use_len:float=span.y-span.x
	var c:=_onto(points,a+dir*(span.x+span.y)*.5,out)
	if mode_filter!=-1:
		var sub_a:=_onto(points,a+dir*clampf(span.x,0.0,length),out)
		var sub_b:=_onto(points,a+dir*clampf(span.y,0.0,length),out)
		var sub_len:=sub_a.distance_to(sub_b)
		if sub_len>=.22:
			dir=(sub_b-sub_a)/sub_len
			out=Vector2(dir.y,-dir.x)
			outward=Vector3(out.x,0,out.y)
			tangent=Vector3(dir.x,0,dir.y)
			c=_onto(points,(sub_a+sub_b)*.5,out)
	var profile:Dictionary=field._cliff_profile(c,out)
	if absf(profile.rock_top-h)>.01:return
	var outer_prof:Dictionary=profile.duplicate()
	if profile.base and not field.levels.is_empty():
		field._outer_profile(c,out,outer_prof)
	var force_interior_step:bool=h>.5 and float(profile.top)<h-.25 and out.x>.10 and c.x>-4.5 and c.x<-1.5 and c.y>-1.5
	var drop:float=maxf(1.5,h-float(profile.top)) if force_interior_step else (h-profile.bottom)
	var step:bool=force_interior_step or profile.step or (not profile.base and drop>=Contours.STEP_BLOCK_DEPTH)
	if not profile.base and not step:return
	if step and use_len>=5.85 and mode_filter<2:
		var s_a:=_onto(points,a+dir*clampf(span.x,0.0,length),out)
		var s_m:=_onto(points,a+dir*clampf((span.x+span.y)*.5,0.0,length),out)
		var s_b:=_onto(points,a+dir*clampf(span.y,0.0,length),out)
		if s_a.distance_to(s_m)>=1.85 and s_m.distance_to(s_b)>=1.85:
			_rim_run(field,s_a,s_m,points,h,seed_value,2)
			_rim_run(field,s_m,s_b,points,h,seed_value,2)
			return
	var inside:Dictionary=field.surface_at(c-out*.18)
	if inside.is_empty() or int(inside.water)>=0:
		inside=field.surface_at(c-out*.35)
	if inside.is_empty() or int(inside.water)>=0:return
	var fine_cell:=Vector2i(roundi(c.x*8.0),roundi(c.y*8.0))
	var geo_anchor:Vector2=c+out*.50
	var cell:=Vector2i(floori(geo_anchor.x/3.2),floori(geo_anchor.y/3.2))
	var col_hash:float=random_at(cell,seed_value,3021)
	var s_phase:=float(seed_value%97)*.13
	# Cohesive shanshui geological massing driven by coarse world-space fields:
	var prom_wave:float=.5+.5*sin(geo_anchor.x*.14+geo_anchor.y*.17+.5+s_phase)*cos(geo_anchor.x*.10-geo_anchor.y*.13+.3)
	var cleft_wave:float=sin(geo_anchor.x*.34-geo_anchor.y*.31+1.1+s_phase*.7)
	var relief_pulse:float=clampf(.5+.38*cleft_wave+.18*(col_hash-.5),0.0,1.0)
	var is_narrow_wedge:bool=use_len<3.10 and not step
	var is_grand_slab:bool=use_len>5.20 and not step
	var pick:=mini(BODY_KINDS.size()-1,int(random_at(cell,seed_value,3008)*BODY_KINDS.size()))
	if curtain_trimmed:
		var veil_choices:Array[int]=[3,2,1]
		pick=veil_choices[int(random_at(cell,seed_value,3007)*veil_choices.size())%veil_choices.size()]
	elif step:
		var step_choices:Array[int]=[1,5,2,4,0]
		pick=step_choices[int(random_at(cell,seed_value,3009)*step_choices.size())%step_choices.size()]
	elif is_narrow_wedge:
		var wedge_choices:Array[int]=[3,2,0,6]
		pick=wedge_choices[int(random_at(cell,seed_value,3011)*wedge_choices.size())%wedge_choices.size()]
	elif relief_pulse<.34 or prom_wave<.28:
		var bay_choices:Array[int]=[3,3,2,5]
		pick=bay_choices[int(random_at(cell,seed_value,3011)*bay_choices.size())%bay_choices.size()]
	elif is_grand_slab or prom_wave>.48 or relief_pulse>.58:
		var headland_choices:Array[int]=[4,1,7,0,2,5,6]
		pick=headland_choices[int(random_at(cell,seed_value,3010)*headland_choices.size())%headland_choices.size()]
	var kind:String=BODY_KINDS[pick]
	var part:Dictionary=assets[kind][0]
	var body_h:float=float(part.body_height)
	var crown_z:float=float(part.crown_z)
	var proud_smooth:float=clampf(prom_wave*.74+.16*sin(geo_anchor.x*.24-geo_anchor.y*.19+s_phase)+.10,0.0,1.0)
	# Measure cross-peninsula thickness purely via land occupancy so expanded fingers do not punch through:
	var land_span_d:float=0.6
	for d_p:float in [0.6,1.0,1.4,1.8,2.2,2.8,3.5,4.4]:
		if not field.surface_at(c-out*d_p).is_empty():
			land_span_d=d_p
		else:
			break
	var angle_around:=atan2(c.y+1.5,c.x)
	var allow_sh_mode:bool=mode_filter==-1 or (mode_filter==1 and use_len>=1.60)
	var is_terrace_bridge:bool=h>.5 and c.x>-5.6 and c.x<-1.8 and c.y>3.2 and out.y>.15
	var p_west:float=exp(-pow(wrapf(angle_around-2.80,-PI,PI)/.68,2.0))
	var p_wsw:float=exp(-pow(wrapf(angle_around-2.42,-PI,PI)/.52,2.0))*.94
	var p_sw:float=exp(-pow(wrapf(angle_around-1.92,-PI,PI)/.48,2.0))*.90
	var p_east:float=exp(-pow(wrapf(angle_around-.05,-PI,PI)/.64,2.0))*.95
	var p_north:float=exp(-pow(wrapf(angle_around+1.65,-PI,PI)/.58,2.0))*.86
	var prom_envelope:float=maxf(maxf(maxf(p_west,p_wsw),p_sw),maxf(p_east,p_north))
	var bottom_fall_guard:float=smoothstep(10.8,8.2,c.y) if c.x>-1.8 else 1.0
	var root_focus:float=clampf(prom_envelope*.86+prom_wave*.18,0.0,1.0)*lerpf(.52,1.0,bottom_fall_guard)
	var cluster_field:float=clampf(.52+.36*prom_envelope+.18*sin(angle_around*2.0-.65+s_phase),0.0,1.0)
	var in_rock_cluster:bool=is_terrace_bridge or (drop>=2.5 and (cluster_field>.44 or root_focus>.38))
	var is_step_corner:bool=h>.5 and c.x>-5.5 and c.x<-1.2 and c.y>3.8
	var is_step_flank:bool=h>.5 and c.x>-9.8 and c.x<-1.2 and c.y>4.0
	var true_island_d:float=maxf(maxf(float(profile.inset),float(outer_prof.inset)),land_span_d)
	var peninsula_guard:float=clampf((land_span_d-1.15)/1.55,0.0,1.0)
	var cove_tuck:float=smoothstep(.30,.04,root_focus)
	var inset_deep:float=clampf((land_span_d-1.25)/1.35,0.0,1.0)
	var prow_plunge:float=smoothstep(.38,.90,root_focus)*inset_deep
	var narrow_t:float=smoothstep(1.30,2.55,land_span_d)
	var main_proud:float=lerpf(.66,.89,clampf(prom_envelope*.52+proud_smooth*.48,0.0,1.0))-cove_tuck*.06
	var proud:float=lerpf(.68,.78,proud_smooth) if step else lerpf(lerpf(.46,.56,proud_smooth),main_proud,narrow_t)
	var span_x:float=maxf(.45,float(part.span_x))
	var span_z:float=maxf(.45,float(part.span_z))
	var min_step_w:float=2.65 if use_len>=1.85 else maxf(1.35,use_len*1.20)
	var min_outer_w:float=maxf(1.55,use_len*1.30) if use_len<2.65 else (2.05 if (mode_filter==1 or terrace_trimmed) else 3.45)
	var want_w:=clampf(use_len*1.26,min_step_w,6.45) if step else clampf(use_len*(1.32 if is_narrow_wedge else 1.24),min_outer_w,11.5)
	var depth_wave:float=.5+.5*cos(geo_anchor.x*.22-geo_anchor.y*.24+.8+s_phase)
	var want_d:=lerpf(3.45,4.42,clampf(depth_wave*.42+proud_smooth*.28+relief_pulse*.30,0.0,1.0))
	var sx:=want_w/span_x
	var sz:=want_d/span_z
	var sy:float
	var foot_y:float=profile.bottom
	var room:float=maxf(1.8,drop)
	var sh_chance:float=0.0 if (is_step_corner or is_step_flank or curtain_trimmed) else (.90 if (in_rock_cluster and use_len>=2.05) else (.44 if drop>=2.55 and use_len>=2.45 else 0.0))
	var has_shoulder:bool=allow_sh_mode and profile.base and not step and float(outer_prof.inset)>=0.90 and land_span_d>=1.65 and random_at(cell,seed_value,3030)<sh_chance
	# The earlier gates (a chance weighted by fixed compass lobes, no shoulder
	# near the two ends of the default island, and a land probe that the
	# stair-stepped contour of a gently bowed wall also fails) keep their
	# results. Any other broad outer run offers a group to the local winner
	# pass; its land probe reaches further in, so only a real nose fails it.
	var sh_first:bool=has_shoulder and not (c.x<-15.8 or c.x>16.2) and not (field.surface_at(c+dir*2.65-out*.62).is_empty() or field.surface_at(c-dir*2.65-out*.62).is_empty())
	var sh_filler:bool=not sh_first and allow_sh_mode and profile.base and not step and not (is_step_corner or is_step_flank or curtain_trimmed) and float(outer_prof.inset)>=0.90 and land_span_d>=MERGE_MIN_LAND and drop>=2.55 and use_len>=2.45 and random_at(cell,seed_value,3082)<STAGGER_FILL_SHARE and not (field.surface_at(c+dir*STAGGER_FILL_FLANK.x-out*STAGGER_FILL_FLANK.y).is_empty() or field.surface_at(c-dir*STAGGER_FILL_FLANK.x-out*STAGGER_FILL_FLANK.y).is_empty())
	if sh_filler:has_shoulder=true
	var r_drop:float=clampf(.55*(.5+.5*sin(geo_anchor.x*.34+geo_anchor.y*.38+s_phase))+.45*random_at(cell,seed_value,3031),0.0,1.0)
	var is_low_tier:bool=false
	var sh_drop:float=lerpf(1.42,2.05,r_drop) if is_step_flank else lerpf(.95,1.88,r_drop)
	if float(profile.inset)<1.55 and true_island_d>=2.1:
		sh_drop=maxf(sh_drop,1.28)
	if step:
		sx=want_w/span_x
		var step_d:=lerpf(1.75,2.35,clampf(relief_pulse*.62+random_at(cell,seed_value,3015)*.38,0.0,1.0))
		var back_chk:Dictionary=field.surface_at(c-out*1.15)
		if back_chk.is_empty() or float(back_chk.get("height",-99.0))<h-.1:
			step_d=minf(step_d,maxf(1.15,use_len*1.15))
		sz=step_d/span_z
		sy=clampf(drop/.76,1.60,3.95)
	else:
		var foot_c:float=field._profile_point(c,Contours.BOTTOM,out,outer_prof).y
		var p_a:=_onto(points,a+dir*clampf(span.x,0.0,length),out)
		var prof_a:Dictionary=field._cliff_profile(p_a,out).duplicate()
		if not field.levels.is_empty():field._outer_profile(p_a,out,prof_a)
		var foot_a:float=field._profile_point(p_a,Contours.BOTTOM,out,prof_a).y
		var p_b:=_onto(points,a+dir*clampf(span.y,0.0,length),out)
		var prof_b:Dictionary=field._cliff_profile(p_b,out).duplicate()
		if not field.levels.is_empty():field._outer_profile(p_b,out,prof_b)
		var foot_b:float=field._profile_point(p_b,Contours.BOTTOM,out,prof_b).y
		foot_y=lerpf(foot_c,foot_c*.54+.23*(foot_a+foot_b),smoothstep(1.2,2.4,land_span_d))
		room=maxf(1.65,h-foot_y-.04)
		var min_ext_veil:=99.0
		for veil_k:Dictionary in field.fall_veils:
			if not veil_k.external:continue
			var vl_k:Vector3=veil_k.lip
			min_ext_veil=minf(min_ext_veil,c.distance_to(Vector2(vl_k.x,vl_k.z)))
		var broad_span_d:float=0.6
		for d_p:float in [0.6,1.0,1.4,1.8,2.2,2.8,3.5,4.4]:
			var flank_d:=minf(d_p,2.4)
			if not field.surface_at(c-out*d_p).is_empty() and not field.surface_at(c+dir*1.45-out*flank_d).is_empty() and not field.surface_at(c-dir*1.45-out*flank_d).is_empty():
				broad_span_d=d_p
			else:
				break
		var main_t1:float=lerpf(.98,1.28,clampf(prom_envelope*.58+prom_wave*.42,0.0,1.0))+prow_plunge*.13-cove_tuck*.05
		main_t1=clampf(main_t1,.94,1.42)
		if bottom_fall_guard<0.9999:
			main_t1=lerpf(.95,main_t1,bottom_fall_guard)
		if min_ext_veil<4.8:
			main_t1=lerpf(.94,main_t1,smoothstep(1.9,4.8,min_ext_veil))
		if curtain_trimmed:main_t1=clampf(main_t1,.93,.99)
		var plunge_t:float=smoothstep(2.85,3.65,broad_span_d)
		# Every outer slab now ends at the local hull foot. The former plunge of up
		# to 42% below it left neighbours hanging at different depths.
		var tier1_frac:float=1.0
		var eff_body_h:float=lerpf(maxf(body_h,float(part.get("geometry_height",body_h))),body_h,plunge_t)
		var target_h:float=clampf(room*tier1_frac,minf(2.35,room*.96),9.85)
		sy=clampf(target_h/eff_body_h,0.85,10.50)
		sh_drop=minf(sh_drop,maxf(.88,body_h*sy-1.35))
		if sh_filler:
			sh_drop=minf(lerpf(1.0,clampf(room*STAGGER_FILL_DROP.x,1.9,STAGGER_FILL_DROP.y),pow(random_at(cell,seed_value,3074),1.3)),maxf(.88,body_h*sy-2.9))
		var near_pond_rim:bool=int(field.surface_at(c-out*1.55).get("water",-1))>=0 or int(field.surface_at(c-out*2.25).get("water",-1))>=0
		var max_safe_d:float=lerpf(clampf(proud+land_span_d*.58,1.25,4.35),4.95,smoothstep(2.4,3.8,land_span_d))
		if float(profile.inset)<1.35 and near_pond_rim:
			max_safe_d=minf(max_safe_d,maxf(1.65,float(profile.inset)+proud))
		sz=minf(sz,max_safe_d/span_z)
	var max_aspect_x:float=3.35 if land_span_d<2.8 else 2.65
	if sx>sz*max_aspect_x:sx=sz*max_aspect_x
	if sz>sx*1.95:sz=sx*1.95
	var open:=span.y-span.x
	if curtain_trimmed:sx=minf(sx,maxf(1.15,open*.88))
	var yaw_amp:float=.024 if step else (.028/maxf(1.0,want_w*.40))
	var yaw:=(random_at(fine_cell,seed_value,3005)-.5)*yaw_amp
	var width_mult:float=lerpf(1.26,1.34,random_at(cell,seed_value,3024)) if step else (1.10 if curtain_trimmed else lerpf(1.24,1.32,random_at(cell,seed_value,3024)))
	var frame:=Basis(-tangent,Vector3.UP,outward)
	var basis:=frame*Basis(Vector3.UP,yaw)*Basis.from_scale(Vector3(minf(sx*width_mult,8.35 if step else 12.5),sy,sz))
	var pose:=Transform3D(basis,Vector3(c.x,h,c.y)+outward*(proud-crown_z*sz))
	var crown_extent:=Vector2(INF,-INF)
	var cap_poly:PackedVector2Array=part.get("cap_polygon",PackedVector2Array())
	if not cap_poly.is_empty():
		for p2:Vector2 in cap_poly:
			var along:float=(pose.basis*Vector3(p2.x,0.0,p2.y)).dot(tangent)
			crown_extent.x=minf(crown_extent.x,along);crown_extent.y=maxf(crown_extent.y,along)
	else:
		for vertex:Vector3 in preload("res://scripts/terrain_editor/chunk_geometry.gd").faces_of(part.mesh):
			var along:float=(pose.basis*vertex).dot(tangent)
			crown_extent.x=minf(crown_extent.x,along);crown_extent.y=maxf(crown_extent.y,along)
	var body_extent:=crown_extent*1.125
	var crown_clear:=_curtain_span(field,Vector2(pose.origin.x,pose.origin.z),dir,body_extent,h,false)
	if is_nan(crown_clear.x):return
	if crown_clear!=body_extent:
		var crown_fit:=(crown_clear.y-crown_clear.x)/(body_extent.y-body_extent.x)
		if crown_fit<.36:return
		# Scale local X width cleanly without non-orthogonal basis shearing (prevents razor-thin fins!):
		pose.basis.x*=crown_fit
		pose.origin+=tangent*((crown_clear.x+crown_clear.y)*.5-(body_extent.x+body_extent.y)*.5*crown_fit)
	var index:=_columns.size()
	var narrow_run:float=use_len if (not step and bool(profile.base) and not curtain_trimmed and use_len<NARROW_OUTER_RUN) else 0.0
	_columns.append({"kind":kind,"pose":pose,"edge":c,"cell":Vector2i(c.floor()),"outward":outward,"tangent":tangent,"width":sx,"thickness":crown_z*sz*2.0,"height":body_h*sy,"is_step":step,"narrow_run":narrow_run,"run_dir":dir,"land_span":land_span_d,"veil":curtain_trimmed,"run_len":use_len})
	_bucket_column(index)
	# Outer Cliff Buttresses (beveled sloped shoulders integrated into adjacent cliff rock):
	var is_extreme_tip:bool=c.x<-15.8 or c.x>16.2
	if has_shoulder and (sh_filler or not is_extreme_tip):
		var sh_idx:=int(random_at(cell,seed_value,3032)*4.0)%4
		var sh_kind:String=UNDERSIDE_KINDS[sh_idx]
		var sh_part:Dictionary=assets[sh_kind][0]
		var sh_h:float=float(sh_part.body_height)
		var sh_crown_z:float=float(sh_part.crown_z)
		var sh_top:float=h-sh_drop
		var col_bottom_y:float=h-body_h*sy
		var full_wall_h:float=maxf(sh_top-foot_y+.35,sh_top-col_bottom_y+lerpf(.08,.48,root_focus))
		var is_sharp_nose:bool=field.surface_at(c+dir*2.65-out*.62).is_empty() or field.surface_at(c-dir*2.65-out*.62).is_empty()
		if full_wall_h>=2.35 and (sh_filler or not is_sharp_nose) and peninsula_guard>=.32:
			var corner_tight:float=peninsula_guard
			var sh_anchor_2d:Vector2=c
			var max_corner_w:float=lerpf(3.40,6.20,corner_tight)
			for probe_w:float in [3.2,4.2,5.2,6.2]:
				var fl_a:Dictionary=field.surface_at(sh_anchor_2d+dir*(probe_w*.44)-out*.58)
				var fl_b:Dictionary=field.surface_at(sh_anchor_2d-dir*(probe_w*.44)-out*.58)
				if fl_a.is_empty() or fl_b.is_empty():
					max_corner_w=minf(max_corner_w,probe_w-.25)
					break
			var safe_back_d:=1.0
			for probe_d:float in [1.2,1.8,2.5,3.3,4.2]:
				if not field.surface_at(sh_anchor_2d-out*probe_d).is_empty():
					safe_back_d=probe_d
				else:
					break
			var sh_w:float=clampf(use_len*lerpf(1.08,1.32,random_at(cell,seed_value,3033)),3.20,max_corner_w)
			var sh_height:float=clampf(full_wall_h,minf(2.40,room*.92),8.65)
			var bridge_tuck:float=.45 if is_terrace_bridge else 1.0
			var bold_cluster:bool=(in_rock_cluster or relief_pulse>.38) and not is_terrace_bridge and corner_tight>.42
			var base_out:float=lerpf(.72,.98,random_at(cell,seed_value,3035)) if is_low_tier else (lerpf(.54,.80,random_at(cell,seed_value,3035)) if bold_cluster else lerpf(.40,.62,random_at(cell,seed_value,3035)))
			var sh_step_out:float=base_out*lerpf(.68,1.0,corner_tight)*bridge_tuck
			var sh_proud:float=proud+sh_step_out
			var max_sh_d:float=maxf(2.55,(sh_proud+safe_back_d-.28)/.66)
			var sh_d:float=minf(minf(clampf(want_d*lerpf(.96,1.16,random_at(cell,seed_value,3034)),2.85,4.60),sh_w*1.12),max_sh_d)
			var sh_yaw:float=yaw*.5+(random_at(cell,seed_value,3037)-.5)*.032
			var sh_pitch:float=lerpf(.06,.10,random_at(cell,seed_value,3052)) if is_terrace_bridge else lerpf(.012,.032,random_at(cell,seed_value,3052))
			var sh_rot:=Basis(Vector3.UP,sh_yaw)*Basis(Vector3.RIGHT,sh_pitch)
			var sh_basis:=frame*sh_rot*Basis.from_scale(Vector3(sh_w,sh_height/sh_h,sh_d))
			var sh_origin:=Vector3(c.x,sh_top,c.y)+outward*(sh_proud-sh_crown_z*sh_d)
			var sh_box:AABB=sh_part.mesh.get_aabb()
			var sh_reach:float=absf((sh_basis.x*sh_box.size.x).dot(tangent))*.5+absf((sh_basis.z*sh_box.size.z).dot(tangent))*.5+.28
			var sh_ext:=Vector2(-sh_reach,sh_reach)
			var sh_clear:=_curtain_span(field,Vector2(sh_origin.x,sh_origin.z),dir,sh_ext,sh_top,true)
			if not is_nan(sh_clear.x):
				var sh_ok:=true
				if sh_clear!=sh_ext:
					var sh_fit:=(sh_clear.y-sh_clear.x)/(sh_ext.y-sh_ext.x)
					if sh_fit<.64:sh_ok=false
					else:
						sh_basis=sh_basis.scaled_local(Vector3(sh_fit,1.0,sh_fit))
						sh_origin+=tangent*((sh_clear.x+sh_clear.y)*.5-(sh_ext.x+sh_ext.y)*.5*sh_fit)
				if sh_ok:
					# Keep the full upper and middle slab: only its final bevel
					# seats inside the supporting rock. Never compress the whole tier.
					var join_script:=preload("res://scripts/terrain_editor/cliff_shoulder_join.gd")
					var joined:ArrayMesh=null
					var sh_pose_final:=Transform3D(sh_basis,sh_origin)
					for dy_nudge:float in [0.0,-0.0037,0.0037,-0.0083,0.0083]:
						var try_pose:=Transform3D(sh_basis,sh_origin+Vector3(0.0,dy_nudge,0.0))
						var cand_join:ArrayMesh=join_script.build(sh_part.mesh,try_pose,part.mesh,pose)
						if cand_join!=null and _is_closed_solid(cand_join):
							joined=cand_join
							sh_pose_final=try_pose
							break
					if joined!=null:
						var near_veil:=curtain_trimmed
						for veil_chk:Dictionary in field.fall_veils:
							var vl:Vector3=veil_chk.lip
							if sh_anchor_2d.distance_to(Vector2(vl.x,vl.z))<3.5:near_veil=true;break
						var allow_bush:bool=false
						var ledge_pt:Vector3=sh_pose_final.origin+sh_basis*Vector3(0.0,-.032,.22)-Vector3(0.0,.03,0.0)
						var sh_prio:float=sh_w+prom_envelope*2.2
						if sh_filler:sh_prio=-10.0+use_len*.2+random_at(cell,seed_value,3075)
						_mass.append({"kind":sh_kind,"pose":sh_pose_final,"mesh":joined,"host_edge":c,"cell":Vector2i(c.floor()),"is_shoulder":true,"is_interior":false,"priority":sh_prio,"filler":sh_filler,"has_ledge_bush":allow_bush,"ledge_point":ledge_pt,"ledge_tangent":tangent})
	elif step and drop>=1.45 and use_len>=1.75 and not curtain_trimmed and random_at(cell,seed_value,3061)<.36:
		# Staggered stepped foot boulders along interior terrace cliffs (clear of paths & ponds):
		var floor_probe:Dictionary=field.surface_at(c+out*1.35)
		if not floor_probe.is_empty() and int(floor_probe.get("water",-1))<0 and _water_distance(field,c+out*.85,float(floor_probe.get("height",h-drop)))>=1.15 and not _near_path(c+out*.95,1.15):
			var st_idx:=int(random_at(cell,seed_value,3062)*4.0)%4
			var st_kind:String=UNDERSIDE_KINDS[st_idx]
			var st_part:Dictionary=assets[st_kind][0]
			var st_h:float=float(st_part.body_height)
			var st_crown_z:float=float(st_part.crown_z)
			var st_drop:float=clampf(drop*lerpf(.24,.48,random_at(cell,seed_value,3063)),.34,1.15)
			var st_top:float=h-st_drop
			var st_height:float=clampf((drop-st_drop+.24)*lerpf(.90,1.04,random_at(cell,seed_value,3064)),1.15,2.25)
			var st_w:float=clampf(use_len*lerpf(.84,1.06,random_at(cell,seed_value,3065)),1.75,3.15)
			var st_d:float=clampf(lerpf(1.42,1.92,random_at(cell,seed_value,3066)),1.35,1.98)
			var st_yaw:float=yaw*.5
			var st_basis:=frame*Basis(Vector3.UP,st_yaw)*Basis(Vector3.RIGHT,.05)*Basis.from_scale(Vector3(st_w,st_height/st_h,st_d))
			var st_proud:float=proud+lerpf(.24,.48,random_at(cell,seed_value,3068))
			var st_origin:=Vector3(c.x,st_top,c.y)+outward*(st_proud-st_crown_z*st_d)
			var st_box:AABB=st_part.mesh.get_aabb()
			var st_reach:float=absf((st_basis.x*st_box.size.x).dot(tangent))*.5+absf((st_basis.z*st_box.size.z).dot(tangent))*.5
			var st_ext:=Vector2(-st_reach,st_reach)
			var st_clear:=_curtain_span(field,Vector2(st_origin.x,st_origin.z),dir,st_ext,h,false)
			if not is_nan(st_clear.x) and st_clear==st_ext:
				_mass.append({"kind":st_kind,"pose":Transform3D(st_basis,st_origin),"cell":Vector2i(c.floor()),"is_shoulder":true,"is_interior":true,"has_ledge_bush":false,"crown_edge":c})
static func _is_closed_solid(mesh:ArrayMesh)->bool:
	if mesh==null or mesh.get_surface_count()==0:return false
	var faces:PackedVector3Array=Geometry.faces_of(mesh)
	if faces.is_empty():return false
	var edges:Dictionary={}
	for i in range(0,faces.size(),3):
		for j in 3:
			var ka:=Vector3i((faces[i+j]*10000.0).round())
			var kb:=Vector3i((faces[i+(j+1)%3]*10000.0).round())
			if ka==kb:continue
			var key:Array=[ka,kb] if ka<kb else [kb,ka]
			edges[key]=int(edges.get(key,0))+1
	for count:int in edges.values():
		if count!=2:return false
	return not edges.is_empty()
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
				var vertices:PackedVector3Array=preload("res://scripts/terrain_editor/chunk_geometry.gd").arrays_of(assets[column.kind][0].mesh,0)[Mesh.ARRAY_VERTEX]
				for vertex:Vector3 in vertices:faces.append(column.pose*crown_remap(vertex,column.height))
	for stone:Dictionary in _mass+_outcrops:
		var mesh:Mesh=assets[stone.kind][0].mesh
		var bounds:AABB=stone.pose*mesh.get_aabb()
		if not bounds.grow(2.0).has_point(point):continue
		for vertex:Vector3 in preload("res://scripts/terrain_editor/chunk_geometry.gd").faces_of(mesh):faces.append(stone.pose*vertex)
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
	# Rhythmic limestone shore-stone necklace along pond rims & beside the cultivator (Ref 1):
	var choose:=random_at(cell,seed_value,1100+block)
	var group:=sin(bank.x*.65+bank.y*.39)*cos(bank.y*.49-bank.x*.21)
	var is_hero_shore:bool=(water_y<2.0 and bank.x<7.5 and bank.y>1.1) or (water_y>2.5 and bank.y>1.0 and bank.x>-5.5)
	if is_hero_shore:
		if choose<.22:return
	else:
		if group<-.18 or choose<.40:return
	var kind:="shore_rock"
	if (is_hero_shore and choose<.48) or (group>.22 and choose<.58):kind="shore_boulder"
	elif choose>.76:kind="shore_pebble"
	# Keep the plunge and its curtain clear of stones set into the lake.
	var wet_reach:=1.0
	for splash:Dictionary in field.splash_points:
		var centre:Vector2=Vector2(splash.center.x,splash.center.z)
		wet_reach=minf(wet_reach,smoothstep(1.2,2.4,bank.distance_to(centre)))
	var tangent:=Vector2(-out.y,out.x)
	var count:=1 if kind!="shore_pebble" else 2+int(random_at(cell,seed_value,1120+block)*2.0)
	for stone in count:
		var salt:=block*7+stone
		var along:=(random_at(cell,seed_value,1140+salt)-.5)*(.34 if kind!="shore_pebble" else .80)
		var across:float
		var size:Vector3
		var sink:float
		match kind:
			"shore_boulder":
				across=lerpf(-.22,.12,random_at(cell,seed_value,1160+salt))
				size=Vector3(lerpf(1.32,1.88,random_at(cell,seed_value,1180+salt)),lerpf(.94,1.38,random_at(cell,seed_value,1200+salt)),lerpf(1.06,1.48,random_at(cell,seed_value,1220+salt)))
				sink=.10
			"shore_pebble":
				across=lerpf(-.58,-.05,random_at(cell,seed_value,1160+salt))
				size=Vector3.ONE*lerpf(.44,.78,random_at(cell,seed_value,1180+salt))*Vector3(1.0,lerpf(.74,1.10,random_at(cell,seed_value,1200+salt)),1.0)
				sink=.05
			_:
				across=lerpf(-.36,.10,random_at(cell,seed_value,1160+salt))
				size=Vector3(lerpf(.78,1.28,random_at(cell,seed_value,1180+salt)),lerpf(.70,1.10,random_at(cell,seed_value,1200+salt)),lerpf(.70,1.02,random_at(cell,seed_value,1220+salt)))
				sink=.07
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
		if not seated.is_empty():
			result[kind].append(seated.pose)
			# Spawn 1 smaller companion cobble beside occasional bank boulders
			if kind!="shore_pebble" and random_at(cell,seed_value,1280+salt)<.42:
				var c_dir:=-1.0 if random_at(cell,seed_value,1281+salt)<.5 else 1.0
				var c_at:=at+tangent*(c_dir*lerpf(.34,.56,random_at(cell,seed_value,1282+salt)))+out*lerpf(-.16,.08,random_at(cell,seed_value,1283+salt))
				var c_size:=Vector3.ONE*lerpf(.46,.74,random_at(cell,seed_value,1284+salt))*Vector3(1.05,.82,.98)*SHORE_STONE_SCALE
				var c_basis:=Basis(Vector3.UP,yaw+1.1).scaled(c_size)
				var c_seated:=preload("res://scripts/terrain_editor/shore_stone_support.gd").seat(field,assets.shore_pebble[0].mesh,Transform3D(c_basis,Vector3(c_at.x,water_y-.05*SHORE_STONE_SCALE,c_at.y)),water_y)
				if not c_seated.is_empty():result.shore_pebble.append(c_seated.pose)
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
func _in_outcrop_hull(p:Vector2)->bool:
	for oc:Dictionary in _outcrops:
		if oc.get("kind","")=="rim_shelf":continue
		var poly:PackedVector2Array=oc.get("turf_hull",PackedVector2Array())
		if poly.size()>=3 and Geometry2D.is_point_in_polygon(p,poly):return true
	return false
func _near_path(p:Vector2,clearance:float=1.08)->bool:
	var points:=_path_points()
	for i in points.size()-1:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,points[i],points[i+1]))<clearance:return true
	return false
func _path(result:Dictionary,field,chunk:Vector2i)->void:
	var points:=_path_points()
	var step_idx:=0
	for i in points.size()-1:
		var a:Vector2=points[i]
		var b:Vector2=points[i+1]
		var seg_dir:=(b-a).normalized()
		var seg_perp:=Vector2(-seg_dir.y,seg_dir.x)
		var count:=ceili(a.distance_to(b)/1.06)
		var seg_yaw:=atan2(b.x-a.x,b.y-a.y)
		for j in count:
			step_idx+=1
			var jitter_t:=(sin(float(step_idx)*3.7)*.018)/maxf(float(count),1.0)
			var lat_off:=sin(float(step_idx)*2.1+.6)*.038
			var p:=a.lerp(b,clampf(float(j)/count+jitter_t,0.0,.98))+seg_perp*lat_off
			if Data.chunk_of(Vector2i(p.floor()))!=chunk:continue
			var sample:Dictionary=field.surface_at(p)
			if sample.is_empty() or sample.water>=0:continue
			var stone_yaw:=seg_yaw+sin(float(step_idx)*2.9)*.16
			var s_w:=1.22+.10*sin(float(step_idx)*1.9)
			var s_l:=.92+.08*cos(float(step_idx)*2.7)
			result.path.append(_transform(Vector3(p.x,sample.height+.004,p.y),stone_yaw,Vector3(s_w,1.0,s_l)))
func _fences(_result:Dictionary,_field,_chunk:Vector2i)->void:
	# Western wooden ranch fences removed for clean Oriental floating-island composition.
	return
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
			# One packed buffer upload instead of one server call per instance:
			# populate also runs on the terrain worker thread.
			var stride:=16 if mm.use_colors else 12
			var buffer:=PackedFloat32Array()
			buffer.resize(transforms.size()*stride)
			for i in transforms.size():
				var t:Transform3D=transforms[i]*part.pose
				var o:=i*stride
				buffer[o]=t.basis.x.x;buffer[o+1]=t.basis.y.x;buffer[o+2]=t.basis.z.x;buffer[o+3]=t.origin.x
				buffer[o+4]=t.basis.x.y;buffer[o+5]=t.basis.y.y;buffer[o+6]=t.basis.z.y;buffer[o+7]=t.origin.y
				buffer[o+8]=t.basis.x.z;buffer[o+9]=t.basis.y.z;buffer[o+10]=t.basis.z.z;buffer[o+11]=t.origin.z
				if mm.use_colors:
					var tone:=_stone_tone(transforms[i].origin)
					buffer[o+12]=tone.r;buffer[o+13]=tone.g;buffer[o+14]=tone.b;buffer[o+15]=tone.a
			mm.buffer=buffer
			var instance:=MultiMeshInstance3D.new()
			instance.name=kind+"_%d"%index
			instance.multimesh=mm
			instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			parent.add_child(instance)
	# Each seated heel has its own cut, while unchanged contour runs reuse
	# the cached mesh. Keep the original pose and per-instance mineral color.
	for stone:Dictionary in _mass:
		if not stone.has("mesh") or Data.chunk_of(stone.cell)!=chunk:continue
		var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.use_colors=true
		mm.mesh=stone.mesh
		mm.instance_count=1
		mm.set_instance_transform(0,stone.pose)
		mm.set_instance_color(0,_stone_tone(stone.pose.origin))
		var instance:=MultiMeshInstance3D.new()
		instance.name=stone.kind+"_joined_%d"%parent.get_child_count()
		instance.multimesh=mm
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(instance)
static func _stone_tone(origin:Vector3)->Color:
	# Subtle per-boulder mineral value & warm/cool shift (4A) so overlapping & stacked boulders separate cleanly at a glance!
	var q:=Vector3(roundf(origin.x*20.0),roundf(origin.y*20.0),roundf(origin.z*20.0))
	var h1:=fposmod(sin(q.dot(Vector3(12.9898,78.233,37.719)))*43758.5453,1.0)
	var h2:=fposmod(sin(q.dot(Vector3(39.346,11.135,83.155)))*24634.6345,1.0)
	var val:=lerpf(.910,1.090,h1)
	var warm:=lerpf(-.028,.028,h2)
	return Color(clampf(val*(1.0+warm),0.86,1.14),clampf(val,0.88,1.12),clampf(val*(1.0-warm),0.86,1.14),1.0)
