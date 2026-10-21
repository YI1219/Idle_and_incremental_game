shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
uniform float bank_stone = 0.0;
varying vec3 rock_origin;
varying vec3 world_position;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	rock_origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	if(terrain_morph_progress<1.0){vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(origin),0.0,0.0)).xyz;}
}
void fragment(){
 vec3 material_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
	// Each retained model already has physical flat faces. Match the body
	// palette without repeating its nearest-site search at every rock pixel.
	vec3 variation=rock_hash(floor(rock_origin/vec3(2.2,1.8,2.2))+vec3(17.0));
	float wet=bank_stone*(1.0-smoothstep(.12,.28,world_position.y-rock_origin.y));
	ALBEDO=stone_surface(world_position,material_normal)*(.73+.20*variation.x)*clamp(COLOR.r/.714,.75,1.02)*mix(1.0,.79,wet);
	ROUGHNESS=mix(stone_map(world_position,material_normal).a,.76,wet);
	SPECULAR=.15;
 NORMAL=normalize((VIEW_MATRIX*vec4(stone_normal(world_position,material_normal),0.0)).xyz);
}
