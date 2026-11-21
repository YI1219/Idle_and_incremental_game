shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled,shadows_disabled,fog_disabled;
#include "sky_palette.gdshaderinc"
// Layered Xuan-silk cloud sea (流云烟海) & island-waist floating mist (山腰浮岚).
uniform sampler2D billow : filter_linear_mipmap, repeat_enable;
uniform vec3 sun_direction = vec3(.56,.50,-.66);
uniform float uv_scale = .0016;
uniform vec2 uv_offset = vec2(0.0);
uniform float coverage = .46;
uniform float opacity = .92;
uniform float aerial_density = .00085;
uniform float fade_radius = 2300.0;
uniform float inner_clear_radius = 0.0;
uniform float cloud_spatial_scale : hint_range(.1,2.0) = 1.0;
uniform float cloud_detail_weight : hint_range(0.0,1.0) = .26;
uniform float cloud_light_gradient : hint_range(0.0,20.0) = 14.5;
uniform float cloud_color_contrast : hint_range(0.0,1.0) = 1.0;
uniform float cloud_value : hint_range(.5,1.5) = 1.0;
uniform vec3 cloud_shade_color : source_color = vec3(.58,.68,.72);
uniform vec3 cloud_lit_color : source_color = vec3(.96,.92,.82);
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float shape(vec2 uv){
	// Anisotropic Song-scroll ribbon clouds (流云飞白): gentle S-curve silk drift instead of isotropic noise blobs
	vec2 ribbon_uv=vec2(uv.x*1.24+uv.y*.22,uv.y*.80-uv.x*.16);
	vec2 warp=vec2(texture(billow,ribbon_uv*.38+vec2(.19,.63)).r,texture(billow,ribbon_uv*.38+vec2(.71,.27)).r)-.5;
	vec2 u=ribbon_uv+warp*.15;
	float b0=texture(billow,u).r;
	float b1=texture(billow,u*2.25+vec2(.37,.11)).r;
	return mix(b0,b1,cloud_detail_weight);
}
void fragment(){
	vec2 uv=world_position.xz*uv_scale*cloud_spatial_scale+uv_offset+vec2(TIME*.0009,TIME*.0004);
	float body=shape(uv);
	vec2 sun_xz=length(sun_direction.xz)>.001 ? normalize(sun_direction.xz) : vec2(.7,.7);
	float toward_sun=shape(uv+sun_xz*.022);
	float toward_sun_fine=shape(uv+sun_xz*.009);
	// Sculpted 3D cloud-billow cushions with silver-gold forward-scattered crests (Journey / Europa):
	float density=smoothstep(coverage-.07,coverage+.17,body);
	float thick=smoothstep(coverage-.02,coverage+.32,body);
	float lit=clamp(.44+(body-toward_sun)*(cloud_light_gradient*1.25),0.0,1.0);
	float crest_rim=clamp((body-toward_sun_fine)*22.0,0.0,1.0)*smoothstep(coverage-.03,coverage+.18,body)*(1.0-smoothstep(coverage+.20,coverage+.42,body));
	vec3 view=world_position-CAMERA_POSITION_WORLD;
	float distance=max(length(view),.001);
	vec2 p=sky_coord(view/distance);
	float sun_d=sky_sun_distance(p);
	float h_sun=sky_horiz_sun(p);
	float billow_t=clamp(lit*.58+thick*.48-.05,0.0,1.0);
	// Cool celadon-slate billow troughs -> warm sunlit cream-gold crests:
	vec3 cool_cloud=mix(cloud_shade_color*vec3(.84,.98,1.06),cloud_lit_color*vec3(.74,.84,.90),billow_t*.78);
	vec3 warm_cloud=mix(cloud_shade_color*vec3(1.34,1.24,1.04),cloud_lit_color*vec3(1.10,1.04,.92),clamp(.40+billow_t*.60,0.0,1.0));
	vec3 color=mix(cool_cloud,warm_cloud,h_sun);
	float day_t=smoothstep(.35,.80,sky_horizon.r);
	float day_hdr=mix(1.0,mix(1.04,1.52,h_sun),day_t);
	color=mix(vec3(.60,.72,.78),color,cloud_color_contrast)*cloud_value*day_hdr;
	color+=mix(vec3(.07,.09,.09),vec3(.18,.14,.07),h_sun)*crest_rim*day_t;
	color+=vec3(.16,.11,.05)*exp(-sun_d*1.75)*thick*day_t;
	float aerial=1.0-exp(-distance*aerial_density*.55);
	vec3 dir_haze=sky_gradient(p);
	ALBEDO=mix(color,dir_haze,clamp(aerial*.36,0.0,.42));
	float horizontal=length(world_position.xz-NODE_POSITION_WORLD.xz);
	float inner_mask=inner_clear_radius>.5 ? smoothstep(inner_clear_radius*.45,inner_clear_radius,length(world_position.xz)) : 1.0;
	float horizon=smoothstep(.04,.34,p.y);
	// Smooth radial fade well inside the 4800m PlaneMesh so square corners never appear!
	float edge_fade=1.0-smoothstep(fade_radius*.48,fade_radius*.94,horizontal);
	ALPHA=density*opacity*horizon*inner_mask*edge_fade;
}
