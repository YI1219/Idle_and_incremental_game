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
float turf_wave(vec2 p){return .055*sin(p.x*.8+p.y*.3)*sin(p.y*.62-p.x*.21);}
void vertex(){
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	// The clump is placed on the wave at its centre. Conform the whole lobe
	// to the same wave so a flat sheet does not hover and draw its outline.
	float sy=max(length((MODEL_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz),.0001);
	VERTEX.y+=(turf_wave(world.xz)-turf_wave(origin.xz))/sy;
	float standing=turf_standing(world.xz);
	VERTEX.y*=standing;
	if(terrain_morph_progress<1.0){
		VERTEX.y+=terrain_morph_offset(world);
	}
}
void fragment(){
	// Identical lawn colour and nap to the cap. Instance tint is ignored so
	// a lobe cannot cut a disc out of the carpet.
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float detail=1.0-smoothstep(55.0,120.0,length(VERTEX));
	vec2 slope;
	vec3 color=lawn_color(world.xz,detail,slope); // same nap as the cap
	ALBEDO=color;
	vec3 normal_world=lawn_normal(vec3(0.0,1.0,0.0),slope,detail,.55);
	NORMAL=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	ROUGHNESS=1.0;
}
