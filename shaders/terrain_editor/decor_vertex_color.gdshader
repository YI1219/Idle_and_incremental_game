shader_type spatial;
#include "terrain_morph.gdshaderinc"
// Vertex-coloured CC0 decoration. Matches the standard material it replaces
// (sRGB vertex colour, rough) and rises with an edit instead of popping.
void vertex(){
	COLOR.rgb=mix(pow((COLOR.rgb+vec3(.055))*(1.0/1.055),vec3(2.4)),COLOR.rgb*(1.0/12.92),lessThan(COLOR.rgb,vec3(.04045)));
	if(terrain_morph_progress<1.0){
		vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
		VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(origin),0.0,0.0)).xyz;
	}
}
void fragment(){
	ALBEDO=COLOR.rgb;
	ROUGHNESS=.96;
	SPECULAR=.06;
}
