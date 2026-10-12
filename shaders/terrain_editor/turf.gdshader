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
	float tip=smoothstep(0.0,.65,UV.y);
	// Slightly under the cap, never a paler card. The normal follows the
	// same gentle tilt as the lawn so the tuft does not catch extra sun.
	color*=mix(vec3(.90),vec3(.97),tip);
	ALBEDO=color*COLOR.rgb;
	// Same tilt as the cap. A geometric blade normal lights the fringe as a
	// pale spike, so the tuft takes the lawn's light instead.
	vec3 normal_world=normalize(vec3(-slope.x*.25,1.0,-slope.y*.25));
	NORMAL=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	ROUGHNESS=1.0;
}
