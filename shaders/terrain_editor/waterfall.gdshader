shader_type spatial;
#include "terrain_morph.gdshaderinc"
render_mode blend_mix,depth_draw_never,cull_disabled,shadows_disabled;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// Convert approximate metre-scale displacement to projected UV at this fragment.
uniform float refraction_strength : hint_range(0.0,.15) = .045;
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
	float fine = strands(vec2(across*13.0,(y+TIME*2.9)*1.1)+vec2(3.1,17.0));
	// Falling packets: denser white clumps travel down the curtain.
	float packets = flow_noise(vec2(across*2.6,(y+TIME*3.1)*1.9)+vec2(5.0,1.0));
	// Aerated strands retain blue-green grooves under frontal sunlight;
	// foam stays below clipping so the moving sheet remains readable.
	float base_air = mix(.09,.48,smoothstep(.05,.80,drop));
	float air = base_air+(body-.5)*.95+(fine-.5)*.35+(packets-.5)*.40*accelerate+landing*.15;
	float white = smoothstep(.25,.60,air)*(.28+.72*smoothstep(.30,.70,packets));
	vec3 water = mix(vec3(.05,.18,.21),vec3(.20,.38,.39),body);
	// A glassy band follows the lip before the stream breaks up.
	float lip = 1.0-smoothstep(.02,.32,drop);
	water = mix(water,vec3(.20,.43,.44),lip*smoothstep(.45,.75,fine)*.30);
	vec3 foam = mix(vec3(.39,.54,.53),vec3(.65,.72,.68),smoothstep(.3,.8,body*.7+fine*.3));
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
	// Denser strands reduce backdrop contrast; clearer channels retain some
	// transmission. Background rock/sky transitions can still remain visible.
	float opacity = mix(mix(.68,.86,body),.94,white);
 opacity *= mix(1.0,.55+.45*body,landing);
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
	if(abs(determinant)>.00000001) NORMAL = normalize(abs(determinant)*NORMAL-gradient*.008);
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
	// Translucent streams bend the opaque background locally instead of
 // laying another flat tinted sheet over it. Current-screen approximation:
 // no off-screen/transparent refraction. Reject a displaced foreground hit.
 vec2 sample_uv=SCREEN_UV;
 if(refraction_strength>0.0){
  float projection_divisor=max(abs((PROJECTION_MATRIX*vec4(VERTEX,1.0)).w),.5);
  vec2 bend=vec2(body-.5,(fine-.5)*.35)*refraction_strength*vec2(PROJECTION_MATRIX[0][0],PROJECTION_MATRIX[1][1])*.5/projection_divisor;
  vec2 bent_uv=clamp(SCREEN_UV+bend,vec2(.001),vec2(.999));
  float depth=texture(depth_texture,bent_uv).r;
  vec4 behind_view=INV_PROJECTION_MATRIX*vec4(bent_uv*2.0-1.0,depth,1.0);
  if(depth<.00001 || behind_view.z/behind_view.w<VERTEX.z-.01)sample_uv=bent_uv;
 }
 vec3 behind=texture(screen_texture,sample_uv).rgb*vec3(.80,.94,.96);
 float transmission=.28*(1.0-white);
 ALBEDO=color*(1.0-transmission);
 EMISSION=behind*transmission+vec3(.025,.035,.04)*white+color*.025;
	ALPHA = opacity*side;
	if(COLOR.a<.001) ALPHA*=1.0-smoothstep(3.2,5.5,drop+(body-.5)*1.2);
	ROUGHNESS = mix(.30,.68,white);
	SPECULAR = mix(.18,.06,white);
}
