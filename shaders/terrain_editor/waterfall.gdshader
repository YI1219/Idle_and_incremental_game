shader_type spatial;
render_mode blend_mix,depth_draw_never,cull_disabled,shadows_disabled;
varying vec3 world_position;
varying vec3 world_normal;
void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
vec3 flow_at(vec2 coordinates){
	// World-space features advect downward as Y+TIME increases. No polygon web.
	vec2 flow=coordinates*vec2(4.4,1.7)+vec2(0.0,TIME*1.25);
	float broad=.5+.5*sin(flow.x*.83+sin(flow.y*.31)*.28);
	float ribbon=pow(.5+.5*sin(flow.x*3.1+sin(flow.y*.55)*.30),8.0);
	ribbon*=.55+.45*(.5+.5*sin(flow.y*2.2+flow.x*.7));
	float fine=pow(.5+.5*sin(flow.x*8.3+sin(flow.y*1.3)*.22),12.0);
	fine*=.5+.5*sin(flow.y*3.7-flow.x);
	return vec3(fine,broad,ribbon);
}
void fragment(){
	// Blend two world projections instead of switching UV axes on a folded face.
	float across=abs(world_normal.x)/(abs(world_normal.x)+abs(world_normal.z)+.0001);
	vec3 field=mix(flow_at(world_position.xy),flow_at(world_position.zy),across);
	vec3 color=mix(vec3(.035,.40,.59),vec3(.10,.61,.76),field.y*.70);
	color=mix(color,vec3(.78,.93,.97),clamp(field.z*.78+field.x*.30,0.0,1.0));
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
	EMISSION=vec3(0.0);
	ALPHA=clamp(.80+field.y*.10+field.z*.09+field.x*.05,.80,.97)*side;
	ROUGHNESS=.46;
	SPECULAR=.30;
}
