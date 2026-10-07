shader_type spatial;
render_mode unshaded,depth_prepass_alpha,shadows_disabled;
varying vec3 world_position;
varying vec3 world_normal;
varying float height;
void vertex(){
 height=VERTEX.y;
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 float light=clamp(dot(normalize(world_normal),normalize(vec3(.65,.65,.15))),0.0,1.0);
 vec3 stone=mix(vec3(.10,.16,.18),vec3(.27,.30,.26),light);
 stone*=.90+COLOR.r*.18;
 float trees=step(.90,COLOR.r);
 stone=mix(stone,mix(vec3(.11,.18,.14),vec3(.23,.29,.18),light),trees);
 float distance_fog=clamp(length(VERTEX)/1800.0,.20,.72);
 vec3 mist=vec3(.52,.55,.53);
 vec3 color=mix(stone,mist,distance_fog);
 float foot=smoothstep(.0,.48,height);
 color=mix(vec3(.78,.74,.65),color,foot);
 ALBEDO=color;
 ALPHA=smoothstep(.04,.35,height);
}
