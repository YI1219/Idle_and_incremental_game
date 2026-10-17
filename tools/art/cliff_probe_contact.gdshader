shader_type spatial;
#include "res://shaders/terrain_editor/land_palette.gdshaderinc"
#include "res://shaders/terrain_editor/ground_cover.gdshaderinc"
#include "res://shaders/terrain_editor/cliff_palette.gdshaderinc"
#include "res://shaders/terrain_editor/stone_surface.gdshaderinc"
uniform sampler2D probe_stone_height : filter_linear_mipmap,repeat_enable;
uniform sampler2D probe_ground_height : filter_linear_mipmap,repeat_enable;
uniform bool height_contact=false;
uniform bool cover_enabled=false;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 vec3 stone=stone_surface(world_position,n);
 vec3 final_normal=stone_normal(world_position,n);
 float cover=smoothstep(3.25,3.51,world_position.y)*smoothstep(.35,.85,n.y);
 if(!cover_enabled)cover=0.0;
 if(height_contact && cover>.001 && cover<.999){
  vec3 w=stone_weights(n);
  float rock=texture(probe_stone_height,world_position.zy*.38).r*w.x+texture(probe_stone_height,world_position.xz*.38).r*w.y+texture(probe_stone_height,world_position.xy*.38).r*w.z;
  float turf=texture(probe_ground_height,world_position.xz*.48).r;
  // Relative source height fields, not mineral albedo used as fake height.
  vec2 h=vec2(1.0-cover,cover)+vec2(rock,turf)*.35;
  vec2 weights=max(h-vec2(max(h.x,h.y)-.35),vec2(0.0));
  cover=weights.y/max(weights.x+weights.y,.0001);
 }
 vec2 slope=vec2(0.0);
 if(cover>.001){
  vec3 grass=ground_cover(world_position,1.0,slope);
  stone=mix(stone,grass,cover);
  final_normal=normalize(mix(final_normal,normalize(n+vec3(-slope.x,0.0,-slope.y)*.55),cover));
 }
 ALBEDO=stone;ROUGHNESS=mix(stone_map(world_position,n).a,.95,cover);SPECULAR=.16;
 NORMAL=normalize((VIEW_MATRIX*vec4(final_normal,0.0)).xyz);
}
