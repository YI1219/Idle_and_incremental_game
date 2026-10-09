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

// Stretched along the fall: strands are long and narrow, never a regular comb.
float strands(vec2 p) {
	return flow_noise(p)*.55+flow_noise(p*vec2(2.03,1.97)+vec2(7.1,3.3))*.30+flow_noise(p*vec2(4.1,3.9)+vec2(1.7,9.2))*.15;
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
	float drop = COLOR.g*16.0;
	float receiver = COLOR.a<.5 ? COLOR.a : (COLOR.b<.001 ? COLOR.r : 0.0);
	float landing = smoothstep(.52,1.0,receiver/.4);
	// Two constant-speed layers: a slower glassy sheet over the lip and a
	// faster broken fall below. Blending by drop avoids shearing over time.
	float y = world_position.y;
	float accelerate = smoothstep(.15,1.6,drop);
	vec2 slow = vec2(across*7.0,(y+TIME*1.25)*.55);
	vec2 fast = vec2(across*13.0,(y+TIME*2.6)*.38);
	float sheet = strands(slow);
	float torrent = strands(fast+vec2(13.7,0.0));
	float body = mix(sheet,torrent,accelerate);
	float fine = strands(vec2(across*26.0,(y+TIME*2.9)*1.1)+vec2(3.1,17.0));
	// Falling packets: denser white clumps travel down the curtain.
	float packets = flow_noise(vec2(across*2.6,(y+TIME*3.1)*1.9)+vec2(5.0,1.0));
	// Water aerates within the first metre and is mostly white below.
	float base_air = mix(.16,.86,smoothstep(.05,1.5,drop));
	float air = base_air+(body-.5)*1.15+(fine-.5)*.55+(packets-.5)*.45*accelerate+landing*.55;
	float white = smoothstep(.38,.78,air);
	vec3 water = mix(vec3(.36,.52,.57),vec3(.58,.71,.74),body);
	// A glassy band follows the lip before the stream breaks up.
	float lip = 1.0-smoothstep(.02,.32,drop);
	water = mix(water,vec3(.66,.78,.78),lip*smoothstep(.45,.75,fine)*.55);
	vec3 color = mix(water,vec3(.93,.95,.93),white);
	float side = 1.0;
	if (COLOR.a<.5) {
		float edge = min(COLOR.r,1.0-COLOR.r);
		// Ragged, thinning edges that widen as the stream falls.
		float ragged = (fine-.5)*.16+(body-.5)*.12;
		float inset = clamp((.018+min(drop,5.0)*.040+ragged)*inverse_width,0.0,.24);
		float softness = min(max(.05*inverse_width,fwidth(edge)*1.5),.14);
		side = smoothstep(inset,inset+max(softness,.0001),edge);
	}
	// Thin water between strands lets the rock behind read through.
	float opacity = mix(mix(.74,.90,body),.97,white);
	opacity *= mix(1.0,smoothstep(.10,.42,air),accelerate*.35);
	// Grooves follow the strands; screen derivatives reconstruct the same
	// world-space gradient for every camera.
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 r1 = cross(dy,NORMAL);
	vec3 r2 = cross(NORMAL,dx);
	float determinant = dot(dx,r1);
	float relief = body*.6+fine*.4;
	vec3 gradient = sign(determinant)*(dFdx(relief)*r1+dFdy(relief)*r2);
	if(abs(determinant)>.00000001) NORMAL = normalize(abs(determinant)*NORMAL-gradient*.035);
	ALBEDO = color;
	// Aerated water scatters light, so white strands stay bright in shade.
	EMISSION = vec3(.16,.18,.18)*white+color*.12;
	ALPHA = opacity*side;
	if(COLOR.a<.001) ALPHA*=1.0-smoothstep(3.2,5.5,drop+(body-.5)*1.2);
	ROUGHNESS = mix(.22,.65,white);
	SPECULAR = mix(.35,.08,white);
}
