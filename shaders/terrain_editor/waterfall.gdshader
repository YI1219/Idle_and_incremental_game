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
	float strand=pow(.5+.5*sin(flow.x*3.1+sin(flow.y*.45)*.36),6.0);
	strand*=(.70+.30*sin(flow.x*.73+flow.y*.17))*(.70+.30*sin(flow.y*.8+flow.x*2.3));
	return vec3(field,strand);
}
void fragment(){
	// Blend two world projections instead of switching UV axes on a folded face.
	float across=abs(world_normal.x)/(abs(world_normal.x)+abs(world_normal.z)+.0001);
	vec3 field=mix(flow_at(world_position.xy),flow_at(world_position.zy),across);
	vec3 color=mix(vec3(.10,.60,.83),vec3(.36,.84,.96),field.y*.70);
	color=mix(color,vec3(.88,.98,1.0),clamp(field.z*.96+field.x*.22,0.0,1.0));
	float side=1.0;
	if(COLOR.a<.5){
		float edge=min(COLOR.r,1.0-COLOR.r);
		float inverse_width=COLOR.b/max(1.0-COLOR.b,.0001);
		float drop=COLOR.g*16.0;
		float irregular=sin(world_position.y*4.3+world_position.x*2.1+world_position.z*1.7+TIME*.6)*.022;
		float inset=clamp((.025+min(drop,5.0)*.028+irregular)*inverse_width,0.0,.20);
		float softness=min(max(.055*inverse_width,fwidth(edge)*1.5),.12);
		side=smoothstep(inset,inset+max(softness,.0001),edge);
	}
	ALBEDO=color;
	EMISSION=color*.18;
	ALPHA=clamp(.80+field.y*.10+field.z*.09+field.x*.05,.80,.97)*side;
	ROUGHNESS=.46;
	SPECULAR=.30;
}
