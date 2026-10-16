shader_type spatial;
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
#include "wet_bank.gdshaderinc"
// This single world-anchored skin carries grass, rock and shallow mineral bed.
// Vertex R is physical top cover; UV is authored cap/water height.
uniform bool show_grid = false;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 vec3 stone=stone_surface(world_position,n);
 stone=stone_root_contact(stone,world_position,n,UV.x,UV.y<0.0?1.0:0.0);
 float cover=clamp(COLOR.r,0.0,1.0);
 vec2 slope=vec2(0.0);
 if(cover>.001){
  float detail=1.0-smoothstep(.35,1.0,length(fwidth(world_position.xz))*9.0);
  vec3 grass=ground_cover(world_position,detail,slope);
  stone=mix(stone,grass,cover);
 }
 if(UV.y>=0.0 && world_position.y<UV.y+.02 && n.y>0.0){
  vec3 mineral=textureLod(stone_mineral_map,world_position.xz*.28,2.5).rgb;
  vec3 bed=mix(vec3(.25,.27,.22),mineral*vec3(.91,.94,.82),.32);
  stone=mix(wet_bank_material(world_position),bed,smoothstep(.04,.32,UV.y-world_position.y));
 }
 if(show_grid && cover>.5){vec2 grid=abs(fract(world_position.xz)-.5);stone=mix(stone,vec3(.91,.95,.66),step(.486,max(grid.x,grid.y))*.35);}
 ALBEDO=stone;
 vec3 normal_world=normalize(mix(stone_normal(world_position,n),normalize(n+vec3(-slope.x,0.0,-slope.y)*.55),cover));
 NORMAL=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
 ROUGHNESS=mix(stone_map(world_position,n).a,.95,cover);SPECULAR=.16;
}
