shader_type spatial;
#include "terrain_morph.gdshaderinc"
render_mode cull_disabled, specular_disabled;
// Standing cover squashes with the same world mask as the lawn shader.
uniform sampler2D grass_compression : filter_linear, repeat_disable, hint_default_black;
uniform vec2 compression_origin = vec2(-64.0);
uniform vec2 compression_extent = vec2(128.0);
varying float tip;
float turf_standing(vec2 p){
	vec2 uv=(p-compression_origin)/compression_extent;
	float inside=step(0.0,uv.x)*step(0.0,uv.y)*step(uv.x,1.0)*step(uv.y,1.0);
	return 1.0-texture(grass_compression,uv).r*inside;
}
void vertex(){
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float standing=turf_standing(world.xz);
	VERTEX.y*=standing;
	if(terrain_morph_progress<1.0){
		VERTEX.y+=terrain_morph_offset(world);
	}
	tip=UV.y;
}
void fragment(){
	vec3 tint=COLOR.rgb;
	tint=mix(pow((tint+vec3(.055))*(1.0/1.055),vec3(2.4)),tint*(1.0/12.92),lessThan(tint,vec3(.04045)));
	vec3 root=tint*vec3(.90,.94,.86);
	vec3 blade=tint*vec3(1.02,1.04,.96);
	ALBEDO=mix(root,blade,smoothstep(.08,.85,tip));
	vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
	NORMAL=normalize(mix(NORMAL,up,.72));
	ROUGHNESS=.98;
}
