shader_type spatial;
render_mode cull_disabled, shadows_disabled;
#include "terrain_morph.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
varying vec3 world_position;
varying float tongue;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float standing=gc_standing(UV2);
 vec3 anchor=vec3(UV2.x,UV.x-.006,UV2.y);
 VERTEX=mix(anchor,VERTEX,standing);
 VERTEX.y+=terrain_morph_offset(world_position);
 tongue=UV.y;
}
void fragment(){
 vec2 slope;
 vec3 green=ground_cover(world_position.xz,.65,slope);
 // Ragged turf edges, anchored intact at the shoulder. Local attributes are
 // normalized; world anchors stay in UV2 so GPU color packing is harmless.
 float ragged=gc_noise(vec2(COLOR.r*13.0,tongue*21.0)+COLOR.g*37.0);
 float edge=min(COLOR.r,1.0-COLOR.r);
 ALPHA=step((.035+.13*ragged)*smoothstep(.03,.25,tongue),edge);
 ALPHA_SCISSOR_THRESHOLD=.5;
 float fleck=gc_noise(world_position.xz*19.0+world_position.y*7.0);
 ALBEDO=green*mix(.99,.83,tongue)*(.93+.20*fleck);
 vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
 NORMAL=normalize(mix(NORMAL,up,.78));
 ROUGHNESS=.96;SPECULAR=.12;
}
