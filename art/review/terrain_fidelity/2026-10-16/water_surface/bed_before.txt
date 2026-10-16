shader_type spatial;
render_mode cull_disabled;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
#include "wet_bank.gdshaderinc"
uniform sampler2D ground_detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float caustic_strength : hint_range(0.0,1.0) = .12;
// Negative follows engine time; a nonnegative value freezes review fixtures.
uniform float caustic_time = -1.0;
varying vec3 world_position;
varying float light_water_height;
float bed_light(vec2 p,float t){
 vec2 warp=vec2(sin(p.y*2.1+sin(p.x*1.4)+t*.35),sin(p.x*1.8+sin(p.y*2.4)-t*.30));
 vec2 g=p*1.65+warp*.45;
 vec2 cell=floor(g),f=fract(g);
 float first=10.0,second=10.0;
 for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
  vec2 offset=vec2(float(x),float(y));
  vec3 seed=rock_hash(vec3(cell+offset,13.0));
  vec2 point=.20+seed.xy*.60+sin(vec2(t*.48,-t*.39)+seed.yz*6.28318)*.12;
  vec2 delta=offset+point-f;
  float distance=dot(delta,delta);
  if(distance<first){second=first;first=distance;}
  else second=min(second,distance);
 }
 float patches=smoothstep(.30,.70,stone_noise(vec3(p*.65,t*.10)));
 return (1.0-smoothstep(.006,.085,second-first))*patches;
}
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float level=round(COLOR.r*255.0)*.5;
 light_water_height=level+terrain_morph_offset(vec3(world_position.x,level,world_position.z));
 float morph=terrain_morph_offset(world_position);
 VERTEX.y+=morph;world_position.y+=morph;
}
void fragment(){
 vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 vec3 mineral=textureLod(stone_mineral_map,world_position.xz*.28,2.5).rgb;
 vec4 grain=texture(ground_detail_map,world_position.xz*.48);
 ALBEDO=mix(vec3(.25,.27,.22),mineral*vec3(.91,.94,.82),.32)*(.98+grain.r*.04);
 // Submerged mineral relief stays quiet instead of looking like rough dry
 // rock viewed through a blue fog. Actual bank geometry/shadows remain.
 n=normalize(mix(n,stone_normal(world_position,n),.12));
 float depth=max(0.0,light_water_height-world_position.y);
 ALBEDO=mix(wet_bank_material(world_position),ALBEDO,smoothstep(.04,.32,depth));
 float light_depth=smoothstep(.035,.18,depth)*(1.0-smoothstep(.7,3.2,depth));
 float time=caustic_time<0.0?TIME:caustic_time;
 float light_web=0.0;
 if(caustic_strength>0.0 && light_depth>.0001)light_web=bed_light(world_position.xz,time)*light_depth*caustic_strength;
 // Albedo modulation keeps the projected light inside real bed shadows.
 ALBEDO*=1.0+light_web;
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 ROUGHNESS=.85;SPECULAR=.20;
}
