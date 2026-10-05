shader_type spatial;
render_mode cull_disabled, shadows_disabled;
varying vec2 world_xz;
void vertex(){
 world_xz=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
 VERTEX.y+=sin(world_xz.x*8.0+world_xz.y*6.0+TIME*3.0)*.025*COLOR.a;
}
void fragment(){
 float churn=.5+.5*sin(world_xz.x*11.0+sin(world_xz.y*9.0-TIME*2.0));
 ALBEDO=mix(vec3(.66,.87,.90),vec3(.96,.985,.98),churn*.35+.65);
 float crest=1.0-COLOR.b;
 float breakup=smoothstep(.18,.72,.5+.5*sin(world_xz.x*5.7+world_xz.y*4.9+sin(world_xz.x*2.1-world_xz.y*1.7-TIME*.7)));
 ALPHA=COLOR.a*.90*mix(1.0,mix(.18,.78,breakup),crest);
 ROUGHNESS=.78;
 SPECULAR=.15;
}
