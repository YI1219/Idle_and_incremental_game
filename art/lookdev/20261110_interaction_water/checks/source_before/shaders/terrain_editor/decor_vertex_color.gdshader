shader_type spatial;
#include "terrain_morph.gdshaderinc"
// Soft Matte Gouache Vertex-Coloured Decoration & Painterly Ancient Bark (古木苍皮水粉肌理 · 苔团柔光 · 竹影).
uniform vec3 decor_sky_shadow : source_color = vec3(.86,.92,.96);
uniform vec3 decor_sky_lit : source_color = vec3(1.04,1.02,.96);
uniform bool linear_vertex_color = false;
uniform float sway_strength = 0.0;
uniform float lantern_glow_strength = 0.22;
uniform vec3 lantern_glow_color : source_color = vec3(1.0,.76,.40);
varying vec3 world_normal;
varying vec3 world_pos;
varying vec3 v_model_origin;
varying vec2 v_uv;
varying float v_is_bark;

float bark_hash(vec3 p){
	p=fract(p*vec3(.1031,.1030,.0973));
	p+=dot(p,p.yxz+33.33);
	return fract((p.x+p.y)*p.z);
}
float bark_noise(vec3 p){
	vec3 i=floor(p);vec3 f=fract(p);vec3 u=f*f*(3.0-2.0*f);
	return mix(
		mix(mix(bark_hash(i),bark_hash(i+vec3(1,0,0)),u.x),mix(bark_hash(i+vec3(0,1,0)),bark_hash(i+vec3(1,1,0)),u.x),u.y),
		mix(mix(bark_hash(i+vec3(0,0,1)),bark_hash(i+vec3(1,0,1)),u.x),mix(bark_hash(i+vec3(0,1,1)),bark_hash(i+vec3(1,1,1)),u.x),u.y),
		u.z
	);
}
float bark_grain_field(vec3 lp,float detail_w){
	float s_along=lp.y*1.25+length(lp.xz)*.55;
	vec2 p_twist=lp.xz+vec2(sin(s_along*1.25+lp.z*1.1),cos(s_along*1.05-lp.x*1.1))*.08;
	float macro_plate=bark_noise(vec3(p_twist*4.2,s_along*.82));
	float mid_plate=bark_noise(vec3(p_twist*9.6+vec2(4.1,7.3),s_along*1.75));
	float fissure=bark_noise(vec3(p_twist*20.0+vec2(9.2,2.7),s_along*3.4));
	return (macro_plate*.56+mid_plate*.44)*.76+fissure*.24*detail_w;
}

void vertex(){
	if(!linear_vertex_color){
		COLOR.rgb=mix(pow((COLOR.rgb+vec3(.055))*(1.0/1.055),vec3(2.4)),COLOR.rgb*(1.0/12.92),lessThan(COLOR.rgb,vec3(.04045)));
	}
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	v_model_origin=origin;
	world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	v_uv=UV;
	v_is_bark=(UV.y>.11 && UV.y<.18)?1.0:0.0;
	if(sway_strength>0.0){
		float ph=dot(origin.xz,vec2(.31,.17));
		float h=UV.x*UV.x;
		vec3 off=vec3(sin(TIME*1.05+ph)+.35*sin(TIME*2.3+ph*2.0),0.0,.6*cos(TIME*.83+ph*1.3))*sway_strength*h*(UV.y>.5?1.0:.45);
		VERTEX+=(inverse(MODEL_MATRIX)*vec4(off,0.0)).xyz;
	}
	if(terrain_morph_progress<1.0){
		VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(origin),0.0,0.0)).xyz;
	}
}
void fragment(){
	vec3 n_w=normalize(world_normal);
	float sky_wrap=smoothstep(-.65,.85,n_w.y);
	vec3 col=COLOR.rgb*mix(decor_sky_shadow,decor_sky_lit,sky_wrap);
	float ao_val=1.0;
	// Painterly gnarled ancient bark strips, sunlit ochre plates & mossy root crevices (Ref 1):
	if(v_is_bark>.5){
		vec3 lp=world_pos-v_model_origin;
		float detail_w=1.0-smoothstep(.035,.15,length(fwidth(world_pos)));
		float bark_h=bark_grain_field(lp,detail_w);
		float e_b=.018;
		float gx=(bark_grain_field(lp+vec3(e_b,0.0,0.0),detail_w)-bark_h)/e_b;
		float gz=(bark_grain_field(lp+vec3(0.0,0.0,e_b),detail_w)-bark_h)/e_b;
		vec3 grad_b=vec3(gx,0.0,gz);
		n_w=normalize(n_w-(grad_b-n_w*dot(n_w,grad_b))*(.085*mix(.65,1.0,detail_w)));

		float is_pine_bark=smoothstep(.14,.155,v_uv.y);
		float crevice_mask=1.0-smoothstep(.25,.50,bark_h);
		float ridge_mask=smoothstep(.50,.79,bark_h);
		vec3 bark_crevice=col*vec3(.42,.49,.58);
		vec3 bark_plate=col*vec3(.98,.99,.97);
		vec3 bark_ridge=col*mix(vec3(1.38,1.35,1.25),vec3(1.42,1.31,1.15),is_pine_bark);
		col=mix(bark_plate,bark_crevice,crevice_mask*.88);
		col=mix(col,bark_ridge,ridge_mask*.84);

		// Cool weathered celadon-lichen dapple on shaded bark + organic mossy root hollows:
		float lichen=smoothstep(.18,-.52,n_w.x)*smoothstep(.54,.82,bark_h);
		col=mix(col,vec3(.086,.122,.084),lichen*.34);
		float root_reach=.15+.11*crevice_mask;
		float root_moss=(1.0-smoothstep(.01,root_reach,v_uv.x));
		col=mix(col,mix(vec3(.048,.088,.034),vec3(.082,.128,.052),bark_h),root_moss*.64);
		ao_val=mix(1.0,.50,crevice_mask);
	}
	NORMAL=normalize((VIEW_MATRIX*vec4(n_w,0.0)).xyz);
	if(v_uv.y>.25 && v_uv.y<.90){
		col*=mix(.92,1.05,smoothstep(0.0,.82,v_uv.x));
	}
	float d_lamp=length(world_pos-vec3(12.3,.56,-2.45));
	float is_lantern_core=step(.90,v_uv.y)*smoothstep(.52,.32,d_lamp);
	col+=lantern_glow_color*exp(-d_lamp*d_lamp*.65)*.28*lantern_glow_strength;
	ALBEDO=col;
	AO=ao_val;
	AO_LIGHT_AFFECT=v_is_bark*.52;
	EMISSION=lantern_glow_color*is_lantern_core*(.36+1.35*lantern_glow_strength);
	ROUGHNESS=.93;
	SPECULAR=.02;
}
void light(){
	vec3 lc=LIGHT_COLOR/PI;
	float l_peak=max(lc.r,max(lc.g,lc.b));
	float ndl=dot(NORMAL,LIGHT);
	if(LIGHT_IS_DIRECTIONAL && l_peak<.45){
		float sky_fill=.32+.68*clamp(.50+.50*ndl,0.0,1.0);
		DIFFUSE_LIGHT+=(vec3(.82,.93,1.06)*(.30*sky_fill))*lc;
	}else{
		float wrap=smoothstep(-.18,.62,ndl);
		float direct_t=clamp(smoothstep(-.04,.50,ndl)*ATTENUATION,0.0,1.0);
		vec3 shadow_tint=mix(vec3(.76,.90,1.04),vec3(.72,.88,1.07),v_is_bark);
		vec3 lit_tint=mix(vec3(1.06,1.01,.93),vec3(1.11,1.04,.93),v_is_bark);
		vec3 temp_tint=mix(shadow_tint,lit_tint,direct_t);
		vec3 indirect_sky=shadow_tint*(.045*(1.0-direct_t));
		float lit=wrap*mix(.04,1.0,ATTENUATION)*.78+smoothstep(.12,.76,ndl)*ATTENUATION*mix(.09,.16,v_is_bark);
		DIFFUSE_LIGHT+=(temp_tint*lit+indirect_sky)*lc;
	}
}
