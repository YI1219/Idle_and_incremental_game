shader_type sky;
#include "sky_palette.gdshaderinc"
uniform sampler2D cloud_backdrop : source_color, filter_linear_mipmap, repeat_enable;
uniform float haze : hint_range(0.0,1.0) = .68;
uniform vec3 sky_cloud_dark : source_color = vec3(.55,.68,.74);
uniform vec3 sky_cloud_light : source_color = vec3(.98,.95,.87);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x),u.y);}
void sky(){
	if(AT_CUBEMAP_PASS){
		float cloud=noise(EYEDIR.xz*14.0);
		vec3 sky_col=sky_gradient_factors(sky_view_factors(EYEDIR))*(.94+.10*cloud);
		float down=smoothstep(.08,-.68,EYEDIR.y);
		COLOR=mix(sky_col,sky_cloud_dark*.68,down);
	}else{
		vec3 factors=sky_view_factors(EYEDIR);
		vec3 color=sky_gradient_factors(factors);
		// Soft painted silk-grain & high cirrus wisps in 3D direction space (zero seam!)
		vec2 dir_uv=vec2(EYEDIR.x*2.2+EYEDIR.z*1.6,EYEDIR.y*16.0);
		float cirrus=smoothstep(.50,.74,noise(dir_uv*vec2(1.6,2.4))+noise(dir_uv*vec2(4.2,5.8))*.24);
		color=mix(color,vec3(.98,.96,.90),cirrus*.11*(1.0-smoothstep(.22,.54,factors.x)));
		// Analytic C-infinity 3D horizontal cross-fade inside [0.08, 0.92] of cloud_backdrop:
		// never touches non-tileable image borders (u=0/1) and never uses atan wrapping!
		vec2 h_dir=normalize(vec2(EYEDIR.x,EYEDIR.z)+vec2(1e-5,0.0));
		float v_coord=.20+clamp(factors.x,-.22,1.20)*.76;
		vec3 sample_a=textureLod(cloud_backdrop,vec2(.50+.41*h_dir.x,v_coord),1.4).rgb;
		vec3 sample_b=textureLod(cloud_backdrop,vec2(.50-.41*h_dir.y,v_coord),1.4).rgb;
		vec3 source=mix(sample_a,sample_b,h_dir.x*h_dir.x);
		float density=smoothstep(.14,.68,source.r);
		float cloud_light=smoothstep(.22,.88,source.r);
		float h_sun=factors.z;
		vec3 cool_c=mix(sky_cloud_dark*vec3(.82,.95,1.04),sky_cloud_light*vec3(.62,.76,.84),cloud_light*.65);
		vec3 warm_c=mix(sky_cloud_dark,sky_cloud_light,cloud_light);
		vec3 cloud_color=mix(cool_c,warm_c,h_sun);
		float sun=factors.y;
		cloud_color+=vec3(.09,.07,.035)*exp(-sun*4.2);
		color=mix(color,cloud_color,density*smoothstep(.24,.76,factors.x)*(.30+(haze-.65)*.10));
		COLOR=mix(color,SKY_SUN_CORE,sky_disc_from_distance(factors.y));
	}
}
