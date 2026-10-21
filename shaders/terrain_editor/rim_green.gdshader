shader_type spatial;
render_mode cull_disabled;
#include "terrain_morph.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
varying vec3 world_position;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float standing=gc_standing(UV2);
 vec3 anchor=vec3(UV2.x,UV.x-.006,UV2.y);
 VERTEX=mix(anchor,VERTEX,standing);
 VERTEX.y+=terrain_morph_offset(world_position);
}
void fragment(){
 vec2 slope;
 vec3 green=ground_cover(world_position,.65,slope);
 ALBEDO=green;
 vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
 NORMAL=normalize(mix(NORMAL,up,.35));
 // Leaf roots share lawn relief; upper leaves keep their curved lighting.
 float root_zone=1.0-smoothstep(.025,.07,abs(world_position.y-UV.x));
 vec3 relief=(VIEW_MATRIX*vec4(-slope.x,0.0,-slope.y,0.0)).xyz;
 NORMAL=normalize(NORMAL+(relief-NORMAL*dot(NORMAL,relief))*.55*root_zone);
 ROUGHNESS=.96;SPECULAR=.12;
}
