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
	float receiver = COLOR.a<.5 ? COLOR.a : (COLOR.b<.001 ? COLOR.r : 0.0);
	float landing = smoothstep(.52,1.0,receiver/.4);
	float drop = COLOR.g*16.0;
	float turn = smoothstep(.12,.65,drop);
	float strand = flow_noise(vec2(flow.x*13.0+bend*.65,flow.y*.65));
	float streak = smoothstep(.36,.67,strand)*smoothstep(.14,.48,lifetime);
	float filament=pow(.5+.5*sin(across*42.0+bend*.9),12.0);
	streak=max(streak*.65,filament*(.5+.5*lifetime));
	float aeration = clamp(.30+streak*mix(.45,.75,turn)+landing*(.50+.25*body),0.0,1.0);
	vec3 color = mix(vec3(.22,.39,.46),vec3(.41,.59,.63),body*.7);
	color = mix(color,vec3(.88,.91,.84),aeration);
	float side = 1.0;
	if (COLOR.a<.5) {
		float edge = min(COLOR.r,1.0-COLOR.r);
		float irregular = (body-.5)*.10;
		float inset = clamp((.018+min(drop,5.0)*.036+irregular)*inverse_width,0.0,.20);
		float softness = min(max(.035*inverse_width,fwidth(edge)*1.5),.12);
		side = smoothstep(inset,inset+max(softness,.0001),edge);
	}
	float opacity = .99;
	// The existing light/sky response follows moving shallow surface folds.
	// Screen derivatives reconstruct the same world-space height gradient
	// for every inspection camera; this is not a painted highlight.
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy,NORMAL);
	vec3 r2 = cross(NORMAL,dx);
	float determinant = dot(dx,r1);
	vec3 gradient = sign(determinant)*(dFdx(body)*r1+dFdy(body)*r2);
	if(abs(determinant)>.00000001) NORMAL = normalize(abs(determinant)*NORMAL-gradient*.055);
	ALBEDO = color;
	// Restrained local fill approximates light scattered inside terminal froth.
	EMISSION = color*.12+vec3(.11,.13,.13)*aeration;
	ALPHA = opacity*side;
	if(COLOR.a<.001) ALPHA*=1.0-smoothstep(3.2,5.5,drop);
	ROUGHNESS = .65;
	SPECULAR = .10;
}
