shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
// Core cliff hull shader (grazing-safe facet lighting)
render_mode cull_disabled;
uniform bool follow_land_morph = true;
varying vec3 world_position;
varying float v_world_ny;
void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	v_world_ny=normalize(MODEL_NORMAL_MATRIX*NORMAL).y;
	if(follow_land_morph)VERTEX.y+=terrain_morph_offset(world_position);
}
void fragment(){
	vec3 material_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
	if(UV.y<-.5)material_normal=normalize(mix(material_normal,vec3(0.0,-1.0,0.0),.55));
	vec3 detail_n=stone_normal(world_position*1.65,material_normal);
	vec3 shade_n=normalize(mix(material_normal,detail_n,.09));
	vec3 stone=stone_root_contact(stone_surface(world_position,shade_n),world_position,material_normal,UV.x,UV.y)*mix(vec3(1.0),COLOR.rgb,.16);
	ALBEDO=stone_mist_dissolve(stone,world_position,material_normal);
	ROUGHNESS=1.0;SPECULAR=0.0;
	// Occlusion follows downward shelter, independently of the moving key light.
	AO=mix(1.0,.88,1.0-smoothstep(-.65,.15,material_normal.y));
	NORMAL=normalize((VIEW_MATRIX*vec4(material_normal,0.0)).xyz);
}
void light(){
 stone_painted_light(NORMAL,LIGHT,LIGHT_COLOR,ATTENUATION,v_world_ny,DIFFUSE_LIGHT);
}
