shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
render_mode cull_disabled;
uniform bool show_grid = false;
uniform float cover_relief = 0.0;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=terrain_morph_offset(world_position);}
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
	if(show_grid){vec2 grid=abs(fract(p)-0.5);float edge=step(0.486,max(grid.x,grid.y));color=mix(color,vec3(0.91,0.95,0.66),edge*0.35);}
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
	ALBEDO=mix(lawn,rooted_sod,lip_soil*root_exposure);
	vec3 base_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
	if(base_normal.y<0.0)base_normal=-base_normal;
	// Smooth 0.6m–2.2m plush moss-meadow cushion swells on turf:
	float path_clear=smoothstep(.42,.82,gc_path_dist(p));
	float cushion_mask=smoothstep(.84,.98,base_normal.y)*COLOR.a*path_clear*gc_standing(p);
	vec2 pillow_g=gc_pillow_grad(p)*(.14*cushion_mask);
	vec3 normal_world=normalize(base_normal+vec3(-pillow_g.x-slope.x*cover_relief*detail,0.0,-pillow_g.y-slope.y*cover_relief*detail));
	NORMAL=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	ROUGHNESS=0.94;
	SPECULAR=.02;
}
void light(){
	meadow_diffuse(NORMAL,LIGHT,LIGHT_COLOR,ATTENUATION,DIFFUSE_LIGHT);
}
