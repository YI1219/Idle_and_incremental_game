shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
render_mode cull_disabled;
varying vec3 world_position;
varying float v_world_ny;
void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
	v_world_ny=normalize(MODEL_NORMAL_MATRIX*NORMAL).y;
	VERTEX.y+=terrain_morph_offset(world_position);
}
void fragment(){
 if(!terrain_transition_visible(FRAGCOORD.xy))discard;
	vec3 material_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
	vec3 detail_n=stone_normal(world_position*1.65,material_normal);
	vec3 shade_n=normalize(mix(material_normal,detail_n,.09));
	vec3 stone=stone_surface(world_position,shade_n)*mix(vec3(1.0),COLOR.rgb,.16);
	ALBEDO=stone_mist_dissolve(stone,world_position,material_normal);
	ROUGHNESS=.952;SPECULAR=.016;
	AO=.92*mix(1.0,.76,smoothstep(.12,-.52,dot(shade_n,normalize(vec3(.88,.43,.11)))));
	NORMAL=normalize((VIEW_MATRIX*vec4(material_normal,0.0)).xyz);
}
void light(){
	stone_crisp_facet_light(NORMAL,LIGHT,LIGHT_COLOR,1.0,LIGHT_IS_DIRECTIONAL,v_world_ny,DIFFUSE_LIGHT);
}
