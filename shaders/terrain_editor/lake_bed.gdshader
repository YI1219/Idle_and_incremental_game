shader_type spatial;
render_mode cull_disabled;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
uniform sampler2D ground_detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=terrain_morph_offset(world_position);
}
void fragment(){
 vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 vec3 mineral=textureLod(stone_mineral_map,world_position.xz*.28,1.5).rgb;
 vec4 grain=texture(ground_detail_map,world_position.xz*.48);
 ALBEDO=mix(vec3(.23,.25,.18),mineral*vec3(.91,.94,.82),.48)*(.94+grain.r*.10);
 n=stone_normal(world_position,n);
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 ROUGHNESS=.85;SPECULAR=.20;
}
