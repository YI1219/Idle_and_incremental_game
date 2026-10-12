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
	// COLOR is a linear multiplier around 1. Skyward normals keep each blade
	// from flashing; the root stays darker so the tuft sits in the loam.
	vec3 tint=max(COLOR.rgb,vec3(0.001));
	vec3 root=vec3(.18,.22,.13)*tint;
	vec3 blade=vec3(.40,.45,.27)*tint;
	ALBEDO=mix(root,blade,smoothstep(.04,.78,tip));
	vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
	NORMAL=normalize(mix(NORMAL,up,.91));
	ROUGHNESS=.97;
	BACKLIGHT=vec3(.03,.04,.018)*smoothstep(.40,1.0,tip);
}
