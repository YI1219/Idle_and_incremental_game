shader_type spatial;
render_mode cull_disabled;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
#include "wet_bank.gdshaderinc"
uniform sampler2D ground_detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float caustic_strength : hint_range(0.0,1.0) = .035;
uniform float caustic_time = -1.0;
uniform float rock_bank_strength : hint_range(0.0,1.0) = 0.0;
varying vec3 world_position;
varying float light_water_height;
varying float rock_bank_weight;
float bed_light(vec2 p,float t){
 vec2 q=p*1.50+vec2(sin(p.y*.8+t*.18),sin(p.x*.9-t*.14))*.60;
 float a=q.x*2.8+sin(q.y*1.45+t*.34)*1.5+sin(q.x*.37-q.y*.75+t*.13)*.45;
 float b=q.y*3.1+sin(q.x*1.25-t*.28)*1.4+sin(q.y*.47+q.x*.61-t*.10)*.50;
 float focus=sin(a)+sin(b)*.78+sin(a*.43-b*.57+t*.19)*.50;
 float width=max(.26,fwidth(focus)*1.3);
 float ribbon=1.0-smoothstep(.04,width,abs(focus-.35));
 float patch=.35+.65*smoothstep(.35,.85,.5+.5*sin(q.x*.65+q.y*.31+t*.12)*sin(q.y*.57-q.x*.44-t*.08));
 return ribbon*patch;
}
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float level=round(COLOR.r*255.0)*.5;
 light_water_height=level+terrain_morph_offset(vec3(world_position.x,level,world_position.z));
 rock_bank_weight=COLOR.g;
 float morph=terrain_morph_offset(world_position);
 VERTEX.y+=morph;world_position.y+=morph;
}
void fragment(){
 vec3 n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 vec3 mineral=textureLod(stone_mineral_map,world_position.xz*.22,3.5).rgb;
 vec4 grain=texture(ground_detail_map,world_position.xz*.36);
 ALBEDO=mix(vec3(.11,.19,.16),mineral*vec3(.86,.92,.84),.16)*(.99+grain.r*.02);
 n=normalize(mix(n,stone_normal(world_position,n),.04));
 float depth=max(0.0,light_water_height-world_position.y);
 ALBEDO=mix(wet_bank_material(world_position),ALBEDO,smoothstep(.04,.34,depth));
 if(rock_bank_strength>0.0 && rock_bank_weight>0.0){
  float rock_mix=rock_bank_strength*rock_bank_weight*(1.0-smoothstep(.10,.65,depth));
  ALBEDO=mix(ALBEDO,stone_surface(world_position,n)*.96,rock_mix);
 }
 float light_depth=smoothstep(.035,.18,depth)*(1.0-smoothstep(.7,3.2,depth));
 float time=caustic_time<0.0?TIME:caustic_time;
 float light_web=0.0;
 if(caustic_strength>0.0)light_web=bed_light(world_position.xz,time)*light_depth*caustic_strength;
 ALBEDO*=1.0+light_web;
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 ROUGHNESS=.90;SPECULAR=.08;
}
void light(){
 stone_gouache_light(NORMAL,LIGHT,LIGHT_COLOR,ATTENUATION,DIFFUSE_LIGHT);
}
