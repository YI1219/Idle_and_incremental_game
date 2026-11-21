shader_type spatial;
render_mode cull_disabled;
#include "terrain_morph.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
varying vec3 world_position;
void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float standing=gc_standing(UV2);
	vec3 anchor=vec3(UV2.x,UV.x-.006,UV2.y);
	VERTEX=mix(anchor,VERTEX,standing);
	VERTEX.y+=terrain_morph_offset(world_position);
}
void fragment(){
 if(!terrain_transition_visible(FRAGCOORD.xy))discard;
	vec2 slope;
	vec3 green=ground_cover(world_position,.65,slope);
	vec3 n_world=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
	float fleck=gc_noise(world_position.xz*4.2+world_position.y*3.1);
	// Luminous sunlit sod rim crest on top bevel + clean dark underside tuck at the very bottom skirt:
	float top_rim=smoothstep(.25,.82,n_world.y);
	float under_skirt=smoothstep(.18,-.35,n_world.y);
	vec3 sunlit_rim=green*vec3(1.08,1.07,.88);
	vec3 sod_edge=mix(green*vec3(.82,.88,.74),vec3(.11,.17,.08),fleck*.42);
	vec3 col=mix(sod_edge,sunlit_rim,top_rim);
	ALBEDO=col*mix(1.0,.68,under_skirt);
	vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
	NORMAL=normalize(mix(NORMAL,up,.52));
	ROUGHNESS=.94;
	SPECULAR=.02;
}
void light(){
	stone_gouache_light(NORMAL,LIGHT,LIGHT_COLOR,ATTENUATION,DIFFUSE_LIGHT);
}
