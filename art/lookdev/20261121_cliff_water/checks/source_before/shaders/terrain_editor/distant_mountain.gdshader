shader_type spatial;
render_mode unshaded,shadows_disabled,fog_disabled;
#include "sky_palette.gdshaderinc"
// Song-dynasty Qinglü & Ink-Wash Distant Mountains (远山如黛 · 螺青叠翠 · 上实下虚):
// Crisp mineral celadon-indigo ridgelines & sunlit spur facets above, dissolving
// seamlessly into drifting Xuan-silk cloud valleys below.
uniform vec3 sun_direction = vec3(.58,.44,-.68);
uniform float aerial_density = .00085;
uniform vec3 mountain_dark : source_color = vec3(.42,.53,.58);
uniform vec3 mountain_light : source_color = vec3(.80,.79,.70);
varying vec3 world_position;
varying vec3 world_normal;
varying float height;
varying float spine_closeness;

float m_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float m_noise(vec2 p){
	vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(m_hash(i),m_hash(i+vec2(1,0)),u.x),mix(m_hash(i+vec2(0,1)),m_hash(i+vec2(1,1)),u.x),u.y);
}

void vertex(){
	height=VERTEX.y;
	spine_closeness=COLOR.r;
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment(){
	vec3 normal=normalize(world_normal);
	vec3 sun_d=normalize(sun_direction);
	// Sculpted 3D Song-Shanshui ridgeline lighting (Europa / Journey / Qianli Jiangshan Tu):
	// Crisp sunlit warm jade-ochre slopes vs cool mineral celadon-indigo sky-shaded faces!
	float ndl=dot(normal,sun_d);
	float ridge_split=smoothstep(-.16,.28,ndl);
	float soft_wrap=smoothstep(-.72,.84,ndl);
	float light=mix(.20,.88,ridge_split*.68+soft_wrap*.32);

	float brush=m_noise(vec2(world_position.x*.016+world_position.z*.014,world_position.y*.055));
	float cun_mod=.95+.10*brush;

	vec3 shade_indigo=mountain_dark*vec3(.86,.99,1.08);
	vec3 mid_celadon=mix(mountain_dark,mountain_light,.54)*vec3(.94,1.02,1.01);
	vec3 lit_jade_ochre=mix(mountain_light,sky_sun_glow,.28)*vec3(1.06,1.02,.93);
	vec3 stone=light<.5 ? mix(shade_indigo,mid_celadon,light*2.0) : mix(mid_celadon,lit_jade_ochre,(light-.5)*2.0);
	stone*=cun_mod;

	// Sun-kissed mineral crest highlight along upper spines + gentle upper-crest condensation (上实下虚):
	float crest=smoothstep(.24,.88,height)*(.45+.55*spine_closeness);
	float crest_gleam=pow(spine_closeness,2.4)*smoothstep(-.05,.45,ndl)*smoothstep(.32,.90,height);
	stone=mix(stone*mix(1.03,.88,crest),lit_jade_ochre*1.12,crest_gleam*.34);

	vec3 view=world_position-CAMERA_POSITION_WORLD;
	float distance=max(length(view),.001);
	vec3 factors=sky_view_factors(view/distance);
	float h_sun=factors.z;

	float day_t=smoothstep(.35,.80,sky_horizon.r);
	float day_hdr=mix(1.0,mix(1.14,1.44,h_sun),day_t);
	stone=mix(stone*vec3(.92,1.00,1.04),mix(stone,sky_sun_glow,.42),h_sun*.72)*day_hdr;

	// Layered atmospheric depth keeping 3D ridge facets clearly legible across all 3 mountain rings:
	vec3 bg_sky=sky_gradient_factors(factors);
	float aerial=.12+.26*(1.0-exp(-max(distance-310.0,0.0)*aerial_density*1.05));
	aerial=mix(aerial,.44,h_sun*.24);

	float mist_wave=.06*(m_noise(world_position.xz*.0042)-.5);
	float base_mist=1.0-smoothstep(.13+mist_wave,.46+mist_wave,height);

	vec3 col=mix(stone,bg_sky,clamp(aerial,0.0,.50));
	col=mix(col,bg_sky,clamp(base_mist*.97,0.0,.99));
	col=mix(col,SKY_SUN_CORE,sky_disc_from_distance(factors.y)*.35);
	ALBEDO=col;
}
