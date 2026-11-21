shader_type spatial;
#include "terrain_morph.gdshaderinc"
render_mode blend_mix,depth_draw_never,cull_disabled,shadows_disabled;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// Convert approximate metre-scale displacement to projected UV at this fragment.
uniform float refraction_strength : hint_range(0.0,.15) = .045;
uniform float flow_time = -1.0;
uniform vec3 sun_direction = vec3(.56,.43,.71);
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
	if(!terrain_transition_visible(FRAGCOORD.xy))discard;
	float time=flow_time<0.0?TIME:flow_time;
	float intensity=clamp(UV.x,0.0,1.0);
	float drop=max(UV.y,0.0);
	float inverse_width=COLOR.b/max(1.0-COLOR.b,.0001);
	bool connected=COLOR.b>.001;
	bool free_fall=COLOR.a>=.495 && COLOR.a<.995;
	float progress=free_fall?clamp((COLOR.a-.5)/.49,0.0,1.0):0.0;
	float across=connected?COLOR.r/max(inverse_width,.0001):dot(world_position.xz,vec2(.80,.60));
	float speed=mix(.95,2.4,intensity);
	vec2 flow_uv=vec2(across*5.3,(world_position.y+time*speed)*.28);
	float groups=strands(flow_uv);
	float fine=strands(vec2(across*24.0,(world_position.y+time*speed*1.2)*1.8)+vec2(8.1,3.7));
	float packets=flow_noise(vec2(across*8.0,(world_position.y+time*speed)*2.3));
	float reflection=smoothstep(.42,.65,fine*.72+groups*.28)*smoothstep(.25,.58,packets);
	float threads=smoothstep(.45,.68,fine)*( .35+.65*smoothstep(.28,.60,groups));
	float impact=free_fall?0.0:smoothstep(.84,1.0,COLOR.a/.4);
	float lip=(1.0-smoothstep(.015,.12,drop))*.12;
	float foam=clamp(impact*(.32+.42*fine)+lip+reflection*.035,0.0,.76);
	float relief=groups*.65+fine*.35;
	vec3 dx=dFdx(VERTEX);
	vec3 dy=dFdy(VERTEX);
	vec3 r1=cross(dy,NORMAL);
	vec3 r2=cross(NORMAL,dx);
	float determinant=dot(dx,r1);
	if(abs(determinant)>.00000001){
		vec3 gradient=sign(determinant)*(dFdx(relief)*r1+dFdy(relief)*r2);
		NORMAL=normalize(abs(determinant)*NORMAL-gradient*.0025);
	}
	vec3 world_n=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
	float sun_bevel=clamp(dot(world_n,normalize(sun_direction))*.5+.5,0.0,1.0);
	vec3 jade=mix(vec3(.045,.175,.164),vec3(.14,.32,.285),groups*.42+sun_bevel*.08);
	jade=mix(jade,vec3(.42,.60,.53),reflection*.43+threads*.12*smoothstep(.32,.65,packets));
	vec3 water_color=mix(jade,vec3(.78,.86,.81),foam);
	vec2 sample_uv=SCREEN_UV;
	if(refraction_strength>0.0){
		float divisor=max(abs((PROJECTION_MATRIX*vec4(VERTEX,1.0)).w),.5);
		vec2 bend=vec2(groups-.5,(fine-.5)*.22)*refraction_strength*vec2(PROJECTION_MATRIX[0][0],PROJECTION_MATRIX[1][1])*.24/divisor;
		vec2 bent_uv=clamp(SCREEN_UV+bend,vec2(.001),vec2(.999));
		float depth=texture(depth_texture,bent_uv).r;
		vec4 behind_view=INV_PROJECTION_MATRIX*vec4(bent_uv*2.0-1.0,depth,1.0);
		if(depth<.00001 || behind_view.z/behind_view.w<VERTEX.z-.01)sample_uv=bent_uv;
	}
	vec3 behind=texture(screen_texture,sample_uv).rgb*vec3(.70,.90,.86);
	float transmission=mix(.12,.065,intensity)*(1.0-foam);
	ALBEDO=water_color*(1.0-transmission);
	EMISSION=behind*transmission+water_color*.025;
	float side=1.0;
	if(connected){
		float edge=min(COLOR.r,1.0-COLOR.r);
		float softness=max(fwidth(edge)*1.25,min(.023*inverse_width,.055));
		side=smoothstep(0.0,max(.0001,softness),edge);
	}
	ALPHA=mix(.82,.95,sqrt(intensity))*side*smoothstep(0.0,.12,intensity);
	if(free_fall){
		float tail=progress+(groups-.5)*.07;
		ALPHA*=(1.0-smoothstep(.76,.985,tail))*(1.0-smoothstep(.93,.99,progress));
	}
	ROUGHNESS=mix(.30,.58,foam);
	SPECULAR=.14;
}
