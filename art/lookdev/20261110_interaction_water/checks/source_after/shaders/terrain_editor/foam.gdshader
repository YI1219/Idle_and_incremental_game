shader_type spatial;
#include "terrain_morph.gdshaderinc"
render_mode cull_disabled, shadows_disabled;
uniform float foam_time = -1.0;
varying vec2 world_xz;
void vertex(){
 float phase=foam_time<0.0?TIME:foam_time;
 world_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
 VERTEX.y+=terrain_morph_offset((MODEL_MATRIX*vec4(VERTEX,1.0)).xyz);
 VERTEX.y+=sin(world_xz.x*8.0+world_xz.y*6.0+phase*3.0)*.012*COLOR.a;
}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x),u.y);}
void fragment(){
 if(!terrain_transition_visible(FRAGCOORD.xy))discard;
 float phase=foam_time<0.0?TIME:foam_time;
 float churn=noise(world_xz*7.0+vec2(phase*.35,-phase*.55));
 float patch=noise(world_xz*3.8+vec2(-phase*.18,phase*.26));
 float crest=1.0-COLOR.b;
 float core=smoothstep(.52,.96,COLOR.a)*(1.0-crest);
 ALBEDO=mix(vec3(.16,.37,.39),vec3(.50,.64,.63),smoothstep(.32,.80,churn*.65+patch*.35));
 // Translucent jade-mist froth at the plunge foot (never a heavy white pad!).
 float froth=smoothstep(.34,.74,churn*.65+patch*.35);
 float broken=.12+.36*froth;
 ALPHA=COLOR.a*mix(broken,mix(.05,.32,smoothstep(.32,.72,churn)),crest);
 EMISSION=vec3(.008,.015,.015)*core*froth;
 if(COLOR.r<.5){
  float arc=smoothstep(.34,.64,noise(world_xz*.95+vec2(phase*.12,-phase*.16)));
  ALBEDO=vec3(.34,.55,.55);
  ALPHA=COLOR.a*smoothstep(.42,.72,churn*.4+patch*.6)*arc*.38;
  EMISSION=vec3(0.0);
 }
 ROUGHNESS=.78;
 SPECULAR=.15;
}
