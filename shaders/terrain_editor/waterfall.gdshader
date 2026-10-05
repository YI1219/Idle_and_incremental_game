shader_type spatial;
render_mode blend_mix,depth_draw_never,cull_disabled,shadows_disabled;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
vec2 hash2(vec2 p){return fract(sin(vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))))*43758.5453);}
vec2 veins(vec2 p){
	vec2 cell=floor(p);vec2 f=fract(p);float first=10.0;float second=10.0;vec2 selected=vec2(0.0);
	for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
		vec2 offset=vec2(float(x),float(y));vec2 d=offset+hash2(cell+offset)-f;float v=dot(d,d);
		if(v<first){second=first;first=v;selected=cell+offset;}else if(v<second){second=v;}
	}
	float border=second-first;
	float softness=max(.022,fwidth(border)*.9);
	float edge=1.0-smoothstep(.010,.010+softness,border);
	float brightness=mix(.48,1.0,smoothstep(.18,.82,hash2(selected+vec2(17.0)).y));
	return vec2(edge*brightness,hash2(selected).x);
}
vec3 flow_at(vec2 coordinates){
	vec2 flow=coordinates*vec2(4.4,1.7)+vec2(0.0,TIME*1.25);
	flow.x+=sin(flow.y*1.8)*.20+sin(flow.x*.93+flow.y*.73)*.10;
	vec2 field=veins(flow);
	float strand=pow(.5+.5*sin(flow.x*4.5+sin(flow.y*.45)*.22),7.0);
	strand*=.65+.35*sin(flow.y*.8+flow.x*2.3);
	return vec3(field,strand);
}
void fragment(){
	// Blend two world projections instead of switching UV axes on a folded face.
	float across=abs(world_normal.x)/(abs(world_normal.x)+abs(world_normal.z)+.0001);
	vec3 field=mix(flow_at(world_position.xy),flow_at(world_position.zy),across);
	vec3 color=mix(vec3(.045,.40,.69),vec3(.22,.66,.84),field.y*.70);
	color=mix(color,vec3(.70,.92,.98),field.z*.55+field.x*.19);
	ALBEDO=color;
	EMISSION=color*.10;
	ALPHA=clamp(.74+field.y*.14+field.z*.12+field.x*.08,.74,.97);
	ROUGHNESS=.46;
	SPECULAR=.30;
}
