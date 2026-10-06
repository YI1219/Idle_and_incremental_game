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
	// Finite aerated seams move downward with broader flow pockets. Their
	// similar horizontal/vertical scale avoids full-height parallel filaments.
	vec2 foam_cell = vec2(flow.x*7.0+bend*.32,flow.y*3.0);
	vec2 cell = floor(foam_cell);
	vec2 f = fract(foam_cell);
	float nearest = 10.0;
	float second = 10.0;
	float seed = 0.0;
	for(int y=-1;y<=1;y++) for(int x=-1;x<=1;x++) {
		vec2 offset = vec2(float(x),float(y));
		vec2 anchor = vec2(hash_flow(cell+offset),hash_flow(cell+offset+vec2(17.2,43.8)));
		vec2 delta = offset+.15+anchor*.70-f;
		float distance = dot(delta,delta);
		if(distance<nearest) {second=nearest; nearest=distance; seed=anchor.x;}
		else if(distance<second) {second=distance;}
	}
	float line_width = max(.025,fwidth(second-nearest));
	float seam = 1.0-smoothstep(.025,.025+line_width,second-nearest);
	seam *= smoothstep(.46,.72,lifetime)*mix(.25,1.0,seed);
	float receiver = COLOR.a<.5 ? COLOR.a : (COLOR.b<.001 ? COLOR.r : 0.0);
	float landing = smoothstep(.52,1.0,receiver/.4);
	float drop = COLOR.g*16.0;
	float turn = smoothstep(.12,.65,drop);
	float bubbles = (1.0-smoothstep(.04,.18,nearest))*smoothstep(.54,.82,seed)*smoothstep(.25,.65,lifetime);
	float aeration = clamp(max(seam*mix(.18,.55,turn),bubbles*.55*turn)+landing*(.65+.35*body),0.0,1.0);
	vec3 color = mix(vec3(.060,.42,.58),vec3(.14,.58,.69),body*.7);
	color = mix(color,vec3(.86,.96,.97),aeration);
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
	EMISSION = vec3(.045,.065,.070)*aeration*landing;
	ALPHA = opacity*side;
	ROUGHNESS = .28;
	SPECULAR = .30;
}
