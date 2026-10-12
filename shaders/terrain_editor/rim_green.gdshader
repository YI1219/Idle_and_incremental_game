shader_type spatial;
render_mode cull_disabled;
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
 float fleck=gc_noise(world_position.xz*19.0+world_position.y*7.0);
 ALBEDO=green*mix(1.0,.86,smoothstep(.25,1.0,tongue))*(.94+.16*fleck);
 vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
 NORMAL=normalize(mix(NORMAL,up,mix(.62,.94,smoothstep(.15,.9,tongue))));
 ROUGHNESS=.96;SPECULAR=.12;
}
