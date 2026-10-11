shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
render_mode cull_disabled;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;VERTEX.y+=terrain_morph_offset(world_position);}
void fragment(){
 ALBEDO=stone_surface(world_position)*mix(vec3(1.0),COLOR.rgb,.55);
 ROUGHNESS=.96;SPECULAR=.16;AO=.94;
}
