shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
render_mode cull_disabled, specular_disabled;
// Standing cover squashes with the same world mask as the lawn shader.
// grass_compression uniforms come from ground_cover.gdshaderinc.
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
}
void fragment(){
	// The clump uses the cap colour at this spot. The root is a little
	// darker so the tuft sits in the sod; the tip matches the lawn.
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float detail=1.0-smoothstep(.35,1.0,length(fwidth(world.xz))*9.0);
	vec2 slope;
	vec3 color=ground_cover(world.xz,detail,slope);
	float tip=smoothstep(0.0,.55,UV.y);
	color*=mix(vec3(.80,.82,.72),vec3(1.0),tip);
	ALBEDO=color*COLOR.rgb;
	vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
	NORMAL=normalize(up);
	ROUGHNESS=1.0;
}
