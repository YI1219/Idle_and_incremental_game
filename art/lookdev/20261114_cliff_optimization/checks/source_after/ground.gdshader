shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "live_water.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
#include "wet_bank.gdshaderinc"
render_mode cull_disabled;
uniform bool show_grid = false;
uniform vec2 grid_center=vec2(0.0);
uniform float grid_radius=0.0;
uniform float cover_relief = 0.0;
uniform sampler2D rim_bald_field : filter_linear, repeat_disable, hint_default_black;
uniform vec2 rim_bald_origin = vec2(-64.0);
uniform vec2 rim_bald_extent = vec2(128.0);
varying vec3 world_position;
void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float morph=terrain_morph_offset(world_position);
	VERTEX.y+=morph;
	world_position.y+=morph;
}
void fragment(){
 if(!terrain_transition_visible(FRAGCOORD.xy))discard;
	vec2 p=world_position.xz;
	float footprint=length(fwidth(p))*9.0;
	float detail=1.0-smoothstep(.35,1.0,footprint);
	vec2 slope;
	vec3 color=ground_cover(world_position,detail,slope);
	float patch=gc_noise(p*1.45+vec2(11.0,3.0));
	float exposed=(1.0-COLOR.a)*smoothstep(.82,.94,patch)*(1.0-smoothstep(.04,.20,UV.x));
	vec3 warm_moss_earth=mix(vec3(.135,.205,.095),vec3(.225,.265,.140),gc_noise(p*1.8));
	color=mix(color,warm_moss_earth,exposed*.28);
	if(show_grid && distance(p,grid_center)<grid_radius){vec2 grid=abs(fract(p)-0.5);float edge=step(0.486,max(grid.x,grid.y));color=mix(color,vec3(0.91,0.95,0.66),edge*0.35);}
	float lip_warm=clamp((0.985-COLOR.g)*3.2,0.0,1.0);
	vec3 lip_tint=mix(vec3(1.0),vec3(1.08,1.07,0.88),lip_warm*0.44);
	vec3 safe_vcol=max(COLOR.rgb,vec3(.88,.93,.82));
	vec3 lawn=color*mix(vec3(1.0),safe_vcol,.30)*lip_tint;
	// Soil appears only at the very edge, in unequal rooted patches.
	float root_patch=gc_noise(p*1.15+vec2(3.2,8.7))*.65+gc_noise(p*3.4)*.35;
	float lip_soil=1.0-smoothstep(.726+.030*root_patch,.770+.042*root_patch,COLOR.g);
	// A warm, broken root layer follows the rolled edge. Its pigment stays
	// distinct from both grass and stone without becoming a dark rim belt.
	vec3 rooted_sod=mix(color*vec3(.92,.86,.65),stone_mid_color*vec3(.96,.88,.72),.50);
	float root_exposure=.28+.56*smoothstep(.30,.72,root_patch);
	vec3 surface_col=mix(lawn,rooted_sod,lip_soil*root_exposure);
	// Reverse cliff-into-turf interaction ("石壁反向露岩与稀疏秃草坪"):
	// Select cliff headlands and rim stretches let bare cliff stone and thin dry turf bite inward.
	vec2 bald_uv=(p-rim_bald_origin)/max(rim_bald_extent,vec2(1.0));
	float bald_inside=step(0.0,bald_uv.x)*step(0.0,bald_uv.y)*step(bald_uv.x,1.0)*step(bald_uv.y,1.0);
	vec2 bald_sample=texture(rim_bald_field,clamp(bald_uv,vec2(0.0),vec2(1.0))).rg*bald_inside;
	float rim_prox=bald_sample.x;
	float stone_bite=0.0;
	float sparse_turf=0.0;
	if(rim_prox>0.01){
		mat2 br1=mat2(vec2(.80,.60),vec2(-.60,.80));
		mat2 br2=mat2(vec2(-.44,.90),vec2(-.90,-.44));
		float b_macro=gc_noise(br1*p*.145+vec2(5.7,2.3))*.66+gc_noise(br2*p*.31+vec2(11.4,7.9))*.34;
		float b_det=gc_noise(br1*p*.68+vec2(2.1,9.4))*.60+gc_noise(br2*p*1.55+vec2(8.3,3.6))*.40;
		float b_wave=clamp(smoothstep(.60,.79,b_macro+(b_det-.5)*.18),0.0,1.0);
		float patch_drive=clamp(b_wave+bald_sample.y*.16*smoothstep(.05,.35,b_wave),0.0,1.0);
		float rag=gc_noise(p*1.35+vec2(4.2,7.8))*.62+gc_noise(p*3.1-vec2(2.6,5.1))*.38;
		float reach=rim_prox*(.60+.62*patch_drive)+(rag-.5)*.24;
		stone_bite=smoothstep(.66,.84,reach)*smoothstep(.26,.58,patch_drive)*COLOR.a;
		sparse_turf=smoothstep(.30,.66,reach)*smoothstep(.16,.46,patch_drive)*COLOR.a;
		// Keep ground under short-cropped 3D tufts (sparse_turf < 0.48) in warm dry olive-moss;
		// transition to rooted ochre sod and weathered matte cliff stone aligned with sunlit wall value.
		float dry_moss_band=smoothstep(.05,.48,sparse_turf);
		float bare_sod_band=smoothstep(.46,.76,sparse_turf);
		float exposed_core=smoothstep(.24,.56,stone_bite);
		vec3 raw_stone=stone_surface(world_position,vec3(0.0,1.0,0.0))*vec3(.72,.69,.61);
		vec3 cliff_top_stone=mix(rooted_sod*vec3(.96,.92,.84),raw_stone,.74);
		float tuft_islands=smoothstep(.34,.72,gc_noise(br2*p*2.15+vec2(6.4,1.9)));
		vec3 dry_olive_turf=lawn*mix(vec3(.95,.93,.78),vec3(1.01,.95,.76),tuft_islands);
		vec3 bare_stony_sod=mix(rooted_sod*vec3(.98,.94,.85),cliff_top_stone,.46);
		surface_col=mix(surface_col,dry_olive_turf,dry_moss_band*.78);
		surface_col=mix(surface_col,bare_stony_sod,bare_sod_band*.84);
		surface_col=mix(surface_col,cliff_top_stone,exposed_core*.88);
	}
	ALBEDO=surface_col;
	float submerged=1.0-live_grass_coverage(world_position);
	if(submerged>0.0)ALBEDO=mix(ALBEDO,wet_bank_material(world_position),submerged);
	vec3 base_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
	if(base_normal.y<0.0)base_normal=-base_normal;
	// Smooth 0.6m–2.2m plush moss-meadow cushion swells on turf:
	float path_clear=smoothstep(.42,.82,gc_path_dist(p));
	float cushion_mask=smoothstep(.84,.98,base_normal.y)*COLOR.a*path_clear*gc_standing(p)*clamp(1.0-stone_bite*.92-sparse_turf*.45,0.0,1.0);
	vec2 pillow_g=gc_pillow_grad(p)*(.14*cushion_mask*(1.0-submerged));
	slope*=1.0-submerged;
	vec3 normal_world=normalize(base_normal+vec3(-pillow_g.x-slope.x*cover_relief*detail,0.0,-pillow_g.y-slope.y*cover_relief*detail));
	NORMAL=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	ROUGHNESS=mix(.94,.90,submerged);
	SPECULAR=mix(.02,.06,submerged);
}
void light(){
	meadow_diffuse(NORMAL,LIGHT,LIGHT_COLOR,ATTENUATION,DIFFUSE_LIGHT);
}
