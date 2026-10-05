shader_type spatial;
#include "cliff_palette.gdshaderinc"
varying vec3 rock_origin;
void vertex(){rock_origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;}
void fragment(){
	// Each retained model already has physical flat faces. Match the body
	// palette without repeating its nearest-site search at every rock pixel.
	vec3 variation=rock_hash(floor(rock_origin/vec3(2.2,1.8,2.2))+vec3(17.0));
	ALBEDO=cliff_gray(variation.x)*clamp(COLOR.r/.714,.85,1.06);
	ROUGHNESS=.96;
	SPECULAR=.15;
}
