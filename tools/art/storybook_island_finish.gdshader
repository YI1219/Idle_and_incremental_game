shader_type spatial;
render_mode diffuse_burley, specular_disabled;
#include "res://shaders/terrain_editor/land_palette.gdshaderinc"
#include "res://shaders/terrain_editor/ground_cover.gdshaderinc"
#include "res://shaders/terrain_editor/cliff_palette.gdshaderinc"
#include "res://shaders/terrain_editor/stone_surface.gdshaderinc"
uniform vec4 stone_tint: source_color = vec4(.62,.65,.58,1.0);
uniform vec4 lower_tint: source_color = vec4(.43,.51,.51,1.0);
uniform float layer_style = 0.0;
uniform float painted_rock_strength=0.0;
uniform float facet_tone_strength=0.0;
uniform float painted_albedo_strength=0.0;
uniform bool show_grid = false;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 float depth=max(0.0,UV.x-world_position.y);
 float broad=sin(world_position.x*.49+sin(world_position.z*.37)*.7)*.5+.5;
 vec3 rock=mix(stone_tint.rgb,lower_tint.rgb,smoothstep(.8,5.4,depth)*.58);
 rock*=.97+.055*broad;
 // Retain quiet painted mineral variation at a coarse scale. Stylization
 // removes fine relief, not every material cue or all value variation.
 vec3 weights=stone_weights(n);
 vec3 paint=textureLod(stone_mineral_map,world_position.zy*.22,3.0).rgb*weights.x+textureLod(stone_mineral_map,world_position.xz*.22,3.0).rgb*weights.y+textureLod(stone_mineral_map,world_position.xy*.22,3.0).rgb*weights.z;
 rock*=vec3(.84)+paint*.32;
 rock*=.96+.08*tw_noise(world_position*.58);
 rock=mix(rock,stone_surface(world_position,n),painted_rock_strength);
 rock=mix(rock,paint*vec3(.91,.98,1.02),painted_albedo_strength);
 float face_tone=rock_hash(floor(n*17.0)).x-.5;
 rock*=1.0+face_tone*facet_tone_strength;
 if(layer_style>.5){
  float layer=smoothstep(.04,.13,abs(sin(depth*1.55+world_position.x*.025)));
  rock*=mix(.86,1.02,layer);
 }
 vec2 slope=vec2(0.0);
 vec3 lawn=ground_cover(world_position,.28,slope);
 // Quiet soft contact: no dark brown extrusion/painted shoulder. Geometry
 // and root support still come from the exact same scalar terrain surface.
 float cover=clamp(COLOR.r,0.0,1.0);
 ALBEDO=mix(rock,lawn,cover);
 if(UV.y>=0.0 && world_position.y<UV.y+.02 && n.y>0.0){
  vec3 bed=textureLod(stone_mineral_map,world_position.xz*.28,2.5).rgb;
  ALBEDO=mix(vec3(.16,.20,.15),bed*vec3(.71,.78,.63),.30);
 }
 if(show_grid && cover>.5){vec2 grid=abs(fract(world_position.xz)-.5);ALBEDO=mix(ALBEDO,vec3(.8,.9,.6),step(.486,max(grid.x,grid.y))*.25);}
 ROUGHNESS=.98;
}
