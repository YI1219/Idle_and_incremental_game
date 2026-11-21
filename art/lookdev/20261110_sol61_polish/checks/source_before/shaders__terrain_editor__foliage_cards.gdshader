shader_type spatial;
render_mode cull_disabled, alpha_to_coverage;
#include "terrain_morph.gdshaderinc"
// Sculpted Multi-Bouquet Botanical Gouache Foliage (层叠苍翠叶团 · 幽深叶隙 · 暖玉透光外缘):
// Linear RGBA atlas: R = multi-rosette leaf-cluster brush value, GB = 3D mini-bouquet dome normal,
// A = velvety opaque core + delicate feathered leaflets / Oriental pine-needle fans on the rim.
uniform sampler2D leaf_atlas : filter_linear_mipmap, repeat_disable;
uniform vec3 leaf_shadow : source_color = vec3(.07,.15,.11);
uniform vec3 leaf_mid : source_color = vec3(.20,.31,.19);
uniform vec3 leaf_lit : source_color = vec3(.43,.53,.34);
uniform float sway_strength = .065;
uniform float flutter = .014;
uniform float rim_strength = 1.0;
varying vec3 world_n;
varying vec3 v_world_pos;
varying float card_value;
varying float card_height;
varying float card_ao;
void vertex(){
	card_value=COLOR.r;
	card_height=COLOR.g;
	card_ao=COLOR.b>.01?COLOR.b:1.0;
	vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	float ph=dot(origin.xz,vec2(.31,.17));
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	v_world_pos=world;
	float h=card_height*card_height;
	vec3 sway=vec3(sin(TIME*1.05+ph)+.35*sin(TIME*2.3+ph*2.0),0.0,.6*cos(TIME*.83+ph*1.3))*sway_strength*h;
	vec3 flut=vec3(sin(TIME*4.1+dot(world,vec3(3.1,2.3,1.7))),sin(TIME*3.3+dot(world,vec3(1.3,2.9,2.1)))*.6,cos(TIME*3.7+dot(world,vec3(2.2,1.1,3.3))))*flutter*card_height;
	VERTEX+=(inverse(MODEL_MATRIX)*vec4(sway+flut,0.0)).xyz;
	world_n=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	if(terrain_morph_progress<1.0){VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(origin),0.0,0.0)).xyz;}
}
void fragment(){
	vec4 tex=texture(leaf_atlas,UV);
	vec3 n=normalize(world_n);
	vec3 up_ref=abs(n.y)<.96?vec3(0.0,1.0,0.0):vec3(1.0,0.0,0.0);
	vec3 tang_x=normalize(cross(up_ref,n));
	vec3 tang_y=normalize(cross(n,tang_x));
	vec2 puff_xy=(tex.gb-vec2(128.0/255.0))*2.0;
	vec3 puff_n=normalize(n+(tang_x*puff_xy.x+tang_y*puff_xy.y)*.52);

	// Consistent 3D dome pigment across ALL cloud tiers (every pad has rich shaded left belly & lit sunward crest!):
	float dome_orient=puff_n.y*.62+puff_n.x*.38;
	float sky_t=clamp(.06+card_height*.12+smoothstep(-.58,.86,dome_orient)*.44+(card_ao-.36)*.46,0.0,1.0)*card_value;
	vec3 col=sky_t<.52?mix(leaf_shadow,leaf_mid,sky_t/.52):mix(leaf_mid,leaf_lit,(sky_t-.52)/.48);
	// Tactile multi-rosette leaf-cluster gouache brushwork (perimeter neutral = 146/255 -> ~1.00):
	col*=mix(.80,1.20,smoothstep(.40,.72,tex.r));
	// Gentle sunward morning-mist touch ONLY on sun-facing outer foliage of the right tree (Ref 1):
	float mist_bloom=smoothstep(4.0,18.0,v_world_pos.x)*smoothstep(0.0,.70,puff_n.x)*smoothstep(.40,.95,card_ao);
	col=mix(col,leaf_lit*vec3(1.16,1.10,.95),mist_bloom*.10);
	ALBEDO=col;
	ALPHA=tex.a;
	ALPHA_SCISSOR_THRESHOLD=.23;
	ALPHA_ANTIALIASING_EDGE=.27;

	NORMAL=normalize((VIEW_MATRIX*vec4(puff_n,0.0)).xyz);
	AO=card_ao;
	AO_LIGHT_AFFECT=.68;
	ROUGHNESS=.94;
	SPECULAR=.01;
}
void light(){
	vec3 lc=LIGHT_COLOR/PI;
	float l_peak=max(lc.r,max(lc.g,lc.b));
	float ndl=dot(NORMAL,LIGHT);
	// Secondary FillLight: soft cool sky-dome lift on shaded canopy bellies without washing out inner AO crevices:
	if(LIGHT_IS_DIRECTIONAL && l_peak<.45){
		float sky_fill=(.28+.72*clamp(.50+.50*ndl,0.0,1.0))*mix(.45,1.0,card_ao);
		DIFFUSE_LIGHT+=(vec3(.80,.94,1.06)*(.34*sky_fill))*lc;
	}else{
		// Rich 3D sub-bouquet shading (Tiny Glade / Europa high-luminosity canopy contrast):
		float half_lambert=smoothstep(-.26,.54,ndl);
		float translucency=mix(.18,1.0,ATTENUATION);
		float direct_t=clamp(smoothstep(-.02,.44,ndl)*mix(.10,1.0,ATTENUATION),0.0,1.0);
		vec3 temp_tint=mix(vec3(.70,.88,1.08),vec3(1.13,1.06,.88),direct_t);
		float lit=mix(.06,.92,half_lambert*translucency);
		// Crisp sunlit creamy-tea rim & backlit leaflet translucency ONLY on sunlit outer sprigs:
		float view_rim=pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),1.58);
		float back_scatter=pow(clamp(dot(-LIGHT,VIEW),0.0,1.0),2.0)*ATTENUATION;
		float sun_kiss=smoothstep(.05,.62,ndl)*ATTENUATION;
		vec3 warm_rim=vec3(1.56,1.42,.96)*(view_rim*sun_kiss*.62+back_scatter*.36)*smoothstep(.36,.94,card_ao)*rim_strength;
		DIFFUSE_LIGHT+=(temp_tint*lit+warm_rim)*lc;
	}
}
