shader_type spatial;
#include "res://shaders/terrain_editor/land_palette.gdshaderinc"
#include "res://shaders/terrain_editor/ground_cover.gdshaderinc"
#include "res://shaders/terrain_editor/cliff_palette.gdshaderinc"
#include "res://shaders/terrain_editor/stone_surface.gdshaderinc"
uniform bool contact_finish=false;
varying vec3 world_position;
varying vec3 local_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;local_position=VERTEX;}
void fragment(){
 vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 vec3 rock=stone_surface(world_position,n);
 vec3 rock_normal=stone_normal(world_position,n);
 float depth=COLOR.r;
 float cover=(1.0-smoothstep(.025,.055,depth))*smoothstep(.4,.65,n.y);
 if(contact_finish){
  // A height/slope-driven ecotone on the same physical surface. Sparse
  // recesses interrupt the narrow soil edge; grass geometry supplies volume.
  float pocket=smoothstep(.46,.68,gc_noise(local_position.xz*2.7+vec2(3,8)));
  float noise=gc_noise(local_position.xz*14.0)*.045;
  float top=(1.0-smoothstep(.025,.08,depth+noise*.3))*smoothstep(.38,.78,n.y);
  float remnant=(1.0-smoothstep(.06,.19,depth+noise))*smoothstep(.32,.76,n.y)*pocket;
  cover=max(top,remnant);
  float soil=(1.0-smoothstep(.04,.26,depth))*smoothstep(.18,.65,n.y)*(1.0-cover);
  vec3 earth=mix(vec3(.18,.15,.105),vec3(.30,.25,.16),gc_noise(local_position.xz*6.3));
  rock=mix(rock,earth,soil*.62);
 }
 vec2 slope;
 vec3 grass=ground_cover(world_position,1.0,slope);
 ALBEDO=mix(rock,grass,cover);
 ROUGHNESS=mix(stone_map(world_position,n).a,.96,cover);SPECULAR=.16;
 vec3 final_normal=normalize(mix(rock_normal,normalize(n+vec3(-slope.x,0,-slope.y)*.55),cover));
 NORMAL=normalize((VIEW_MATRIX*vec4(final_normal,0.0)).xyz);
}
