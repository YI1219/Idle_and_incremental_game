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
 float phase=foam_time<0.0?TIME:foam_time;
 float churn=noise(world_xz*7.0+vec2(phase*.35,-phase*.55));
 float patch=noise(world_xz*3.8+vec2(-phase*.18,phase*.26));
 float crest=1.0-COLOR.b;
 float core=smoothstep(.45,.95,COLOR.a)*(1.0-crest);
 ALBEDO=mix(vec3(.24,.40,.40),vec3(.57,.65,.61),smoothstep(.28,.76,churn*.65+patch*.35));
 // Broken low froth remains connected to the impact rather than a white pad.
 float froth=smoothstep(.28,.68,churn*.65+patch*.35);
 float broken=.24+.58*froth;
 ALPHA=COLOR.a*mix(broken,mix(.12,.62,smoothstep(.25,.65,churn)),crest);
 // Aerated plunge water scatters light; keeps the core white on the shaded side.
 EMISSION=vec3(.012,.020,.018)*core*froth;
 if(COLOR.r<.5){ALBEDO=vec3(.62,.75,.71); ALPHA=COLOR.a*smoothstep(.36,.66,churn*.4+patch*.6)*.72; EMISSION=vec3(0.0);}
 ROUGHNESS=.78;
 SPECULAR=.15;
}
