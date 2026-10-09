shader_type spatial;
#include "terrain_morph.gdshaderinc"
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
	VERTEX.y += terrain_morph_offset(world_position);
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
	// A thick aerated body: only the lip is glassy; within a metre the fall
	// is dense white water with soft grey-blue shading in the grooves.
	float base_air = mix(.22,1.05,smoothstep(.05,.80,drop));
	float air = base_air+(body-.5)*.95+(fine-.5)*.35+(packets-.5)*.40*accelerate+landing*.55;
	float white = smoothstep(.30,.70,air);
	vec3 water = mix(vec3(.50,.64,.68),vec3(.72,.81,.83),body);
	// A glassy band follows the lip before the stream breaks up.
	float lip = 1.0-smoothstep(.02,.32,drop);
	water = mix(water,vec3(.72,.82,.82),lip*smoothstep(.45,.75,fine)*.55);
	vec3 foam = mix(vec3(.86,.89,.89),vec3(.97,.98,.96),smoothstep(.3,.8,body*.7+fine*.3));
	vec3 color = mix(water,foam,white);
	float side = 1.0;
	float edge = .5;
	if (COLOR.a<.5) {
		edge = min(COLOR.r,1.0-COLOR.r);
		// Ragged edges widen as the stream falls and feather into the spray veil.
		float ragged = (fine-.5)*.16+(body-.5)*.14;
		float inset = clamp((.012+min(drop,5.0)*.030+ragged)*inverse_width,0.0,.20);
		float softness = min(max((.10+min(drop,4.0)*.06)*inverse_width,fwidth(edge)*1.5),.22);
		side = smoothstep(inset,inset+max(softness,.0001),edge);
	}
	// The core is nearly opaque below the lip, so a change of backdrop (rock
	// ending above open sky) no longer shows through as a seam.
	float opacity = mix(mix(.76,.92,body),.985,white);
	opacity *= mix(1.0,smoothstep(.0,.30,air),accelerate*.12);
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
	// Rounded cross-section: normals wrap toward each side so the body shades
	// as a thick column of water rather than a flat sheet.
	if (COLOR.a<.5 && abs(determinant)>.00000001) {
		vec3 across_gradient = sign(determinant)*(dFdx(COLOR.r)*r1+dFdy(COLOR.r)*r2);
		if (length(across_gradient)>.0000001) {
			vec3 side_direction = normalize(across_gradient);
			float wrap = (COLOR.r-.5)*2.0;
			NORMAL = normalize(NORMAL*sqrt(max(.0,1.0-wrap*wrap*.55))+side_direction*wrap*.75);
		}
	}
	ALBEDO = color;
	// Aerated water scatters light, so white water stays bright in shade.
	EMISSION = vec3(.30,.31,.31)*white+color*.16;
	ALPHA = opacity*side;
	if(COLOR.a<.001) ALPHA*=1.0-smoothstep(3.2,5.5,drop+(body-.5)*1.2);
	ROUGHNESS = mix(.22,.65,white);
	SPECULAR = mix(.35,.08,white);
}
