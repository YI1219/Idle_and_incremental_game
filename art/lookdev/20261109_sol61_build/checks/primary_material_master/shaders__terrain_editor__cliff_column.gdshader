shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
// Multi-Boulder Stacked & Staggered Chiseled Shanshui Cliff Shader (纵横交错叠石 · 干脆切削块面 · 零掠射阴影锯齿, Refs 01–04).
uniform float crown_cover = 1.0;
varying vec3 local_position;
varying vec3 column_origin;
varying vec3 world_position;
varying vec3 world_facet_n;
varying float v_world_ny;

void vertex(){
	local_position=VERTEX;
	column_origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_facet_n=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	v_world_ny=world_facet_n.y;
	if(terrain_morph_progress<1.0){
		vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
		VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(origin),0.0,0.0)).xyz;
	}
}

void fragment(){
 vec3 base_normal=normalize(world_facet_n);
 vec3 shade_normal=stone_mineral_normal(world_position,base_normal);
 NORMAL=normalize((VIEW_MATRIX*vec4(shade_normal,0.0)).xyz);
 vec3 pigment=stone_surface(world_position,base_normal);
 pigment*=mix(vec3(1.0),COLOR.rgb/.708,.28);
 pigment=stone_root_contact(pigment,world_position,base_normal,column_origin.y,crown_cover);
 ALBEDO=stone_mist_dissolve(pigment,world_position,base_normal);
 ROUGHNESS=.92;
 SPECULAR=0.0;
 AO=mix(.94,1.0,smoothstep(-.50,.30,base_normal.y));
 AO_LIGHT_AFFECT=.35;
}

void light(){
 stone_painted_light(NORMAL,VIEW,LIGHT,LIGHT_COLOR,ATTENUATION,v_world_ny,DIFFUSE_LIGHT);
}
