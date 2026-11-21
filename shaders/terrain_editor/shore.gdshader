shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D stone_mineral_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
#include "wet_bank.gdshaderinc"
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=terrain_morph_offset(world_position);}
void fragment(){
 if(!terrain_transition_visible(FRAGCOORD.xy))discard;
	vec2 p=world_position.xz;
	vec2 slope;
	vec3 grass=ground_cover(world_position,1.0-smoothstep(.35,1.0,length(fwidth(p))*9.0),slope);
	float wet=(1.0-smoothstep(.02,.11,world_position.y-UV.x))*UV.y;
	vec3 earth=wet_bank_earth(world_position);
	vec3 damp=wet_bank_material(world_position)*mix(vec3(1.0),vec3(.92,.95,.91),wet);
	float cover=smoothstep(.12,.94,COLOR.a*(.72+.30*gc_noise(p*2.6)));
	float above=smoothstep(-.01,.03,world_position.y-UV.x);
	float remnants=smoothstep(.48,.80,gc_noise(p*3.8)*.70+gc_noise(p*8.4+vec2(9.1,3.2))*.30)*(.35+.65*gc_noise(p*.75));
	// Gentle shallow sand cove on upper-left pond end; crisp grassy/stony banks elsewhere (Ref 1):
	float west_beach=smoothstep(-4.6,-7.6,p.x)*step(2.2,world_position.y);
	float bank_weight=mix(.38,.82,west_beach);
	float exposed=clamp(cover*bank_weight+wet*.78,0.0,1.0)*(1.0-remnants*mix(.62,.24,west_beach)*above);
	vec3 warm_cove_sand=mix(earth,vec3(.32,.30,.19),.55);
	ALBEDO=mix(grass,mix(warm_cove_sand,damp,wet*.65),exposed);
	vec3 n=normalize(vec3(-slope.x*.12,1.0,-slope.y*.12));
	NORMAL=normalize(mix(NORMAL,(VIEW_MATRIX*vec4(n,0.0)).xyz,.35));
	ROUGHNESS=mix(.94,.68,wet);
	SPECULAR=mix(.02,.10,wet);
}
void light(){
	float ndl=dot(NORMAL,LIGHT);
	float wrap=smoothstep(-.22,.64,ndl);
	float direct_t=clamp(smoothstep(-.08,.55,ndl)*ATTENUATION,0.0,1.0);
	vec3 temp_tint=mix(vec3(.78,.90,1.02),vec3(1.06,1.01,.93),direct_t);
	float lit=wrap*mix(.05,1.0,ATTENUATION)*.78+smoothstep(.14,.78,ndl)*ATTENUATION*.10;
	DIFFUSE_LIGHT+=(temp_tint*lit)*LIGHT_COLOR/PI;
}
