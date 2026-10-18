shader_type spatial;
#include "res://shaders/terrain_editor/land_palette.gdshaderinc"
#include "res://shaders/terrain_editor/ground_cover.gdshaderinc"
#include "res://shaders/terrain_editor/cliff_palette.gdshaderinc"
#include "res://shaders/terrain_editor/stone_surface.gdshaderinc"
#include "res://shaders/terrain_editor/wet_bank.gdshaderinc"
// Quiet broad color, retained physical rock shapes, restrained mineral paint.
uniform bool show_grid=false;
uniform bool world_cap_contact=true;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 float broad=gc_noise(world_position.xz*.34+vec2(7.0,3.0));
 vec3 rock=mix(vec3(.29,.33,.31),vec3(.39,.40,.34),broad);
 rock=mix(rock,stone_surface(world_position,n),.22);
 rock=mix(rock,stone_root_contact(rock,world_position,n,UV.x,UV.y<0.0?COLOR.g:0.0),.35);
 float cover=clamp(COLOR.r,0.0,1.0);
 if(world_cap_contact){
  // B is derived from the actual highest dry cap; it is not an arbitrary
  // world-height stripe, and becomes zero below a higher edited roof.
  float depth=UV.x-world_position.y;
  float reach=.045+.075*gc_noise(world_position.xz*2.0+vec2(17.0,31.0));
  float edge=1.0-smoothstep(reach-.015,reach+.025,depth);
  float upward=smoothstep(-.10,.35,n.y);
  float resolved=edge*upward;
  cover=mix(cover,resolved,smoothstep(.10,.75,COLOR.b));
 }
 vec3 grass=mix(grass_base,grass_highlight,broad*.70+.10);
 grass*=.98+gc_noise(world_position.xz*3.2)*.04;
 float path_distance=1000.0;
 for(int i=0;i<7;i++){
  if(i+1>=footpath_count)break;
  vec2 a=footpath_points[i],edge=footpath_points[i+1]-a;
  float t=clamp(dot(world_position.xz-a,edge)/max(dot(edge,edge),.0001),0.0,1.0);
  path_distance=min(path_distance,length(world_position.xz-a-edge*t));
 }
 float margin=.10*(gc_noise(world_position.xz*4.0)-.5);
 float path=1.0-smoothstep(.42,.94,path_distance+margin);
 grass=mix(grass,vec3(.45,.39,.27),path*.78);
 vec3 color=mix(rock,grass,cover);
 if(UV.y>=0.0 && world_position.y<UV.y+.02 && n.y>0.0)
  color=mix(wet_bank_material(world_position),vec3(.27,.31,.25),smoothstep(.04,.32,UV.y-world_position.y));
 if(show_grid && cover>.5){vec2 grid=abs(fract(world_position.xz)-.5);color=mix(color,vec3(.91,.95,.66),step(.486,max(grid.x,grid.y))*.35);}
 ALBEDO=color;
 vec3 normal_world=normalize(mix(n,stone_normal(world_position,n),.15*(1.0-cover)));
 NORMAL=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
 ROUGHNESS=.98;SPECULAR=.10;
}
