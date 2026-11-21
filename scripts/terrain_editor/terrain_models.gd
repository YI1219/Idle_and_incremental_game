class_name TerrainModels
extends RefCounted
## CC0 model parts and material palette. Canopies assemble existing oak mesh modules.
var assets:Dictionary={}
## Microseconds to bake the six rim/underside block meshes. They are instanced after that.
var block_bake_us:=0
const REFINED_CLIFF="res://assets/nature/refined/cliff_main_v4.glb"
const INTEGRATED_CLIFF="res://assets/nature/refined/cliff_integrated_main_v1.glb"
const INTEGRATED_TALL="res://assets/nature/refined/cliff_integrated_tall_v1.glb"
const REFINED_TALL="res://assets/nature/refined/cliff_tall_v2.glb"
const HUAI_TREE="res://assets/nature/trees/huai_tree.glb"
const PINE_TREE="res://assets/nature/trees/common_pine.glb"
const BOTANICAL_ATLAS="res://assets/nature/trees/botanical_foliage_atlas.png"
static var _botanical_atlas_tex:Texture2D

static func _get_botanical_atlas()->Texture2D:
	if _botanical_atlas_tex!=null:return _botanical_atlas_tex
	var abs_p:=ProjectSettings.globalize_path(BOTANICAL_ATLAS)
	var img:=Image.load_from_file(abs_p)
	if img!=null and not img.is_empty():
		img.generate_mipmaps()
		_botanical_atlas_tex=ImageTexture.create_from_image(img)
		return _botanical_atlas_tex
	_botanical_atlas_tex=load("res://assets/nature/trees/leaf_cluster.png")
	return _botanical_atlas_tex
const IDS={"rim_outcrop":REFINED_TALL,"rim_shelf":REFINED_CLIFF,"bush":"tree_oak","surface_rock":"stone_largeA","cliff_rock":"stone_largeA","shore_rock":"stone_largeD","shore_boulder":"stone_largeB","shore_pebble":"stone_largeA","path":"stone_smallFlatA","fence":"fence_simple","reeds":"plant_flatTall","lily":"lily_large","flower":"flower_yellowA","vine":"tree_oak"}
func load_assets()->void:
	if not assets.is_empty():return
	for kind in IDS:assets[kind]=_load(IDS[kind],kind)
	assets.bush=_shrub_clusters(assets.bush)
	assets.rim_outcrop=[{"mesh":preload("res://scripts/terrain_editor/procedural_shard.gd").build_rim_crag(131),"pose":Transform3D.IDENTITY,"tint":Color.WHITE}]
	assets.rim_shelf=_bluff_shelf_models()
	assets.cliff_rock=_boulder_models(2.9,Vector3(.56,.46,.52))
	assets.surface_rock=_boulder_models(8.9,Vector3(.52,.38,.48))
	assets.shore_boulder=_boulder_models(4.1,Vector3(.50,.35,.44))
	assets.shore_rock=_boulder_models(5.7,Vector3(.45,.28,.39))
	assets.shore_pebble=_boulder_models(7.3,Vector3(.35,.22,.31))
	assets.flower=_flower_models()
	assets.grass=_grass_models()
	assets.grass_clump=_grass_clump_models()
	assets.reeds=_reed_models()
	assets.lily=_lily_models()
	assets.path=_path_models()
	# Eight distinct blunt-chamfered crown monoliths + four terrace/root boulders.
	# Closed solids, baked once.
	var bake:=Time.get_ticks_usec()
	assets.cliff_column=_rock_body_models(16)
	assets.cliff_column_b=_rock_body_models(25)
	assets.cliff_column_c=_rock_body_models(34)
	assets.cliff_column_d=_rock_body_models(43)
	assets.cliff_column_e=_rock_body_models(52)
	assets.cliff_column_f=_rock_body_models(61)
	assets.cliff_column_g=_rock_body_models(70)
	assets.cliff_column_h=_rock_body_models(79)
	assets.underside_rock=_rock_body_models(88,true)
	assets.underside_rock_b=_rock_body_models(97,true)
	assets.underside_rock_c=_rock_body_models(106,true)
	assets.underside_rock_d=_rock_body_models(115,true)
	block_bake_us=Time.get_ticks_usec()-bake
	assets.tree=tree_parts()
	# Tripo-generated, Blender-processed trees (tools/art/process_tripo_asset.py).
	# Sculpted multi-bouquet bonsai cloud-pad & foliage-tuft trees matching target_ref_journey.jpg!
	var huai:=_leaf_card_tree(HUAI_TREE,1,Color(.09,.18,.13),Color(.24,.35,.23),Color(.49,.59,.39),960.0)
	if not huai.is_empty():assets.tree=huai
	var pine:=_leaf_card_tree(PINE_TREE,2,Color(.06,.14,.10),Color(.17,.28,.17),Color(.38,.48,.31),1100.0)
	assets.tree_b=pine if not pine.is_empty() else assets.tree
	var spray:Array=[]
	# Flatten retained oak lobes into pointed leaf blades. Unequal paired
	# leaves form one overlapping spray rather than three rounded beads.
	var blades:Array=[
		[Vector3(-.15,.01,.025),-.62,Vector3(.24,.42,.075)],
		[Vector3(.16,.025,.01),.70,Vector3(.23,.40,.07)],
		[Vector3(-.12,-.13,.045),-.46,Vector3(.21,.37,.07)],
		[Vector3(.13,-.16,.03),.51,Vector3(.22,.36,.075)],
		[Vector3(-.075,-.27,.055),-.28,Vector3(.17,.32,.06)],
		[Vector3(.065,-.30,.02),.30,Vector3(.16,.30,.06)],
		[Vector3(.01,-.37,.035),.06,Vector3(.13,.26,.055)],
	]
	for i in blades.size():
		var spec:Array=blades[i]
		for part:Dictionary in assets.vine:
			var box:AABB=part.mesh.get_aabb()
			var basis:=Basis(Vector3.FORWARD,float(spec[1])).scaled_local(spec[2]/box.size.max(Vector3.ONE*.0001))
			var pose:=Transform3D(basis,spec[0]-basis*(box.position+box.size*.5))
			spray.append({"mesh":part.mesh,"pose":pose,"tint":Color(.94+.10*sin(i*2.1),1.0+.06*cos(i*1.7),.94,1)})
	assets.vine=spray
	for kind in assets:
		# Retain the curved grass mesh's UVs/normals and palette texture.
		if kind not in ["tree","tree_b","bush","grass","grass_clump","reeds","underside_rock","underside_rock_b","underside_rock_c","underside_rock_d","cliff_column","cliff_column_b","cliff_column_c","cliff_column_d","cliff_column_e","cliff_column_f","cliff_column_g","cliff_column_h"]:assets[kind]=[_merge(assets[kind])]
	for sway_kind in ["grass_clump","reeds","flower"]:
		if assets.has(sway_kind) and not assets[sway_kind].is_empty():
			var sm_sway:=assets[sway_kind][0].mesh.surface_get_material(0) as ShaderMaterial
			if sm_sway!=null:
				sm_sway.set_shader_parameter("sway_strength",.058 if sway_kind=="reeds" else .036)
	assets.path[0].mesh.surface_set_material(0,_path_material())
	# Apply after merging, which intentionally replaces individual source materials.
	var rock_material:=ShaderMaterial.new()
	rock_material.shader=load("res://shaders/terrain_editor/cliff_rock.gdshader")
	preload("res://scripts/terrain_editor/material_detail.gd").bind(rock_material)
	for kind in ["cliff_rock","surface_rock","shore_rock","shore_boulder","shore_pebble","rim_outcrop","rim_shelf"]:
		var material:=rock_material.duplicate()
		material.set_shader_parameter("bank_stone",1.0 if kind.begins_with("shore_") else 0.0)
		material.set_shader_parameter("prop_kind",1.0 if kind=="rim_shelf" else (4.0 if kind=="rim_outcrop" else 0.0))
		assets[kind][0].mesh.surface_set_material(0,material)
		assets[kind][0]["faces"]=assets[kind][0].mesh.get_faces()
	# Worker-thread rebuilds read asset geometry from CPU copies only.
	for kind in assets:
		for part:Dictionary in assets[kind]:
			for key in ["mesh","render_mesh"]:
				if part.get(key) is Mesh:preload("res://scripts/terrain_editor/chunk_geometry.gd").remember_cpu(part[key])

static func _soft_pad(center:Vector3,radii:Vector3,seed_val:float,base_tint:Color,ground_base:bool=false,crown_center:Vector3=Vector3.ZERO,crown_radii:Vector3=Vector3.ZERO)->Dictionary:
	# Velvety rounded moss/cloud cushion (温润苔团/云冠): 18-sided smooth organic lobe
	# with sRGB-encoded vertex colors so decor_vertex_color.gdshader decodes exact linear sage reflectance!
	const SEG:=18
	var profile:Array[Vector2]=[Vector2(0.0,-.30),Vector2(.64,-.29),Vector2(.92,-.15),Vector2(1.0,.06),Vector2(.88,.42),Vector2(.58,.72),Vector2(.24,.89),Vector2(0.0,.94)]
	var has_macro:=crown_radii.length_squared()>.001
	var safe_macro:=crown_radii.max(Vector3.ONE*.001)
	var offset:=center
	if ground_base:offset.y=center.y+.30*radii.y
	var grid:Array=[]
	for r_i in profile.size():
		var row:Array=[]
		for s_i in SEG:
			var a:=TAU*float(s_i)/float(SEG)
			var lobe:=1.0+.07*sin(3.0*a+seed_val)+.035*sin(5.0*a+seed_val*2.3)
			var pr:Vector2=profile[r_i]
			var rr:=pr.x*lobe
			var yy:=pr.y*(1.0+.04*sin(2.0*a+seed_val*1.7)*clampf(pr.y*2.0,0.0,1.0))
			row.append(offset+Vector3(cos(a)*rr*radii.x,yy*radii.y,sin(a)*rr*radii.z))
		grid.append(row)
	var safe_r:=radii.max(Vector3.ONE*.001)
	var c_shade:=Color(.16,.22,.12)*base_tint
	var c_mid:=Color(.23,.29,.16)*base_tint
	var c_lit:=Color(.31,.36,.21)*base_tint
	var normals:Array=[]
	var colors:Array=[]
	var heights:Array=[]
	for r_i in profile.size():
		var n_row:Array=[];var c_row:Array=[];var h_row:Array=[]
		for s_i in SEG:
			var p:Vector3=grid[r_i][s_i]
			var local:=(p-offset)/safe_r
			var ell:=Vector3(local.x/safe_r.x,local.y/safe_r.y*(1.6 if local.y<0.0 else 1.0),local.z/safe_r.z)
			if ell.length_squared()<.0001:ell=Vector3.UP if local.y>=0.0 else Vector3.DOWN
			var n:=ell.normalized()
			if has_macro:
				var macro:=((p-crown_center)/safe_macro).normalized()
				n=(n*.55+macro*.35+Vector3.UP*.10).normalized()
			else:
				n=(n*.82+Vector3.UP*.18).normalized()
			var h_t:=clampf(.42+local.y*.62,0.0,1.0)
			if has_macro:
				var my:=clampf((p.y-crown_center.y)/safe_macro.y,-1.0,1.0)
				h_t=clampf(h_t*.70+(.50+my*.42)*.30,0.0,1.0)
			var col:Color=c_shade.lerp(c_mid,clampf(h_t*2.0,0.0,1.0)) if h_t<.5 else c_mid.lerp(c_lit,clampf((h_t-.5)*2.0,0.0,1.0))
			n_row.append(n);c_row.append(col);h_row.append(h_t)
		normals.append(n_row);colors.append(c_row);heights.append(h_row)
	var builder=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	for r_i in profile.size()-1:
		for s_i in SEG:
			var n_i:=(s_i+1)%SEG
			for tri:Array in [[Vector2i(r_i,s_i),Vector2i(r_i,n_i),Vector2i(r_i+1,n_i)],[Vector2i(r_i,s_i),Vector2i(r_i+1,n_i),Vector2i(r_i+1,s_i)]]:
				var ids:Array=tri.duplicate()
				var a:Vector3=grid[ids[0].x][ids[0].y];var b:Vector3=grid[ids[1].x][ids[1].y];var c:Vector3=grid[ids[2].x][ids[2].y]
				var fn:=-(b-a).cross(c-a)
				if fn.length_squared()<1e-10:continue
				var outward:Vector3=(a+b+c)/3.0-offset
				if fn.dot(outward)<0.0:
					var t:Vector2i=ids[1];ids[1]=ids[2];ids[2]=t
				for id:Vector2i in ids:
					builder.vertices.append(grid[id.x][id.y])
					builder.normals.append(normals[id.x][id.y])
					builder.colors.append(colors[id.x][id.y])
					builder.uv.append(Vector2(heights[id.x][id.y],1.0 if has_macro else .35))
	var mesh:ArrayMesh=builder.mesh()
	mesh.surface_set_material(0,_vertex_color_material())
	return {"mesh":mesh,"pose":Transform3D.IDENTITY,"tint":Color.WHITE}

static func _stone_hash(seed_val:float,k:float)->float:
	return fposmod(sin(seed_val*12.9898+k*78.233)*43758.5453,1.0)

static func _boulder_models(seed_val:float,radii:Vector3)->Array:
	# Finely Chiseled Multi-Facet Shanshui Stone (细腻多切面切削山石, aligned with Refs 01–04):
	# Crown & shoulder plane normals are compensated for radii scaling so every boulder preserves
	# true 22°–38° world-space ridge tilts: sunward top crown facets catch bright zenith/morning light,
	# adjacent bevels step softly, and the crisp terminator cuts right across the crown ridge into
	# distinctly darker cool-slate backlit faces (强明暗交界 · 顶面亮 · 背光面差异鲜明)!
	var scale3:=Vector3(maxf(.12,radii.x*.98),maxf(.10,radii.y*1.32),maxf(.12,radii.z*.96))
	var planes:Array[Plane]=[]
	var to_unit:=func(wn:Vector3,wp:Vector3)->Plane:
		var un:=(wn*scale3).normalized()
		var up:=Vector3(wp.x/scale3.x,wp.y/scale3.y,wp.z/scale3.z)
		return Plane(un,un.dot(up))
	planes.append(Plane(Vector3.DOWN,0.0))
	var top_a:=_stone_hash(seed_val,1.0)*TAU
	# 4 clean crystalline crown facets in world-proportioned space (20°–36° world tilt —
	# broad, readable planes without sliver-triangle clutter, matching Tiny Glade / Ref 04!):
	var crown_tilts:Array[float]=[.34,.58,.62,.48]
	var crown_heights:Array[float]=[.94,.88,.87,.91]
	for k in 4:
		var ca:=top_a+TAU*(float(k)+(_stone_hash(seed_val,5.0+float(k))-.5)*.22)/4.0
		var tilt:float=crown_tilts[k]*lerpf(.92,1.10,_stone_hash(seed_val,8.0+float(k)))
		var wn:=Vector3(cos(ca)*sin(tilt),cos(tilt),sin(ca)*sin(tilt)).normalized()
		var wp:=Vector3(cos(ca)*scale3.x*.16,crown_heights[k]*scale3.y,sin(ca)*scale3.z*.16)
		planes.append(to_unit.call(wn,wp))
	# 7 broad irregular primary cleavage side walls (bold sunlit vs backlit rock planes):
	var sides:=7+int(_stone_hash(seed_val,2.0)*2.0)
	var start:=_stone_hash(seed_val,3.0)*TAU
	for i in sides:
		var a:=start+TAU*float(i)/float(sides)+(_stone_hash(seed_val,10.0+i)-.5)*.34*TAU/float(sides)
		var lean:=lerpf(.16,.38,_stone_hash(seed_val,20.0+i))
		var wn:=Vector3(cos(a),lean,sin(a)).normalized()
		var reach:=lerpf(.86,1.02,_stone_hash(seed_val,30.0+i))
		var wp:=Vector3(cos(a)*reach*scale3.x,.38*scale3.y,sin(a)*reach*scale3.z)
		planes.append(to_unit.call(wn,wp))
	# 5 subtle shoulder bevels (clean bevel transitions without fragmenting main faces):
	for i in 5:
		var a:=start+TAU*(float(i)+_stone_hash(seed_val,40.0+i)*.38)/5.0
		var tilt:=lerpf(.68,.88,_stone_hash(seed_val,50.0+i))
		var wn:=Vector3(cos(a)*sin(tilt),cos(tilt),sin(a)*sin(tilt)).normalized()
		var ch_r:=lerpf(.70,.78,_stone_hash(seed_val,60.0+i))
		var wp:=Vector3(cos(a)*ch_r*scale3.x,.70*scale3.y,sin(a)*ch_r*scale3.z)
		planes.append(to_unit.call(wn,wp))
	# 4 tucked lower undercut planes:
	for i in 4:
		var a:=start+TAU*(float(i)+.42)/4.0
		var wn:=Vector3(cos(a)*.84,-.54,sin(a)*.84).normalized()
		var wp:=Vector3(cos(a)*.92*scale3.x,.11*scale3.y,sin(a)*.92*scale3.z)
		planes.append(to_unit.call(wn,wp))
	var raw:=Geometry3D.compute_convex_mesh_points(planes)
	var points:PackedVector3Array=PackedVector3Array()
	for p:Vector3 in raw:
		var dup:=false
		for q:Vector3 in points:
			if q.distance_squared_to(p)<1e-6:dup=true;break
		if not dup:points.append(p)
	var min_y:=INF
	var max_y:=-INF
	for p:Vector3 in points:
		var py:=p.y*scale3.y
		min_y=minf(min_y,py);max_y=maxf(max_y,py)
	var span_y:=maxf(.05,max_y-min_y)
	var builder=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	var base_v:=.56
	for p_idx in planes.size():
		var pl:Plane=planes[p_idx]
		var on:Array[Vector3]=[]
		for p:Vector3 in points:
			if absf(pl.distance_to(p))<.002:on.append(p)
		if on.size()<3:continue
		var c:=Vector3.ZERO
		for p:Vector3 in on:c+=p
		c/=on.size()
		var u_ax:=(on[0]-c).normalized()
		var v_ax:=pl.normal.cross(u_ax).normalized()
		on.sort_custom(func(p:Vector3,q:Vector3)->bool:return atan2((p-c).dot(v_ax),(p-c).dot(u_ax))<atan2((q-c).dot(v_ax),(q-c).dot(u_ax)))
		var world_n:=(pl.normal/scale3).normalized()
		var f_jit:=(_stone_hash(seed_val,70.0+float(p_idx))-.5)*.022
		var shade:=clampf(base_v*(.98+.04*world_n.y)+f_jit,.52,.60)
		var col:=Color(shade,shade,shade,1.0)
		for i in range(1,on.size()-1):
			var a:=on[0]*scale3-Vector3(0,min_y,0)
			var b:=on[i]*scale3-Vector3(0,min_y,0)
			var d:=on[i+1]*scale3-Vector3(0,min_y,0)
			var tri_pts:Array=[a,d,b] if (-(b-a).cross(d-a)).dot(world_n)<0.0 else [a,b,d]
			for vp:Vector3 in tri_pts:
				var h_n:=clampf(vp.y/span_y,0.0,1.0)
				var cav:=lerpf(.24,.02,smoothstep(.03,.32,h_n))+(.18 if world_n.y<-.20 else 0.0)
				builder.vertices.append(vp)
				builder.normals.append(world_n)
				builder.colors.append(col)
				builder.uv.append(Vector2(h_n,clampf(cav,0.0,.62)))
	var mesh:ArrayMesh=builder.mesh()
	# Crisp per-polygon facet normals (8.5° coplanar unification ONLY — zero 38° ridge blurring!):
	mesh=preload("res://scripts/terrain_editor/stone_normals.gd").soften(mesh,8.5,.20)
	return [{"mesh":mesh,"pose":Transform3D.IDENTITY,"tint":Color.WHITE}]

static func _emit_bluff_tri(s,a:Vector3,b:Vector3,c:Vector3,out_dir:Vector3,ca:Color,cb:Color,cc:Color,ua:Vector2,ub:Vector2,uc:Vector2)->void:
	var n:=-(b-a).cross(c-a)
	if n.length_squared()<1e-10:return
	var va:=a;var vb:=b;var vc:=c
	var c0:=ca;var c1:=cb;var c2:=cc
	var u0:=ua;var u1:=ub;var u2:=uc
	if n.dot(out_dir)<0.0:
		vb=c;vc=b;c1=cc;c2=cb;u1=uc;u2=ub;n=-n
	var fn:=n.normalized()
	s.vertices.append(va);s.normals.append(fn);s.colors.append(c0);s.uv.append(u0)
	s.vertices.append(vb);s.normals.append(fn);s.colors.append(c1);s.uv.append(u1)
	s.vertices.append(vc);s.normals.append(fn);s.colors.append(c2);s.uv.append(u2)

static func _emit_bluff_quad(s,a:Vector3,b:Vector3,c:Vector3,d:Vector3,out_dir:Vector3,ca:Color,cb:Color,cc:Color,cd:Color,ua:Vector2,ub:Vector2,uc:Vector2,ud:Vector2)->void:
	_emit_bluff_tri(s,a,b,c,out_dir,ca,cb,cc,ua,ub,uc)
	_emit_bluff_tri(s,a,c,d,out_dir,ca,cc,cd,ua,uc,ud)

static func _bluff_shelf_models()->Array:
	# C-shaped double chiseled limestone ledges wrapping the outer cliff brow of the
	# front-left promontory (Refs 01–04): inner center stays buried deep (y = -0.26) so the flat
	# promontory top is 100% seamless ground.gdshader bedrock, while outer ledges show crisp rock facets!
	var s=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	const SEG:=22
	var r_inner:Array[Vector3]=[]
	var r_rim1_t:Array[Vector3]=[]
	var r_rim1_b:Array[Vector3]=[]
	var r_crev:Array[Vector3]=[]
	var r_rim2_t:Array[Vector3]=[]
	var r_rim2_m:Array[Vector3]=[]
	var r_rim2_b:Array[Vector3]=[]
	var front_w:Array[float]=[]
	for i in SEG:
		var ang:=TAU*float(i)/float(SEG)+(_stone_hash(41.0,float(i))-.5)*.18*TAU/float(SEG)
		var ca:=cos(ang);var sa:=sin(ang)
		var wob:=1.0+.068*sin(ang*2.0-.35)+.050*cos(ang*3.0+.75)+(_stone_hash(53.0,float(i))-.5)*.048
		var cliff_side:=clampf(smoothstep(-.18,.38,sa+ca*.46),0.0,1.0)
		front_w.append(cliff_side)
		var rx:=.97*wob
		var rz:=.94*wob
		var lobe_var:=(.042*cos(ang*4.0-.6)+(_stone_hash(67.0,float(i))-.5)*.032)*cliff_side
		var cleft_dip:=(.055*sin(ang*3.0+.4)+(_stone_hash(79.0,float(i))-.5)*.030)*cliff_side
		r_inner.append(Vector3(ca*rx*.58,-.26,sa*rz*.58-.04))
		r_rim1_t.append(Vector3(ca*rx*.91,lerpf(-.24,-.03,cliff_side),sa*rz*.91))
		r_rim1_b.append(Vector3(ca*rx*(.97+lobe_var),lerpf(-.28,-.21+cleft_dip*.4,cliff_side),sa*rz*(.97+lobe_var)))
		r_crev.append(Vector3(ca*rx*.89,lerpf(-.32,-.32+cleft_dip,cliff_side),sa*rz*.89))
		r_rim2_t.append(Vector3(ca*rx*(.98-lobe_var*.5),lerpf(-.35,-.42+cleft_dip*.7,cliff_side),sa*rz*(.98-lobe_var*.5)))
		r_rim2_m.append(Vector3(ca*rx*(.99+lobe_var*.4),lerpf(-.38,-.63+cleft_dip*.6,cliff_side),sa*rz*(.99+lobe_var*.4)))
		r_rim2_b.append(Vector3(ca*rx*.87,lerpf(-.42,-.92,cliff_side),sa*rz*.87))
	var top_center:=Vector3(0.0,-.28,-.06)
	var bot_center:=Vector3(0.0,-.80,0.0)
	var c_top:=Color(.60,.60,.58,1.0)
	var c_rim_lit:=Color(.64,.64,.62,1.0)
	var c_crevice:=Color(.46,.49,.51,1.0)
	var c_lower:=Color(.57,.58,.57,1.0)
	for i in SEG:
		var ni:=(i+1)%SEG
		var fw_i:=front_w[i];var fw_n:=front_w[ni]
		var out_dir:=Vector3((r_rim1_b[i].x+r_rim1_b[ni].x)*.5,.06,(r_rim1_b[i].z+r_rim1_b[ni].z)*.5).normalized()
		var uv_flat:=Vector2(.5,0.0)
		var uv_belly:=Vector2(.5,.05)
		var uv_crev_i:=Vector2(.5,.65*fw_i)
		var uv_crev_n:=Vector2(.5,.65*fw_n)
		var uv_low_i:=Vector2(.5,.22*fw_i)
		var uv_low_n:=Vector2(.5,.22*fw_n)
		var c_r1_i:=c_top.lerp(c_rim_lit,fw_i*.90)
		var c_r1_n:=c_top.lerp(c_rim_lit,fw_n*.90)
		var c_cr_i:=c_top.lerp(c_crevice,fw_i)
		var c_cr_n:=c_top.lerp(c_crevice,fw_n)
		_emit_bluff_tri(s,top_center,r_inner[i],r_inner[ni],Vector3.UP,c_top,c_top,c_top,uv_flat,uv_flat,uv_flat)
		_emit_bluff_quad(s,r_inner[i],r_inner[ni],r_rim1_t[ni],r_rim1_t[i],Vector3.UP,c_top,c_top,c_r1_n,c_r1_i,uv_flat,uv_flat,uv_belly,uv_belly)
		_emit_bluff_quad(s,r_rim1_t[i],r_rim1_t[ni],r_rim1_b[ni],r_rim1_b[i],out_dir+Vector3.UP*.42,c_r1_i,c_r1_n,c_r1_n,c_r1_i,uv_belly,uv_belly,uv_belly,uv_belly)
		_emit_bluff_quad(s,r_rim1_b[i],r_rim1_b[ni],r_crev[ni],r_crev[i],out_dir-Vector3.UP*.55,c_r1_i,c_r1_n,c_cr_n,c_cr_i,uv_belly,uv_belly,uv_crev_n,uv_crev_i)
		_emit_bluff_quad(s,r_crev[i],r_crev[ni],r_rim2_t[ni],r_rim2_t[i],out_dir+Vector3.UP*.72,c_cr_i,c_cr_n,c_r1_n,c_r1_i,uv_crev_i,uv_crev_n,uv_belly,uv_belly)
		_emit_bluff_quad(s,r_rim2_t[i],r_rim2_t[ni],r_rim2_m[ni],r_rim2_m[i],out_dir+Vector3.UP*.14,c_r1_i,c_r1_n,c_r1_n,c_r1_i,uv_belly,uv_belly,uv_belly,uv_belly)
		_emit_bluff_quad(s,r_rim2_m[i],r_rim2_m[ni],r_rim2_b[ni],r_rim2_b[i],out_dir-Vector3.UP*.26,c_r1_i,c_r1_n,c_lower,c_lower,uv_belly,uv_belly,uv_low_n,uv_low_i)
		_emit_bluff_tri(s,bot_center,r_rim2_b[ni],r_rim2_b[i],Vector3.DOWN,c_crevice,c_lower,c_lower,uv_low_i,uv_low_n,uv_low_i)
	var built:ArrayMesh=preload("res://scripts/terrain_editor/stone_normals.gd").soften(s.mesh(),10.0,.22)
	return [{"mesh":built,"pose":Transform3D.IDENTITY,"tint":Color.WHITE}]

static func _sweep_branch_tube(builder,pts:Array[Vector3],r0:float,r1:float,sides:int,c_base:Color,c_crotch:Color,flare_root:bool=false)->void:
	# Parallel-transport tube sweep with pow(t, 0.72) taper and smooth radial
	# normals so trunks and limbs read as soft painted wood, not faceted sticks.
	var n_pts:=pts.size()
	if n_pts<2:return
	var rings:Array=[]
	var ring_n:Array=[]
	var nrm:=Vector3.RIGHT
	for i in n_pts:
		var t:=float(i)/float(n_pts-1)
		var tan:Vector3=(pts[mini(i+1,n_pts-1)]-pts[maxi(i-1,0)]).normalized()
		nrm=nrm-tan*nrm.dot(tan)
		if nrm.length_squared()<1e-6:
			var ref:=Vector3.RIGHT if absf(tan.y)>.9 else Vector3.UP
			nrm=tan.cross(ref)
		nrm=nrm.normalized()
		var binorm:=tan.cross(nrm).normalized()
		var r:=lerpf(r0,r1,pow(t,.72))
		var ring:Array[Vector3]=[]
		var norms:Array[Vector3]=[]
		for s_i in sides:
			var a:=TAU*float(s_i)/float(sides)+float(i)*.14
			var flare:=1.0
			if flare_root and i==0:
				flare=1.0+.38*cos(float(s_i)*2.0+.4)
			elif flare_root and i==1:
				flare=1.0+.10*cos(float(s_i)*2.0+.4)
			var dir_r:Vector3=nrm*cos(a)+binorm*sin(a)
			ring.append(pts[i]+dir_r*(r*flare))
			norms.append(dir_r)
		rings.append(ring)
		ring_n.append(norms)
	for i in range(n_pts-1):
		var t_seg:=float(i)/float(maxi(1,n_pts-2))
		var col_a:Color=c_base.lerp(c_crotch,smoothstep(.35,1.0,t_seg))
		var col_b:Color=c_base.lerp(c_crotch,smoothstep(.35,1.0,float(i+1)/float(maxi(1,n_pts-2))))
		if flare_root and i==0:col_a=col_a*.90
		var curr:Array[Vector3]=rings[i];var next:Array[Vector3]=rings[i+1]
		var cn:Array[Vector3]=ring_n[i];var nn:Array[Vector3]=ring_n[i+1]
		for s_i in sides:
			var ni:=(s_i+1)%sides
			var quad:Array=[[curr[s_i],cn[s_i],col_a],[curr[ni],cn[ni],col_a],[next[ni],nn[ni],col_b],[next[s_i],nn[s_i],col_b]]
			for tri:Array in [[0,1,2],[0,2,3]]:
				var a:Vector3=quad[tri[0]][0];var b:Vector3=quad[tri[1]][0];var c:Vector3=quad[tri[2]][0]
				var order:Array=tri
				if (-(b-a).cross(c-a)).dot(quad[tri[0]][1]+quad[tri[1]][1]+quad[tri[2]][1])<0.0:order=[tri[0],tri[2],tri[1]]
				for k:int in order:
					builder.vertices.append(quad[k][0])
					builder.normals.append(quad[k][1])
					builder.colors.append(quad[k][2])
					builder.uv.append(Vector2.ZERO)

static func _sculpted_tree_wood()->Dictionary:
	# Lean, slender ancient trunk with a gentle S-lean (山野古木) and a few
	# long limbs reaching out under each cloud-tier pad; wood stays visible.
	var builder=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	var c_bark:=Color(.33,.24,.17)
	var c_crotch:=Color(.24,.17,.12)
	var trunk_pts:Array[Vector3]=[
		Vector3(0.0,0.0,0.0),
		Vector3(.035,.22,.010),
		Vector3(.095,.46,.000),
		Vector3(.100,.70,-.020),
		Vector3(.040,.93,-.030),
		Vector3(-.030,1.14,-.025),
		Vector3(-.050,1.36,-.035),
		Vector3(-.030,1.56,-.040),
	]
	_sweep_branch_tube(builder,trunk_pts,.120,.034,8,c_bark,c_crotch,true)
	var limbs:Array=[
		[Vector3(.098,.74,-.020),Vector3(-.10,.88,.040),Vector3(-.32,.99,.085),Vector3(-.56,1.05,.110),.050,.020],
		[Vector3(.040,.94,-.030),Vector3(.22,1.06,-.070),Vector3(.42,1.15,-.110),Vector3(.62,1.19,-.130),.044,.018],
		[Vector3(-.030,1.16,-.025),Vector3(.06,1.27,.010),Vector3(.15,1.36,.020),Vector3(.24,1.42,.020),.036,.016],
		[Vector3(-.045,1.30,-.035),Vector3(-.18,1.38,-.10),Vector3(-.30,1.45,-.15),Vector3(-.38,1.48,-.17),.030,.014],
	]
	for l_spec:Array in limbs:
		var l_pts:Array[Vector3]=[l_spec[0],l_spec[1],l_spec[2],l_spec[3]]
		_sweep_branch_tube(builder,l_pts,float(l_spec[4]),float(l_spec[5]),6,c_bark*.96,c_crotch,false)
	var mesh:ArrayMesh=builder.mesh()
	mesh.surface_set_material(0,_vertex_color_material())
	return {"mesh":mesh,"pose":Transform3D.IDENTITY,"tint":Color.WHITE}

## Same retained CC0 tree assembly; preview callers need not bake unrelated rocks.
func tree_parts()->Array:
	var tree:Array=[_sculpted_tree_wood()]
	# Three to four flat, unequal cloud-tier pads (层云片冠) at staggered heights:
	# a broad crown tier, two lateral boughs on opposite sides and a small apex.
	var crown_c:=Vector3(.00,1.34,-.02)
	var crown_r:=Vector3(.86,.36,.62)
	var pads:Array=[
		[Vector3(.12,1.47,.00),Vector3(.66,.26,.52),1.1,Color(1.05,1.05,1.02)],
		[Vector3(-.54,1.12,.10),Vector3(.52,.22,.42),2.7,Color(.98,1.0,1.0)],
		[Vector3(.60,1.25,-.12),Vector3(.46,.21,.38),4.3,Color(1.02,1.03,1.01)],
		[Vector3(-.30,1.68,-.10),Vector3(.38,.18,.32),5.9,Color(1.07,1.07,1.03)],
	]
	for spec:Array in pads:
		tree.append(_soft_pad(spec[0],spec[1],float(spec[2]),spec[3],false,crown_c,crown_r))
	return tree

func tree_model()->Dictionary:
	return _merge(tree_parts())

func _shrub_clusters(_source:Array)->Array:
	# Fluffy Multi-Bouquet Botanical Gouache Shrub (蓬松层叠叶团灌木, aligned with Tiny Glade & main trees):
	# 1) 8-point grounded collar at y = -0.015 (r = 0.25m) gives _supported_shrub an exact, fast 8-point base check;
	# 2) 5 asymmetric 3D sub-bouquet domes composed of arched 5-vertex botanical cards (foliage_cards.gdshader)
	#    with rich interior AO crevices, sunlit outer sprigs, and gentle wind flutter!
	var cards=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	var collar_r:=.25
	var collar_y:=-.015
	var collar_c:=Vector3(0.0,.012,0.0)
	for ci in 8:
		var a0:=TAU*float(ci)/8.0
		var a1:=TAU*float((ci+1)%8)/8.0
		var p0:=Vector3(cos(a0)*collar_r,collar_y,sin(a0)*collar_r)
		var p1:=Vector3(cos(a1)*collar_r,collar_y,sin(a1)*collar_r)
		for vp:Vector3 in [collar_c,p0,p1]:
			cards.vertices.append(vp)
			cards.normals.append(Vector3.UP)
			cards.colors.append(Color(.88,0.0,.28,1.0))
			cards.uv.append(Vector2(.25,.25))
	var lobes:Array=[
		[Vector3(.03,.32,.02),Vector3(.30,.22,.28),11],
		[Vector3(-.26,.21,.09),Vector3(.26,.18,.24),9],
		[Vector3(.27,.22,-.08),Vector3(.25,.18,.23),9],
		[Vector3(-.05,.24,-.22),Vector3(.24,.18,.22),8],
		[Vector3(.07,.19,.22),Vector3(.23,.16,.22),8],
	]
	var macro_c:=Vector3(0.0,.24,0.0)
	var macro_span:=Vector3(.56,.34,.52)
	var rng:=RandomNumberGenerator.new()
	rng.seed=51827
	for l_idx in lobes.size():
		var l_spec:Array=lobes[l_idx]
		var lc:Vector3=l_spec[0]
		var lr:Vector3=l_spec[1]
		var l_count:int=int(l_spec[2])
		for k in l_count:
			var ang:=TAU*(float(k)+rng.randf_range(-.22,.22))/float(l_count)+float(l_idx)*1.17
			var elev:=lerpf(.08,.92,float(k%3)/2.0)+rng.randf_range(-.12,.12)
			var dir_l:=Vector3(cos(ang)*cos(elev*.85),sin(elev*.95)*.82+.18,sin(ang)*cos(elev*.85)).normalized()
			var centre:=lc+Vector3(dir_l.x*lr.x*.74,dir_l.y*lr.y*.70,dir_l.z*lr.z*.74)
			centre.y=maxf(.125,centre.y)
			var sub_n:=Vector3((centre.x-lc.x)/lr.x*1.35,(centre.y-lc.y)/lr.y*.88+.22,(centre.z-lc.z)/lr.z*1.35).normalized()
			var mac_n:=Vector3((centre.x-macro_c.x)/macro_span.x*1.28,(centre.y-macro_c.y)/macro_span.y*.85+.18,(centre.z-macro_c.z)/macro_span.z*1.28).normalized()
			var center_n:=(sub_n*.64+mac_n*.36).normalized()
			var tilt:=Vector3(rng.randf_range(-.75,.75),rng.randf_range(-.05,.85),rng.randf_range(-.75,.75)).normalized()
			var face:=(Vector3(center_n.x*.74,center_n.y*.66+.24,center_n.z*.74)+tilt*.20).normalized()
			var t:=face.cross(Vector3.UP if absf(face.y)<.95 else Vector3.RIGHT).normalized()
			var bt:=face.cross(t).normalized()
			if bt.y<0.0:bt=-bt;t=-t
			var roll:=rng.randf_range(-.32,.32)
			var t2:=(t*cos(roll)+bt*sin(roll)).normalized()
			var b2:=(bt*cos(roll)-t*sin(roll)).normalized()
			var sz:=rng.randf_range(.160,.208)*(1.10 if k%4==0 else 1.0)
			var sx:=sz*1.08
			var sy:=sz*.92
			var cup_arch:=center_n*(sz*.20)
			var fan_pts:Array[Vector3]=[
				centre+cup_arch,
				centre-t2*sx-b2*sy-cup_arch*.32,
				centre+t2*sx-b2*sy-cup_arch*.32,
				centre+t2*sx+b2*sy-cup_arch*.32,
				centre-t2*sx+b2*sy-cup_arch*.32,
			]
			for f_i in fan_pts.size():
				if fan_pts[f_i].y<.048:
					fan_pts[f_i].y=.048
			var cell_x:=rng.randi()%2
			var uv0:=Vector2(float(cell_x)*.5,0.0)
			var fan_uvs:Array[Vector2]=[
				uv0+Vector2(.25,.25),
				uv0+Vector2(0.0,.5),
				uv0+Vector2(.5,.5),
				uv0+Vector2(.5,0.0),
				uv0+Vector2(0.0,0.0),
			]
			var shade_var:=rng.randf_range(.95,1.06)
			var fan_nrms:Array[Vector3]=[]
			var fan_cols:Array[Color]=[]
			for fv:Vector3 in fan_pts:
				var fn_sub:=Vector3((fv.x-lc.x)/lr.x*1.35,(fv.y-lc.y)/lr.y*.88+.20,(fv.z-lc.z)/lr.z*1.35).normalized()
				var fn_mac:=Vector3((fv.x-macro_c.x)/macro_span.x*1.28,(fv.y-macro_c.y)/macro_span.y*.85+.16,(fv.z-macro_c.z)/macro_span.z*1.28).normalized()
				fan_nrms.append((fn_sub*.62+fn_mac*.38).normalized())
				var fh:=clampf((fv.y-.04)/.56,0.0,1.0)
				var shell:=clampf(((fv-macro_c)/macro_span).length(),0.0,1.15)
				var f_ao:=clampf(.32+.36*shell+.28*fh,.28,1.0)
				fan_cols.append(Color(shade_var,fh,f_ao,1.0))
			for tri_idx:Array in [[0,1,2],[0,2,3],[0,3,4],[0,4,1]]:
				for vi:int in tri_idx:
					cards.vertices.append(fan_pts[vi])
					cards.normals.append(fan_nrms[vi])
					cards.colors.append(fan_cols[vi])
					cards.uv.append(fan_uvs[vi])
	var bush_mesh:ArrayMesh=cards.mesh()
	var bush_mat:=ShaderMaterial.new()
	bush_mat.shader=load("res://shaders/terrain_editor/foliage_cards.gdshader")
	bush_mat.set_shader_parameter("leaf_atlas",_get_botanical_atlas())
	bush_mat.set_shader_parameter("leaf_shadow",Color(.13,.22,.17))
	bush_mat.set_shader_parameter("leaf_mid",Color(.30,.42,.29))
	bush_mat.set_shader_parameter("leaf_lit",Color(.62,.70,.51))
	bush_mat.set_shader_parameter("sway_strength",.028)
	bush_mat.set_shader_parameter("flutter",.010)
	bush_mat.set_shader_parameter("rim_strength",.90)
	bush_mesh.surface_set_material(0,bush_mat)
	return [{"mesh":bush_mesh,"pose":Transform3D.IDENTITY,"tint":Color.WHITE}]

func _join_crown(parts:Array)->Array:
	# The current oak source has one active foliage surface per arranged mass.
	# Preserve an unfamiliar source assembly rather than assume its indexing.
	if parts.size()!=4:return parts
	var result:Array=[]
	for part:Dictionary in parts:result.append(_crown_hull([part]))
	return result

func _crown_hull(parts:Array)->Dictionary:
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
	# The native convex shape provides an indexed solid
	# surface alongside its debug lines. Copy only the solid triangles into
	# our normal render resource; no physics node or debug material is used.
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
		# The native hull approximates nearly coplanar source points. Expand
		# uniformly by the measured supporting-plane deficit to limit clipping
		# of leaf tips. Rebuilt float normals retain a small numerical tolerance.
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
	if builder.vertices.is_empty():return _merge(parts)

	return {"mesh":builder.mesh(),"pose":Transform3D.IDENTITY}

static func _leaf_tri(builder,a:Vector3,b:Vector3,c:Vector3,color:Color,h_ref:float=.26)->void:
	var n:Vector3=-(b-a).cross(c-a)
	if n.length_squared()<=.0000001:return
	var biased_n:Vector3=(n.normalized()+Vector3(0.0,1.65,0.0)).normalized()
	for v:Vector3 in [a,b,c]:
		builder.vertices.append(v)
		builder.normals.append(biased_n)
		builder.colors.append(color)
		builder.uv.append(Vector2(clampf(v.y/maxf(h_ref,.05),0.0,1.0),.66))

static func _sword_rosette_models(blade_count:int,rad:float,h_max:float,seed_val:float)->Array:
	# Graceful arching celadon-sage ribbon-grass & fern spray (柔弧兰草蕨丛): luminous sRGB sage tones matching grass_blades!
	var builder=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	var total_blades:int=maxi(blade_count+4,11)
	var c_base:=Color(.31,.41,.26)
	var c_mid:=Color(.45,.55,.36)
	var c_tip:=Color(.62,.70,.49)
	for b_idx in total_blades:
		var ring_t:=0.0 if b_idx<4 else (0.5 if b_idx<8 else 1.0)
		var base_ang:=TAU*float(b_idx)/float(total_blades)+.28*sin(float(b_idx)*2.7+seed_val)
		var dir2:=Vector2(cos(base_ang),sin(base_ang))
		var dir3:=Vector3(dir2.x,0.0,dir2.y)
		var side3:=Vector3(-dir2.y,0.0,dir2.x)
		var reach:=rad*lerpf(.44,.96,ring_t)*(.88+.16*sin(float(b_idx)*3.1+seed_val))
		var bh:=h_max*lerpf(.98,.64,ring_t)*(.90+.14*cos(float(b_idx)*2.3+seed_val))
		var bw:=rad*.112*(1.0+.10*sin(float(b_idx)*1.9))
		var p0_c:=dir3*(rad*.04)+Vector3(0.0,0.0,0.0)
		var p0_l:=p0_c-side3*(bw*.78)
		var p0_r:=p0_c+side3*(bw*.78)
		var p1_c:=dir3*(reach*.48)+Vector3(0.0,bh*.62,0.0)
		var p1_l:=p1_c-side3*bw-Vector3(0.0,bh*.05,0.0)
		var p1_r:=p1_c+side3*bw-Vector3(0.0,bh*.05,0.0)
		var p2_c:=dir3*(reach*.84)+Vector3(0.0,bh*.92,0.0)
		var p2_l:=p2_c-side3*(bw*.60)-Vector3(0.0,bh*.04,0.0)
		var p2_r:=p2_c+side3*(bw*.60)-Vector3(0.0,bh*.04,0.0)
		var tip:=dir3*reach+Vector3(0.0,bh*(.82 if ring_t>.6 else 1.02),0.0)
		var shade:=.95+.07*sin(float(b_idx)*2.9+seed_val)
		var col0:=c_base*shade
		var col1:=c_mid*shade
		var col2:=c_tip*shade
		_leaf_tri(builder,p0_l,p0_c,p1_c,col0,h_max)
		_leaf_tri(builder,p0_l,p1_c,p1_l,col0,h_max)
		_leaf_tri(builder,p0_c,p0_r,p1_r,col0*.95,h_max)
		_leaf_tri(builder,p0_c,p1_r,p1_c,col0*.95,h_max)
		_leaf_tri(builder,p1_l,p1_c,p2_c,col1,h_max)
		_leaf_tri(builder,p1_l,p2_c,p2_l,col1,h_max)
		_leaf_tri(builder,p1_c,p1_r,p2_r,col1*.96,h_max)
		_leaf_tri(builder,p1_c,p2_r,p2_c,col1*.96,h_max)
		_leaf_tri(builder,p2_l,p2_c,tip,col2,h_max)
		_leaf_tri(builder,p2_c,p2_r,tip,col2*.97,h_max)
		_leaf_tri(builder,p0_r,p0_l,p1_l,col0*.90,h_max)
		_leaf_tri(builder,p0_r,p1_l,p1_r,col0*.90,h_max)
		_leaf_tri(builder,p1_r,p1_l,p2_l,col1*.92,h_max)
		_leaf_tri(builder,p1_r,p2_l,p2_r,col1*.92,h_max)
		_leaf_tri(builder,p2_r,p2_l,tip,col2*.94,h_max)
	var mesh:ArrayMesh=builder.mesh()
	mesh.surface_set_material(0,_vertex_color_material())
	return [{"mesh":mesh,"pose":Transform3D.IDENTITY,"tint":Color.WHITE}]

static func _flower_models()->Array:
	# Poetic Song-painting wild mountain-orchid & misty celadon/ivory blossom sprays (山野素兰与青黛芳穗, Tiny Glade / Regreening):
	# Readable 3.6–4.8cm painterly cup-blossoms in muted silk-ivory & pale misty periwinkle, swaying gently on arching stems!
	var builder=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	var h_ref:=.28
	for lf in 9:
		var a:=TAU*float(lf)/9.0+.35
		var d:=Vector3(cos(a),0.0,sin(a))
		var s:=Vector3(-sin(a),0.0,cos(a))
		var reach:=.16+.04*sin(float(lf)*2.3)
		var h_tip:=.12+.05*cos(float(lf)*1.7)
		var p0:=d*.016+Vector3(0.0,.006,0.0)
		var p1:=d*(reach*.54)-s*.020+Vector3(0.0,h_tip*.74,0.0)
		var p2:=d*(reach*.54)+s*.020+Vector3(0.0,h_tip*.74,0.0)
		var tip:=d*reach+Vector3(0.0,h_tip,0.0)
		var lc:=Color(.36,.47,.31)*(.94+.08*sin(float(lf)*2.1))
		_leaf_tri(builder,p0,p1,tip,lc,h_ref)
		_leaf_tri(builder,p0,tip,p2,lc*.95,h_ref)
	var stems:Array=[
		[Vector3(.01,.255,.01),Color(.95,.92,.82),.036],
		[Vector3(-.085,.220,.065),Color(.77,.83,.92),.033],
		[Vector3(.092,.208,-.058),Color(.94,.90,.79),.032],
		[Vector3(-.048,.185,-.088),Color(.80,.85,.93),.030],
		[Vector3(.062,.172,.082),Color(.93,.89,.80),.028],
		[Vector3(-.105,.156,-.018),Color(.90,.87,.78),.026],
	]
	for st_i in stems.size():
		var head:Vector3=stems[st_i][0]
		var b_col:Color=stems[st_i][1]
		var r_main:float=float(stems[st_i][2])
		var st_base:=Vector3(head.x*.22,0.0,head.z*.22)
		var st_mid:=st_base.lerp(head,.55)+Vector3(0.0,.028,0.0)
		_leaf_tri(builder,st_base-Vector3(.007,0,0),st_base+Vector3(.007,0,0),st_mid,Color(.34,.45,.29),h_ref)
		_leaf_tri(builder,st_mid-Vector3(.005,0,0),st_mid+Vector3(.005,0,0),head,Color(.42,.53,.35),h_ref)
		# Main 5-petal painterly cup-blossom + 1 smaller upper/side companion bud per stem:
		for b_i in 2:
			var bc:=head if b_i==0 else head+Vector3(sin(float(st_i)*2.3)*.032,-.030,cos(float(st_i)*2.3)*.032)
			var rb:=r_main if b_i==0 else r_main*.62
			var cup_h:=rb*.52
			var core_c:=Color(.93,.84,.58) if b_i==0 else b_col*.95
			for s_i in 5:
				var sa:=TAU*float(s_i)/5.0+float(st_i)*.45+float(b_i)*.6
				var sb:=TAU*float(s_i+1)/5.0+float(st_i)*.45+float(b_i)*.6
				var sm:=(sa+sb)*.5
				var p_l:=bc+Vector3(cos(sa)*rb*.78,cup_h*.35,sin(sa)*rb*.78)
				var p_r:=bc+Vector3(cos(sb)*rb*.78,cup_h*.35,sin(sb)*rb*.78)
				var p_tip:=bc+Vector3(cos(sm)*rb*1.08,cup_h,sin(sm)*rb*1.08)
				var p_col:=b_col*(.97+.04*float(s_i%2))
				_leaf_tri(builder,bc,p_l,p_tip,p_col,h_ref)
				_leaf_tri(builder,bc,p_tip,p_r,p_col*.97,h_ref)
			if b_i==0:
				_leaf_tri(builder,bc+Vector3(-.009,.009,0),bc+Vector3(.009,.009,0),bc+Vector3(0,.018,.009),core_c,h_ref)
	var mesh:ArrayMesh=builder.mesh()
	mesh.surface_set_material(0,_vertex_color_material())
	return [{"mesh":mesh,"pose":Transform3D.IDENTITY,"tint":Color.WHITE}]

func _grass_clump_models()->Array:
	return _sword_rosette_models(9,.34,.24,1.7)

## Angular procedural shards (procedural_shard.gd) replace the rounded kit.
const SHARD_CLIFFS:=true
## Tripo-generated cliff kit (tools/art/process_tripo_asset.py): seed -> [file, cut fraction].
const CLIFF_KIT:={11:["res://assets/nature/cliff_kit/cliff_shoulder.glb",.95],23:["res://assets/nature/cliff_kit/underside_cone.glb",.92],37:["res://assets/nature/cliff_kit/cliff_shoulder.glb",.88],41:["res://assets/nature/cliff_kit/underside_cone.glb",.97],53:["res://assets/nature/cliff_kit/cliff_shoulder.glb",.95],67:["res://assets/nature/cliff_kit/cliff_shoulder.glb",.90]}
func _rock_body_models(seed_value:int,root:bool=false)->Array:
	# Kit crowns: a sculpted closed source clipped under the shared turf cap
	# (source_stone_crown.gd). Falls back to the planar procedural blocks.
	var built:Dictionary={}
	if SHARD_CLIFFS:
		built=preload("res://scripts/terrain_editor/procedural_shard.gd").build(seed_value,root)
	elif CLIFF_KIT.has(seed_value):
		var source:=_vertex_colored_glb(CLIFF_KIT[seed_value][0])
		if not source.is_empty():
			built=preload("res://scripts/terrain_editor/source_stone_crown.gd").build(source.mesh,1.0,float(CLIFF_KIT[seed_value][1]),AABB(),true)
			# Free-standing ledges show their own bench top (mossy in the shader).
			if root:built.render_mesh=built.mesh
	if built.is_empty():built=preload("res://scripts/terrain_editor/procedural_stone.gd").build(seed_value,root)
	built.integrated_foot=false
	var mesh:ArrayMesh=built.mesh
	var material:=ShaderMaterial.new()
	material.shader=load("res://shaders/terrain_editor/cliff_column.gdshader")
	preload("res://scripts/terrain_editor/material_detail.gd").bind(material)
	material.set_shader_parameter("crown_cover",0.0 if root else 1.0)
	mesh.surface_set_material(0,material)
	built.render_mesh.surface_set_material(0,material)
	var render_faces:PackedVector3Array=built.render_mesh.get_faces()
	return [{"mesh":mesh,"render_mesh":built.render_mesh,"faces":render_faces,"pose":Transform3D.IDENTITY,"body_height":built.height,"geometry_height":built.get("geometry_height",built.height),"integrated_foot":false,"crown_z":built.crown_z,"span_x":built.span_x,"span_z":built.span_z,"cap_polygon":built.get("cap_polygon",PackedVector2Array())}]


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
	if id.begins_with("res://"):path=id
	if id.begins_with("q:"):path="res://assets/nature/quaternius/"+id.trim_prefix("q:")+".gltf"
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
			elif kind in ["surface_rock","cliff_rock","shore_rock","shore_boulder","shore_pebble","path","rim_outcrop","rim_shelf"]:tint=Color("aaa89b")
			elif kind=="tree_leaf":tint=Color("697547")
			elif kind=="bush":tint=Color("73844e")
			elif kind=="vine":tint=Color("68785c")
			elif kind=="grass" or kind=="reeds":tint=Color("939b72")
			elif kind=="lily":tint=Color("a8ad55")
			elif kind=="flower":tint=Color("e2dcc1") if name_value.to_lower().contains("yellow") else Color("788665")
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
				var shade:=.92+.08*sin((a.x+b.x+c.x)*12.13+(a.y+b.y+c.y)*8.17+(a.z+b.z+c.z)*4.7)
				if kind in ["tree_wood","fence"]:
					shade=clampf(.92+.07*sin((a.x+b.x+c.x)*15.1+(a.y+b.y+c.y)*9.3),.84,1.04)
				if kind in ["shore_rock","shore_boulder","shore_pebble"]:shade=.94+.06*sin((a.x+b.x+c.x)*9.13+(a.y+b.y+c.y)*5.3+(a.z+b.z+c.z)*7.7)
				if kind in ["tree_leaf","bush","vine"]:shade=.94+.08*sin((a.x+b.x+c.x)*12.13+(a.y+b.y+c.y)*8.17+(a.z+b.z+c.z)*4.7)
				var color:=Color(tint.r*shade,tint.g*shade,tint.b*shade,1)
				if kind in ["tree_leaf","bush","vine"]:
					var box:AABB=leaf_box
					var ab:=(a+b)*.5
					var bc:=(b+c)*.5
					var ca:=(c+a)*.5
					var faces:=[[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]]
					for face in faces:
						var blend:=.62 if kind=="tree_leaf" else .68
						var v0:Vector3;var v1:Vector3;var v2:Vector3
						if kind=="vine":
							v0=_vine_leaf(face[0],box);v1=_vine_leaf(face[1],box);v2=_vine_leaf(face[2],box)
						else:
							var irregularity:=.15 if kind=="tree_leaf" else .075
							v0=_round_leaf(face[0],box,blend,irregularity)
							v1=_round_leaf(face[1],box,blend,irregularity)
							v2=_round_leaf(face[2],box,blend,irregularity)
						var fc:=(v0+v1+v2)/3.0
						var sub_jit:=.045*sin(fc.x*19.3+fc.y*14.7+fc.z*17.1)
						var h_lift:=clampf((fc.y-box.position.y)/maxf(box.size.y,.001),0.0,1.0)
						var f_mod:=Color(.92,.96,.94).lerp(Color(1.06,1.06,.96),h_lift)*(1.0+sub_jit)
						builder.triangle(v0,v1,v2,Color(color.r*f_mod.r,color.g*f_mod.g,color.b*f_mod.b,1.0))
				elif kind in ["surface_rock","cliff_rock","shore_rock","shore_boulder"]:
					var box:AABB=leaf_box
					var ab:=_chisel_rock_edge(a,b,box)
					var bc:=_chisel_rock_edge(b,c,box)
					var ca:=_chisel_rock_edge(c,a,box)
					var r_faces:=[[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]]
					for rf in r_faces:
						var r0:Vector3=rf[0];var r1:Vector3=rf[1];var r2:Vector3=rf[2]
						var rc:=(r0+r1+r2)/3.0
						var r_shade:=clampf(.94+.05*sin(rc.x*17.3+rc.y*11.9+rc.z*13.7),.86,1.02)
						builder.triangle(r0,r1,r2,Color(tint.r*r_shade,tint.g*r_shade,tint.b*r_shade,1.0))
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
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array else PackedVector3Array()
		var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array else PackedVector2Array()
		var tint:Color=part.get("tint",Color.WHITE)
		var pose:Transform3D=part.pose
		var has_n:bool=normals.size()==vertices.size()
		var has_uv:bool=uvs.size()==vertices.size()
		if has_n:
			for j in vertices.size():
				var v_world:Vector3=pose*vertices[j]
				var n_world:Vector3=(pose.basis*normals[j]).normalized()
				builder.vertices.append(v_world)
				builder.normals.append(n_world)
				builder.colors.append(colors[j]*tint)
				builder.uv.append(uvs[j] if has_uv else Vector2(v_world.x+v_world.z,v_world.y))
		else:
			for i in range(0,vertices.size(),3):builder.triangle(pose*vertices[i],pose*vertices[i+1],pose*vertices[i+2],colors[i]*tint)
	var mesh:ArrayMesh=builder.mesh()
	mesh.surface_set_material(0,_vertex_color_material())
	return {"mesh":mesh,"pose":Transform3D.IDENTITY}

func _lift_branches(point:Vector3)->Vector3:
	# Lift the two low forks of the retained CC0 detailed-tree mesh into the
	# raised crown, and flare the base root collar smoothly into the turf.
	var flare:=1.0+.48*pow(clampf((.22-point.y)/.22,0.0,1.0),1.7)
	point.x*=flare
	point.z*=flare
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

func _vine_leaf(point:Vector3,box:AABB)->Vector3:
	var center:=box.position+box.size*.5
	var radius:=box.size*.5
	var leaf:=_round_leaf(point,box,.26)-center
	var along:=clampf(absf(leaf.y)/maxf(radius.y,.0001),0,1)
	leaf.x*=lerpf(1.0,.12,pow(along,1.4))
	return center+leaf

func _chisel_rock_edge(p1:Vector3,p2:Vector3,box:AABB)->Vector3:
	# Symmetric edge-midpoint displacement keeps subdivided rock meshes watertight
	# while breaking broad Kenney triangles into crisp chiseled low-poly facets.
	var mid:=(p1+p2)*.5
	var edge_len:=p1.distance_to(p2)
	if edge_len<.001:return mid
	var center:=box.position+box.size*.5
	var y_norm:=clampf((mid.y-box.position.y)/maxf(box.size.y,.001),0.0,1.0)
	var upper_mask:=smoothstep(.24,.46,y_norm)
	if upper_mask<=.001:return mid
	var dir:=(mid-center).normalized()
	var sum_p:=p1+p2
	var prod_p:=p1*p2
	var h:=sin(sum_p.x*11.3+sum_p.y*7.9+sum_p.z*13.7)*cos((prod_p.x+prod_p.z)*6.1)
	return mid+dir*(edge_len*(.038+.032*h)*upper_mask)

func _reed_models()->Array:
	# Waterside calamus & feathery autumn-ivory reed plumes (临水菖蒲与荻花穗, Europa / Song Shanshui):
	var base:Array=_sword_rosette_models(10,.26,.46,3.9)
	var arrays:Array=base[0].mesh.surface_get_arrays(0)
	var builder=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	builder.vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
	builder.normals.append_array(arrays[Mesh.ARRAY_NORMAL])
	builder.colors.append_array(arrays[Mesh.ARRAY_COLOR])
	builder.uv.append_array(arrays[Mesh.ARRAY_TEX_UV])
	var plumes:Array=[
		[Vector3(.03,.58,.02),Vector3(.06,.14,.03)],
		[Vector3(-.07,.52,-.04),Vector3(-.04,.12,-.03)],
		[Vector3(.06,.48,-.05),Vector3(.04,.11,-.04)],
	]
	for pl:Array in plumes:
		var stem_top:Vector3=pl[0]
		var plume_dir:Vector3=pl[1]
		var stem_base:=Vector3(stem_top.x*.20,0.0,stem_top.z*.20)
		var stem_mid:=stem_base.lerp(stem_top,.55)+Vector3(0.0,.03,0.0)
		_leaf_tri(builder,stem_base-Vector3(.008,0,0),stem_base+Vector3(.008,0,0),stem_mid,Color(.34,.44,.28),.68)
		_leaf_tri(builder,stem_mid-Vector3(.006,0,0),stem_mid+Vector3(.006,0,0),stem_top,Color(.48,.56,.37),.68)
		var tip:=stem_top+plume_dir
		var p_col:=Color(.89,.86,.75)
		for f_i in 4:
			var fa:=TAU*float(f_i)/4.0+.4
			var off:=Vector3(cos(fa)*.018,0.0,sin(fa)*.018)
			_leaf_tri(builder,stem_top-off*.5,stem_top+off,tip,p_col*(.96+.04*float(f_i%2)),.68)
	var mesh:ArrayMesh=builder.mesh()
	mesh.surface_set_material(0,_vertex_color_material())
	return [{"mesh":mesh,"pose":Transform3D.IDENTITY,"tint":Color.WHITE}]

func _lily_models()->Array:
	var surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	var tones:Array[Color]=[Color("67885a"),Color("769464"),Color("5d7e53"),Color("718f60"),Color("69895b")]
	for pad in 5:
		var center:=Vector3(sin(pad*2.38)*.172,0.004*float(pad%2),cos(pad*2.38)*.182)
		var radius:=.072+pad*.013
		var pad_col:Color=tones[pad%tones.size()]
		# Classic V-notched lotus pad (skip side 0 for natural radial cleft):
		for side in range(1,12):
			var a:=TAU*float(side)/12.0+pad*1.35
			var b:=TAU*float(side+1)/12.0+pad*1.35
			var r_a:=radius*(.94+.06*sin(float(side)*2.3))
			var r_b:=radius*(.94+.06*sin(float(side+1)*2.3))
			surface.triangle(center+Vector3(0.0,.009,0.0),center+Vector3(cos(a)*r_a,0.0,sin(a)*r_a),center+Vector3(cos(b)*r_b,0.0,sin(b)*r_b),pad_col*(.95+.06*cos(float(side))),true)
		if pad==1 or pad==3:
			var b_top:=center+Vector3(0.0,.052,0.0)
			for p_i in 6:
				var pa:=TAU*float(p_i)/6.0+.2
				var pb:=TAU*float(p_i+1)/6.0+.2
				var pm:=(pa+pb)*.5
				surface.triangle(center+Vector3(0.0,.010,0.0),center+Vector3(cos(pa)*.028,.020,sin(pa)*.028),center+Vector3(cos(pm)*.036,.038,sin(pm)*.036),Color("f0e8da"),true)
				surface.triangle(center+Vector3(0.0,.010,0.0),center+Vector3(cos(pm)*.036,.038,sin(pm)*.036),center+Vector3(cos(pb)*.028,.020,sin(pb)*.028),Color("ebe0d0"),true)
				surface.triangle(b_top,center+Vector3(cos(pa)*.016,.016,sin(pa)*.016),center+Vector3(cos(pb)*.016,.016,sin(pb)*.016),Color("f4dcd4"),true)
	var mesh:ArrayMesh=surface.mesh()
	return [{"mesh":mesh,"pose":Transform3D.IDENTITY}]

func _path_models()->Array:
	# Plump rounded-bevelled grey-taupe river-limestone stepping cobble (圆润厚重灰青汀步石, Ref 1):
	# Thick enough (~12cm) to read as tactile 3D river cobbles and cast crisp shadows onto the sand bed!
	var surface=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	const SIDES:=14
	var inner:=PackedVector3Array()
	var rim:=PackedVector3Array()
	var bottom:=PackedVector3Array()
	var apex:=Vector3(.004,.118,-.002)
	for i in SIDES:
		var a:=TAU*float(i)/float(SIDES)
		var r:=.31*(1.0+.055*sin(float(i)*2.0+.4)-.035*cos(float(i)*3.0+.8))
		var r_in:=r*.76
		var split_y:=.098+.004*sin(float(i)*2.0+.3)
		inner.append(Vector3(cos(a)*r_in,split_y,sin(a)*r_in*.72))
		rim.append(Vector3(cos(a)*r,.052,sin(a)*r*.72))
		bottom.append(Vector3(cos(a)*(r+.014),-.018,sin(a)*(r+.014)*.72))
	for i in SIDES:
		var j:=(i+1)%SIDES
		surface.triangle(apex,inner[i],inner[j],Color("84867e"),true)
		surface.quad(inner[j],inner[i],rim[i],rim[j],Color("6e716a"),true)
		surface.quad(rim[j],rim[i],bottom[i],bottom[j],Color("545852"))
	var smoothed:ArrayMesh=preload("res://scripts/terrain_editor/stone_normals.gd").soften(surface.mesh(),14.0,.25)
	return [{"mesh":smoothed,"pose":Transform3D.IDENTITY}]

## Painterly tree: ancient weathered dark bark/branches (ZERO solid green foliage helmet!)
## crowned by delicate, finely-stippled bonsai cloud-pad & cumulus-dome tufts (Ref 1).
func _leaf_card_tree(path:String,seed_value:int,shadow:Color,mid:Color,lit:Color,density:float)->Array:
	var source:=_vertex_colored_glb(path)
	if source.is_empty():return []
	var arrays:Array=preload("res://scripts/terrain_editor/chunk_geometry.gd").arrays_of(source.mesh,0)
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var box:AABB=(source.mesh as Mesh).get_aabb()
	var trunk=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	var cards=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	var is_pine:bool=(seed_value==2)
	var bark_root:=Color(.26,.20,.16,1.0) if is_pine else Color(.24,.21,.18,1.0)
	var bark_upper:=Color(.40,.31,.24,1.0) if is_pine else Color(.38,.34,.29,1.0)
	var fol_min:=Vector3(INF,INF,INF)
	var fol_max:=Vector3(-INF,-INF,-INF)
	for i in vertices.size():
		if uvs[i].y>.5:
			fol_min=fol_min.min(vertices[i])
			fol_max=fol_max.max(vertices[i])
	var fol_center:Vector3=(fol_min+fol_max)*.5 if fol_min.x<INF else box.get_center()
	var fol_span:Vector3=(fol_max-fol_min).max(Vector3.ONE*.25)*0.5 if fol_min.x<INF else box.size*.5
	var fol_h_span:float=maxf(fol_max.y-fol_min.y,.25)
	# Build 18–26 distinct spatial sub-bouquet centroids across the crown so foliage gathers into
	# sculptural botanical cloud-clusters separated by deep mossy crevices & airy sky gaps (Ref 1!):
	var lobe_sums:Dictionary={}
	var lobe_counts:Dictionary={}
	var full_span:Vector3=(fol_max-fol_min).max(Vector3.ONE*.25)
	for i in vertices.size():
		if uvs[i].y>.5:
			var vp:Vector3=vertices[i]
			var key:=Vector3i(
				clampi(int(floorf((vp.x-fol_min.x)/maxf(full_span.x/5.0,.08))),0,4),
				clampi(int(floorf((vp.y-fol_min.y)/maxf(fol_h_span/4.0,.08))),0,3),
				clampi(int(floorf((vp.z-fol_min.z)/maxf(full_span.z/5.0,.08))),0,4)
			)
			lobe_sums[key]=lobe_sums.get(key,Vector3.ZERO)+vp
			lobe_counts[key]=int(lobe_counts.get(key,0))+1
	var lobe_centers:Array[Vector3]=[]
	for key:Vector3i in lobe_sums:
		if int(lobe_counts[key])>=(10 if is_pine else 4):
			lobe_centers.append(lobe_sums[key]/float(lobe_counts[key]))
	if lobe_centers.is_empty():
		lobe_centers.append(fol_center)
	var nearest_bouquet:=func(pt:Vector3)->Vector3:
		var best_c:Vector3=lobe_centers[0]
		var best_d:float=INF
		for lc:Vector3 in lobe_centers:
			var d2:float=pt.distance_squared_to(lc)
			if d2<best_d:best_d=d2;best_c=lc
		return best_c
	var smooth_crown_n:=func(pt:Vector3)->Vector3:
		var macro_d:=((pt-fol_center)/fol_span.max(Vector3.ONE*.15))
		# Strong lateral 3D cushion curvature so left/away slopes of EVERY tier hold rich olive depth
		# while right/sunward crests glow with warm morning sage (eliminates flat bleached top caps!):
		var macro_v:=Vector3(macro_d.x*1.32,macro_d.y*.82+.06,macro_d.z*1.32)
		var macro_n:=macro_v.normalized() if macro_v.length_squared()>.0001 else Vector3.UP
		var sub_acc:=Vector3.ZERO
		var w_sum:=0.0
		var inv_r2:=1.0/maxf(box.size.y*box.size.y*.014,.004)
		for lc:Vector3 in lobe_centers:
			var dv:=pt-lc
			var w:=exp(-dv.length_squared()*inv_r2)
			var sn:=Vector3(dv.x*1.44,dv.y*.84+.012*box.size.y,dv.z*1.44)
			if sn.length_squared()>.00001:
				sub_acc+=sn.normalized()*w
				w_sum+=w
		var sub_n:=(sub_acc/w_sum).normalized() if w_sum>.0001 and sub_acc.length_squared()>.00001 else macro_n
		return (sub_n*.70+macro_n*.30).normalized()
	var rng:=RandomNumberGenerator.new()
	rng.seed=seed_value*7919
	for i in range(0,vertices.size(),3):
		var foliage:bool=uvs[i].y>.5 and uvs[i+1].y>.5 and uvs[i+2].y>.5
		if not foliage:
			for k in 3:
				var v:Vector3=vertices[i+k]
				var vn:Vector3=normals[i+k]
				var h_wood:=clampf((v.y-box.position.y)/maxf(box.size.y,.001),0.0,1.0)
				if not is_pine and h_wood<.28:
					var flare:=lerpf(1.08,1.0,smoothstep(0.0,.28,h_wood))
					v=Vector3(v.x*flare,v.y,v.z*flare)
				var bark_col:=bark_root.lerp(bark_upper,smoothstep(.06,.74,h_wood))
				trunk.vertices.append(v)
				trunk.normals.append(vn)
				trunk.colors.append(bark_col)
				trunk.uv.append(Vector2(h_wood,.16 if is_pine else .13))
			continue
		var a:=vertices[i];var b:=vertices[i+1];var c:=vertices[i+2]
		var tri_n:=(normals[i]+normals[i+1]+normals[i+2]).normalized()
		if (is_pine and tri_n.y<-.18) or (not is_pine and tri_n.y<-.26):
			continue
		var area:=(b-a).cross(c-a).length()*.5/(box.size.y*box.size.y)
		var expected:=area*density
		var count:=int(expected)
		if rng.randf()<expected-count:count+=1
		for n_i in count:
			var u:=rng.randf();var w:=rng.randf()
			if u+w>1.0:u=1.0-u;w=1.0-w
			var p:=a+(b-a)*u+(c-a)*w
			var n:=tri_n
			var h_raw:=clampf((p.y-fol_min.y)/fol_h_span,0.0,1.0)
			var is_core_tuft:bool=(rng.randf()<.30)
			var size:=box.size.y*(rng.randf_range(.092,.128) if is_pine else rng.randf_range(.080,.114))
			if is_core_tuft:size*=1.20
			var offset_d:=(-box.size.y*.016) if is_core_tuft else (box.size.y*rng.randf_range(-.002,.018))
			var centre:=p+n*offset_d
			var bq_c:Vector3=nearest_bouquet.call(centre)
			var bq_dist:float=centre.distance_to(bq_c)
			var pull:float=(.42 if bq_dist>box.size.y*.13 else .14) if is_pine else .18
			centre=centre.lerp(bq_c,pull)
			if is_pine:
				var strata_n:=3.0
				var h_tier:=clampf(roundf(h_raw*strata_n)/strata_n,0.0,1.0)
				centre.y=lerpf(centre.y,fol_min.y+h_tier*fol_h_span,.28)
			var center_n:Vector3=smooth_crown_n.call(centre)
			var t2:Vector3
			var b2:Vector3
			var size_x:=size*1.08
			var size_y:=size*.96
			if is_pine:
				var tilt_p:=Vector3(rng.randf_range(-.72,.72),rng.randf_range(-.04,.82),rng.randf_range(-.72,.72)).normalized()
				var face_p:=(Vector3(center_n.x*.68,center_n.y*.58+.32,center_n.z*.68)+tilt_p*.20).normalized()
				var tp:=face_p.cross(Vector3.UP if absf(face_p.y)<.94 else Vector3.RIGHT).normalized()
				var btp:=face_p.cross(tp).normalized()
				if btp.y<0.0:btp=-btp;tp=-tp
				var roll_p:=rng.randf_range(-.24,.24)
				t2=(tp*cos(roll_p)+btp*sin(roll_p)).normalized()
				b2=(btp*cos(roll_p)-tp*sin(roll_p)).normalized()
				size_x=size*1.24
				size_y=size*.84
			else:
				var tilt:=Vector3(rng.randf_range(-.88,.88),rng.randf_range(-.12,.92),rng.randf_range(-.88,.88)).normalized()
				var face:=(Vector3(center_n.x*.76,center_n.y*.68+.16,center_n.z*.76)+tilt*.22).normalized()
				var t:=face.cross(Vector3.UP if absf(face.y)<.95 else Vector3.RIGHT).normalized()
				var bt:=face.cross(t).normalized()
				if bt.y<0.0:bt=-bt;t=-t
				var roll:=rng.randf_range(-.34,.34)
				t2=(t*cos(roll)+bt*sin(roll)).normalized()
				b2=(bt*cos(roll)-t*sin(roll)).normalized()
				size_x=size*1.06
				size_y=size*.96
			var cell_x:=rng.randi()%2
			var cell_y:=1 if is_pine else 0
			var uv0:=Vector2(float(cell_x)*.5,float(cell_y)*.5)
			var shade_var:=rng.randf_range(.95,1.05)
			var cup_arch:Vector3=center_n*(size*.20)
			var fan_pts:Array[Vector3]=[
				centre+cup_arch,
				centre-t2*size_x-b2*size_y-cup_arch*.35,
				centre+t2*size_x-b2*size_y-cup_arch*.35,
				centre+t2*size_x+b2*size_y-cup_arch*.35,
				centre-t2*size_x+b2*size_y-cup_arch*.35,
			]
			var fan_uvs:Array[Vector2]=[
				uv0+Vector2(.25,.25),
				uv0+Vector2(0.0,.5),
				uv0+Vector2(.5,.5),
				uv0+Vector2(.5,0.0),
				uv0+Vector2(0.0,0.0),
			]
			var fan_nrms:Array[Vector3]=[]
			var fan_cols:Array[Color]=[]
			var bq_r:=maxf(box.size.y*(.135 if is_pine else .105),.12)
			for fv:Vector3 in fan_pts:
				fan_nrms.append(smooth_crown_n.call(fv))
				var fh:=clampf((fv.y-fol_min.y)/fol_h_span,0.0,1.0)
				var horiz_rel:=Vector2((fv.x-fol_center.x)/maxf(fol_span.x,.15),(fv.z-fol_center.z)/maxf(fol_span.z,.15)).length()
				var f_rel:=horiz_rel*.72 if is_pine else ((fv-fol_center)/fol_span).length()
				var bq_local_y:=clampf((fv.y-bq_c.y)/bq_r,-1.0,1.0)
				var bq_shell:=clampf(fv.distance_to(bq_c)/bq_r,0.0,1.15)
				var base_ao:=(.24 if is_core_tuft else .34) if is_pine else (.30 if is_core_tuft else .40)
				var f_ao:=clampf(base_ao+(.26 if is_pine else .32)*f_rel+.20*bq_local_y+.18*bq_shell,.24,1.0)
				fan_cols.append(Color(shade_var,fh,f_ao,1.0))
			# Pack card tangent direction into UV2 + normal reconstruction in shader via dFdx/UV or custom tangent:
			for tri_idx:Array in [[0,1,2],[0,2,3],[0,3,4],[0,4,1]]:
				for vi:int in tri_idx:
					cards.vertices.append(fan_pts[vi])
					cards.normals.append(fan_nrms[vi])
					cards.colors.append(fan_cols[vi])
					cards.uv.append(fan_uvs[vi])
	var trunk_mesh:ArrayMesh=trunk.mesh()
	var trunk_material:=_vertex_color_material()
	trunk_material.set_shader_parameter("sway_strength",.045)
	trunk_mesh.surface_set_material(0,trunk_material)
	var card_mesh:ArrayMesh=cards.mesh()
	var card_material:=ShaderMaterial.new()
	card_material.shader=load("res://shaders/terrain_editor/foliage_cards.gdshader")
	card_material.set_shader_parameter("leaf_atlas",_get_botanical_atlas())
	card_material.set_shader_parameter("leaf_shadow",shadow)
	card_material.set_shader_parameter("leaf_mid",mid)
	card_material.set_shader_parameter("leaf_lit",lit)
	card_mesh.surface_set_material(0,card_material)
	return [{"mesh":trunk_mesh,"pose":Transform3D.IDENTITY,"tint":Color.WHITE},{"mesh":card_mesh,"pose":Transform3D.IDENTITY,"tint":Color.WHITE}]

## Loads a processed GLB with baked vertex colours (alpha 1 = foliage). UV.y
## flags foliage for the soft cluster lighting in decor_vertex_color.gdshader.
func _vertex_colored_glb(path:String)->Dictionary:
	if not FileAccess.file_exists(path):return {}
	var document:=GLTFDocument.new()
	var state:=GLTFState.new()
	if document.append_from_file(path,state)!=OK:return {}
	var scene:=document.generate_scene(state)
	var found:Array=[]
	var stack:Array=[scene]
	while not stack.is_empty():
		var node:Node=stack.pop_back()
		if node is MeshInstance3D:found.append(node)
		stack.append_array(node.get_children())
	if found.is_empty():
		scene.free()
		return {}
	var source:MeshInstance3D=found[0]
	var arrays:Array=source.mesh.surface_get_arrays(0)
	scene.free()
	var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
	var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] is PackedColorArray else PackedColorArray()
	var box:=AABB(vertices[0],Vector3.ZERO)
	for v:Vector3 in vertices:box=box.expand(v)
	var builder=preload("res://scripts/terrain_editor/chunk_geometry.gd").Surface.new()
	var count:=indices.size() if not indices.is_empty() else vertices.size()
	for k in count:
		var i:int=indices[k] if not indices.is_empty() else k
		var c:Color=colors[i] if colors.size()==vertices.size() else Color(.5,.5,.5,1)
		builder.vertices.append(vertices[i])
		builder.normals.append(normals[i])
		builder.colors.append(Color(c.r,c.g,c.b,1.0))
		builder.uv.append(Vector2(clampf((vertices[i].y-box.position.y)/maxf(box.size.y,.001),0.0,1.0),1.0 if c.a>.5 else 0.0))
	var mesh:ArrayMesh=builder.mesh()
	# Processed colours are authored as display (sRGB) values.
	var material:=_vertex_color_material()
	if path in [HUAI_TREE,PINE_TREE]:material.set_shader_parameter("sway_strength",.07)
	mesh.surface_set_material(0,material)
	return {"mesh":mesh,"pose":Transform3D.IDENTITY,"tint":Color.WHITE}

static func _vertex_color_material()->ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/terrain_editor/decor_vertex_color.gdshader")
	return material

func _path_material()->ShaderMaterial:
	var material:=ShaderMaterial.new()
	material.shader=load("res://shaders/terrain_editor/cliff_rock.gdshader")
	material.set_shader_parameter("prop_kind",2.0)
	preload("res://scripts/terrain_editor/material_detail.gd").bind(material)
	return material
