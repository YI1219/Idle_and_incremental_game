shader_type spatial;
#include "terrain_morph.gdshaderinc"
render_mode blend_mix,depth_draw_never,cull_disabled,shadows_disabled;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// Convert approximate metre-scale displacement to projected UV at this fragment.
uniform float refraction_strength : hint_range(0.0,.15) = .045;
uniform float flow_time = -1.0;
uniform vec3 sun_direction = vec3(.56,.43,.71);
// Same field as stone_root_veil in stone_surface.gdshaderinc: an outer fall
// thins into the cloud-sea mist together with the rock behind it.
uniform float root_veil_strength : hint_range(0.0,1.0) = 1.0;
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

float fall_veil(vec3 p){
	float wave=sin(p.x*.14+p.z*.12)*.42+cos(p.x*.25-p.z*.19)*.18;
	float t=clamp((-2.5+wave-p.y)/3.2,0.0,1.0);
	float v=t*t*(3.0-2.0*t);
	return root_veil_strength*v*(.38+.62*v);
}

// Water leaves the lip as one glassy sheet and gravity pulls it apart on the
// way down. 0 at the lip, 1 where the sheet has become separate ropes; a
// stronger flow holds together longer.
float fall_loosen(float drop,float intensity){
	return smoothstep(.10,mix(1.1,2.3,intensity),drop);
}

void vertex() {
	float time=flow_time<0.0?TIME:flow_time;
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	// A slow billow travels down the loosened sheet, so neither its face nor
	// its outline stands still. The lip rows stay put and keep their joins.
	float drop=max(UV.y,0.0);
	float loosen=fall_loosen(drop,clamp(UV.x,0.0,1.0));
	float billow=sin(world_position.x*2.3+world_position.z*1.9+drop*2.6-time*2.2)
		+sin(world_position.x*5.1-world_position.z*4.3+drop*4.3-time*3.1)*.6;
	VERTEX+=NORMAL*(billow*.022*loosen);
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
	float loosen=fall_loosen(drop,intensity);
	// The pattern is laid along sqrt(drop): it creeps over the lip, then
	// stretches and speeds up as it falls, as falling water does.
	float speed=mix(.95,2.4,intensity);
	float run=sqrt(drop+.05)*3.1-time*speed*.75;
	// Ropes lean a little from side to side on the way down.
	float lane=across+(sin(run*.9+across*2.1)*.040+sin(run*2.3-across*5.7)*.014)*loosen;
	vec2 group_uv=vec2(lane*5.3,run*.42);
	float groups=flow_noise(group_uv)*.62+flow_noise(group_uv*vec2(2.03,1.31)+vec2(7.1,3.3))*.38;
	vec2 fine_uv=vec2(lane*15.0,run*1.4)+vec2(8.1,3.7);
	float fine=flow_noise(fine_uv)*.60+flow_noise(fine_uv*vec2(2.1,1.6)+vec2(1.7,9.2))*.40;
	float packets=flow_noise(vec2(across*7.0,run*2.0+11.0));
	// White water: fine threads on the glassy sheet, gathering into ropes below.
	float thread=smoothstep(.50,.72,fine)*(.30+.70*smoothstep(.30,.62,groups));
	float rope=smoothstep(mix(.64,.42,loosen),mix(.82,.66,loosen),groups*.62+fine*.38)*smoothstep(.30,.62,packets);
	float white=clamp(thread*mix(.28,.50,loosen)+rope*mix(.20,.78,loosen),0.0,1.0);
	float impact=free_fall?0.0:smoothstep(.84,1.0,COLOR.a/.4);
	// A bright roll where the sheet bends over the lip.
	float lip=(1.0-smoothstep(.02,.16,drop))*.16;
	float veil=free_fall?fall_veil(world_position):0.0;
	float foam=clamp(white+impact*(.35+.45*fine)+lip+veil*.6,0.0,.92);
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
	// Pond jade at the lip, lightening to a misty celadon as air gets in.
	vec3 jade=mix(vec3(.045,.175,.164),vec3(.14,.32,.285),groups*.42+sun_bevel*.08);
	jade=mix(jade,vec3(.27,.47,.43),loosen*.50);
	vec3 water_color=mix(jade,vec3(.78,.88,.84),foam);
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
	// The unbroken sheet near the lip is the clearest part of the fall.
	float transmission=mix(mix(.24,.12,intensity),mix(.12,.065,intensity),loosen)*(1.0-foam);
	ALBEDO=water_color*(1.0-transmission);
	EMISSION=behind*transmission+water_color*.025;
	float run_width=1.0/max(inverse_width,.0001);
	float side=1.0;
	if(connected){
		// Metres from the nearer edge. Ropes peel away from the outline as the
		// sheet loosens, so the fall is never a ruled rectangle.
		float edge=min(COLOR.r,1.0-COLOR.r)*run_width;
		float fray=((groups-.5)*mix(.03,.36,loosen)+(fine-.5)*.06*loosen)*clamp(run_width*.6,.3,1.0);
		float softness=max(fwidth(edge)*1.25,mix(.022,.085,loosen));
		side=smoothstep(0.0,softness,edge+min(fray,0.0)-.012*loosen);
	}
	// Between the ropes the loosened sheet thins, and wet rock shows through.
	float body=mix(1.0,mix(.34,1.0,smoothstep(.26,.60,groups*.50+fine*.30+white*.55)),loosen*.85);
	ALPHA=mix(.82,.95,sqrt(intensity))*side*body*smoothstep(0.0,.12,intensity);
	if(free_fall){
		float tail=progress+(groups-.5)*.07;
		ALPHA*=(1.0-smoothstep(.76,.985,tail))*(1.0-smoothstep(.93,.99,progress));
		ALPHA*=1.0-smoothstep(.30,.94,veil+(groups-.5)*.18);
	}
	ROUGHNESS=mix(.30,.58,foam);
	SPECULAR=.14;
}
