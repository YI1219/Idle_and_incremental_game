shader_type spatial;
render_mode blend_mix,depth_draw_never,cull_disabled,shadows_disabled;
varying vec3 world_position;

float hash_flow(vec2 p) {
	vec3 q = fract(vec3(p.xyx)*.1031);
	q += dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}

float flow_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 blend = f*f*(3.0-2.0*f);
	float a = hash_flow(cell);
	float b = hash_flow(cell+vec2(1.0,0.0));
	float c = hash_flow(cell+vec2(0.0,1.0));
	float d = hash_flow(cell+vec2(1.0,1.0));
	return mix(mix(a,b,blend.x),mix(c,d,blend.x),blend.y);
}

void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	float inverse_width = COLOR.b/max(1.0-COLOR.b,.0001);
	// Connected-run coordinates survive chunk clipping and curved outlets.
	// White metadata from legacy/closed rings keeps a continuous world fallback.
	float across = dot(world_position.xz,vec2(.80,.60));
	if (COLOR.a<.5) {
		across = COLOR.r/max(inverse_width,.0001);
	}
	vec2 coordinates = vec2(across,world_position.y);
	// A single downward flow coordinate keeps the strand envelope and its
	// finer aeration moving together, instead of sliding peaks past one another.
	vec2 flow = coordinates+vec2(0.0,TIME*1.45);
	float body = flow_noise(flow*vec2(2.4,.65));
	float lifetime = flow_noise(flow*vec2(3.1,1.8)+vec2(11.3,7.8));
	float bend = flow_noise(flow*vec2(1.7,1.15)+vec2(29.1,3.2))-.5;
	// Narrow contours, rather than broad maxima, form irregular connected
	// downflow. Strong anisotropy gives them length; the envelope varies their
	// width and lifetime without a repeating across-stream sine lattice.
	float strand_field = flow_noise(vec2(flow.x*13.5+bend*1.2,flow.y*.48)+vec2(7.3,19.1));
	float envelope = smoothstep(.24,.68,lifetime);
	float width = mix(.030,.085,envelope);
	float strand_softness = max(.045,fwidth(strand_field)*.7);
	float strand = 1.0-smoothstep(width,width+strand_softness,abs(strand_field-.5));
	// Low aeration actually ends a bright strand; a nonzero envelope floor
	// would preserve full-height white filaments and read as striped fabric.
	strand *= envelope;
	float fine_field = flow_noise(vec2(flow.x*25.0-bend*.7,flow.y*.86)+vec2(31.4,5.6));
	float thread_softness = max(.045,fwidth(fine_field)*.7);
	float thread = 1.0-smoothstep(.018,.018+thread_softness,abs(fine_field-.5));
	float fine_visibility = 1.0-smoothstep(.018,.060,fwidth(flow.x));
	thread *= smoothstep(.35,.75,lifetime)*fine_visibility;
	// Broad, finite patches interrupt fine filaments. A wet receiver alone
	// increases aeration through the last part of the fall, joining its foam.
	float receiver = COLOR.a<.5 ? COLOR.a : (COLOR.b<.001 ? COLOR.r : 0.0);
	float landing = smoothstep(.60,1.0,receiver/.4);
	float patches = smoothstep(.36,.76,body)*smoothstep(.25,.70,lifetime);
	float aeration = clamp(strand*.28+thread*.08+patches*.35+landing*(.30+.28*body),0.0,.84);
	vec3 color = mix(vec3(.050,.40,.58),vec3(.15,.61,.74),body*.55);
	color = mix(color,vec3(.78,.93,.97),aeration);
	float side = 1.0;
	if (COLOR.a<.5) {
		float edge = min(COLOR.r,1.0-COLOR.r);
		float drop = COLOR.g*16.0;
		float irregular = (body-.5)*.065;
		float inset = clamp((.025+min(drop,5.0)*.028+irregular)*inverse_width,0.0,.20);
		float softness = min(max(.055*inverse_width,fwidth(edge)*1.5),.12);
		side = smoothstep(inset,inset+max(softness,.0001),edge);
	}
	ALBEDO = color;
	EMISSION = vec3(0.0);
	ALPHA = clamp(.80+body*.06+aeration*.12,.80,.97)*side;
	ROUGHNESS = .46;
	SPECULAR = .30;
}
