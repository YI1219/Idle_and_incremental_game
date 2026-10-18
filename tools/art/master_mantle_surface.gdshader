shader_type spatial;
#include "res://shaders/terrain_editor/land_palette.gdshaderinc"
#include "res://shaders/terrain_editor/ground_cover.gdshaderinc"
#include "res://shaders/terrain_editor/cliff_palette.gdshaderinc"
#include "res://shaders/terrain_editor/stone_surface.gdshaderinc"
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 vec3 stone=stone_surface(world_position,n);
 vec2 slope;
 vec3 lawn=ground_cover(world_position,1.0,slope);
 float depth=COLOR.r;
 float owned=COLOR.g;
 float grass=owned*(1.0-smoothstep(.025,.10,depth))*smoothstep(.45,.78,n.y);
 float earth=owned*(1.0-smoothstep(.13,.29,depth))*(1.0-grass);
 vec3 soil=mix(vec3(.18,.15,.105),vec3(.30,.25,.16),gc_noise(world_position.xz*6.3));
 ALBEDO=mix(mix(stone,soil,earth*.8),lawn,grass);
 ROUGHNESS=mix(stone_map(world_position,n).a,.96,max(grass,earth));SPECULAR=.16;
 vec3 final_normal=normalize(mix(stone_normal(world_position,n),normalize(n+vec3(-slope.x,0,-slope.y)*.55),grass));
 NORMAL=normalize((VIEW_MATRIX*vec4(final_normal,0.0)).xyz);
}
