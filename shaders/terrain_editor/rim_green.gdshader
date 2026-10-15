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
 vec3 root=green*vec3(.63,.62,.48);
 ALBEDO=mix(green,root,smoothstep(.48,.95,tongue)*.55)*(.97+.06*fleck);
 vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
 NORMAL=normalize(mix(NORMAL,up,.12));
 // Only the physical sod tips fray. The lawn and stone retain solid joins;
 // this breaks the repeated rounded-card silhouette at close range.
 float fray=gc_noise(world_position.xz*51.0+world_position.y*23.0);
 ALPHA=1.0-smoothstep(.72,1.08,tongue+fray*.30);
 ALPHA_SCISSOR_THRESHOLD=.5;
 ROUGHNESS=.96;SPECULAR=.12;
}
