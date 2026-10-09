shader_type spatial;
#include "terrain_morph.gdshaderinc"
render_mode cull_disabled, shadows_disabled;
varying vec2 world_xz;
void vertex(){
 world_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
 VERTEX.y+=terrain_morph_offset((MODEL_MATRIX*vec4(VERTEX,1.0)).xyz);
 VERTEX.y+=sin(world_xz.x*8.0+world_xz.y*6.0+TIME*3.0)*.012*COLOR.a;
}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x),u.y);}
void fragment(){
 float churn=noise(world_xz*7.0+vec2(TIME*.35,-TIME*.55));
 float patch=noise(world_xz*3.8+vec2(-TIME*.18,TIME*.26));
 float crest=1.0-COLOR.b;
 float core=smoothstep(.45,.95,COLOR.a)*(1.0-crest);
 ALBEDO=mix(vec3(.55,.68,.66),vec3(.93,.94,.90),mix(churn*.35+.65,1.0,core));
 // Broken low froth remains connected to the impact rather than a white pad.
 float froth=smoothstep(.28,.68,churn*.65+patch*.35);
 float broken=mix(.46+.52*froth,1.0,smoothstep(.40,.80,COLOR.a));
 ALPHA=COLOR.a*mix(broken,mix(.12,.62,smoothstep(.25,.65,churn)),crest);
 // Aerated plunge water scatters light; keeps the core white on the shaded side.
 EMISSION=vec3(.20,.20,.18)*core;
 if(COLOR.r<.5){ALBEDO=vec3(.84,.90,.86); ALPHA=COLOR.a*(.50+churn*.35); EMISSION=vec3(0.0);}
 ROUGHNESS=.78;
 SPECULAR=.15;
}
