shader_type spatial;
#include "terrain_morph.gdshaderinc"
// Vertex-coloured CC0 decoration. Matches the standard material it replaces
// (sRGB vertex colour, rough) and rises with an edit instead of popping.
varying float rise;
void vertex(){
	COLOR.rgb=mix(pow((COLOR.rgb+vec3(.055))*(1.0/1.055),vec3(2.4)),COLOR.rgb*(1.0/12.92),lessThan(COLOR.rgb,vec3(.04045)));
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	vec3 pivot=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	rise=world.y-pivot.y;
	if(terrain_morph_progress<1.0){
		VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(pivot),0.0,0.0)).xyz;
	}
}
void fragment(){
	float contact=(1.0-smoothstep(0.0,.12,rise))*smoothstep(-.04,0.0,rise);
	ALBEDO=COLOR.rgb*mix(1.0,.74,contact);
	ROUGHNESS=.96;
	SPECULAR=.06;
}
