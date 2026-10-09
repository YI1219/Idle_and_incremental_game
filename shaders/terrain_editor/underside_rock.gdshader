shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
// Rounded boulder masses that make up the island underside and corners.
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 rock_origin;
varying vec3 world_normal;
void vertex(){
	rock_origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	world_normal=normalize((MODEL_MATRIX*vec4(NORMAL,0.0)).xyz);
	if(terrain_morph_progress<1.0){vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(origin),0.0,0.0)).xyz;}
}
void fragment(){
	vec3 variation=rock_hash(floor(rock_origin/vec3(2.2,1.8,2.2))+vec3(17.0));
	// The source texture's value carries chips and seams; its moss hue is
	// replaced by the shared cliff stone palette.
	vec3 source=texture(detail_tex,UV).rgb;
	float detail=dot(source,vec3(.30,.59,.11));
	vec3 stone=cliff_gray(variation.x)*mix(vec3(1.0),COLOR.rgb,.5)*mix(.86,1.12,smoothstep(.15,.55,detail));
	// Overhanging faces stay in deeper shade, as under a real floating mass.
	stone*=mix(.82,1.0,smoothstep(-.85,.25,world_normal.y));
	ALBEDO=stone;
	ROUGHNESS=.94;
	SPECULAR=.18;
}
