shader_type spatial;
render_mode cull_disabled, shadows_disabled;
varying vec2 world_xz;
void vertex(){
 world_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
 VERTEX.y+=sin(world_xz.x*8.0+world_xz.y*6.0+TIME*3.0)*.012*COLOR.a;
}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x),u.y);}
void fragment(){
 float churn=noise(world_xz*7.0+vec2(TIME*.35,-TIME*.55));
 float patch=noise(world_xz*3.8+vec2(-TIME*.18,TIME*.26));
 float crest=1.0-COLOR.b;
 ALBEDO=mix(vec3(.60,.84,.87),vec3(.96,.985,.98),churn*.35+.65);
 // Broken low froth remains connected to the impact rather than a white pad.
 float froth=smoothstep(.28,.68,churn*.65+patch*.35);
 float broken=mix(.34+.60*froth,.97,smoothstep(.45,.85,COLOR.a));
 ALPHA=COLOR.a*mix(broken,mix(.12,.62,smoothstep(.25,.65,churn)),crest);
 ROUGHNESS=.78;
 SPECULAR=.15;
}
