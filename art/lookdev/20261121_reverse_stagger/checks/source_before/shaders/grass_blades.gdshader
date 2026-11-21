shader_type spatial;
render_mode cull_disabled;
#include "terrain_morph.gdshaderinc"
#include "live_water.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
// Wind-combed plush gouache velvet meadow & swaying breeze plumes (风吹草低柔绒草甸):
// Evaluates root-anchored ground_cover & moss-pillow gradient in vertex() (~25x faster fragment throughput!),
// with rolling mountain-breeze gust waves and sunlit spring-tea sheen in light().
uniform float wind_strength : hint_range(0.0, 1.0) = .54;
uniform vec2 wind_direction = vec2(.82, .38);
uniform float grass_time = -1.0;
varying vec3 v_root_col;
varying vec3 v_tip_col;
varying vec3 v_blade_n;
varying vec3 v_canopy_col;
varying vec3 v_canopy_n;
varying float blade_t;
varying float v_gust;
varying float grass_coverage;
void vertex(){
	float t_wind=grass_time<0.0?TIME:grass_time;
	vec3 root_world=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	blade_t=COLOR.r;
	float blade_tone=COLOR.g;
	float blade_phase=COLOR.b;
	vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float dist=length(world-CAMERA_POSITION_WORLD);
	float keep=1.0-smoothstep(74.0,108.0,dist);
	vec3 shown_root=root_world;
	shown_root.y+=terrain_morph_offset(root_world);
	grass_coverage=live_grass_coverage(shown_root);
	float water_keep=smoothstep(0.0,.65,grass_coverage);
	float standing=gc_standing(root_world.xz);
	float press=1.0-standing;
	keep*=mix(1.0,0.24,press);
	float bend=pow(blade_t,1.55);
	vec2 dir=normalize(wind_direction);
	vec2 cross_dir=vec2(-dir.y,dir.x);
	float phase=dot(root_world.xz,vec2(.37,.27));
	// Traveling mountain-breeze wave warped organically in 2D so it NEVER forms straight parallel stripes on the lawn:
	float warp=gc_noise(root_world.xz*.22+vec2(2.3,7.1))*2.6;
	float wave_coord=dot(root_world.xz,dir)*.26-dot(root_world.xz,cross_dir)*.11+warp-t_wind*1.85;
	float gust_wave=pow(sin(wave_coord)*.5+.5,1.55)*(.68+.32*sin(wave_coord*.43+1.3));
	v_gust=gust_wave*standing;
	float tuft_sway=sin(t_wind*2.15+phase+blade_phase*1.5)*.60+sin(t_wind*3.55+phase*1.7-blade_phase)*.28;
	float cross_sway=sin(t_wind*1.60+phase*1.3+blade_phase*2.1)*.24;
	float world_h=max(world.y-root_world.y,.08);
	float reach=clamp(world_h/.28,.45,1.55);
	float along_disp=(.015+gust_wave*.055+tuft_sway*.025)*wind_strength*bend*reach*(1.0-press*.68);
	float side_disp=cross_sway*wind_strength*.045*bend*reach*(1.0-press*.68);
	vec2 disp_xz=dir*along_disp+cross_dir*side_disp;
	vec3 offset=vec3(disp_xz.x,-length(disp_xz)*.36-press*.08*bend,disp_xz.y);
	vec2 sway_xz=disp_xz*1.65;
	vec3 local_offset=(inverse(MODEL_MATRIX)*vec4(offset,0.0)).xyz;
	VERTEX=(VERTEX*vec3(1.0,keep,1.0)+local_offset*keep)*water_keep;
	if(terrain_morph_progress<1.0){VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(root_world),0.0,0.0)).xyz;}

	vec2 slope;
	vec3 ground=ground_cover(root_world,0.0,slope);
	float patch_var=gc_noise(root_world.xz*.55+vec2(4.1,2.7));
	float tone_mix=clamp(patch_var*.50+blade_tone*.50+v_gust*.16,0.0,1.0);
	// The CPU's correlated height is also the tuft's pigment weight: soft low
	// grass stays unified, while the occasional taller fan has a shaded heart.
	float tuft_volume=smoothstep(.82,1.28,length(MODEL_MATRIX[1].xyz));
	v_root_col=ground*mix(vec3(.86,.90,.82),vec3(.62,.74,.51),tuft_volume);
	vec3 fan_tip=mix(vec3(1.09,1.12,.96),vec3(1.21,1.18,1.01),tone_mix);
	v_tip_col=ground*mix(vec3(1.04,1.07,.98),fan_tip,tuft_volume);
	// Even subpixel leaves retain a little root-to-tip volume. Filtering the
	// whole ribbon to one bright canopy colour previously erased that volume.
	v_canopy_col=ground*mix(mix(vec3(.94,.97,.88),vec3(.78,.87,.67),tuft_volume),mix(vec3(1.03,1.05,.98),vec3(1.10,1.12,.97),tuft_volume),smoothstep(.0,.80,blade_t));

	vec2 pillow_g=gc_pillow_grad(root_world.xz)*(.14*standing);
	vec3 rn=normalize(MODEL_NORMAL_MATRIX*NORMAL);
	if(rn.y<0.0)rn=-rn;
	float leaf_curve=mix(.35,.62,tuft_volume);
	v_blade_n=normalize(vec3(rn.x*leaf_curve-pillow_g.x-sway_xz.x*.30,max(.84,rn.y),rn.z*leaf_curve-pillow_g.y-sway_xz.y*.30));
	vec3 up=normalize(MODEL_NORMAL_MATRIX*vec3(0.0,1.0,0.0));
	v_canopy_n=normalize(up+vec3(-pillow_g.x,0.0,-pillow_g.y));
}
void fragment(){
 if(!terrain_transition_visible(FRAGCOORD.xy))discard;
	if(!grass_coverage_visible(grass_coverage,FRAGCOORD.xy))discard;
	// Preserve the visible leaf at the lip; aggregate narrow leaves into the
	// same painted canopy as the ground instead of shimmering dark/light pixels.
	float width_pixels=1.0/max(fwidth(UV.x),.0001);
	float leaf_detail=mix(.45,1.0,smoothstep(1.5,5.0,width_pixels));
	vec3 leaf=mix(v_root_col,v_tip_col,smoothstep(.06,.90,blade_t));
	// At MSAA silhouette samples a subpixel triangle can extrapolate UV
	// beyond its ribbon. Keep pigment and AO in their physical ranges.
	float edge=clamp(UV.x,0.0,1.0)*2.0-1.0;
	edge*=edge;
	leaf*=1.0-.045*edge;
	ALBEDO=mix(v_canopy_col,leaf,leaf_detail);
	vec3 normal_world=normalize(mix(v_canopy_n,v_blade_n,leaf_detail));
	NORMAL=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	AO=mix(.97,mix(.90,.99,clamp(blade_t,0.0,1.0)),leaf_detail);
	AO_LIGHT_AFFECT=.45;
	ROUGHNESS=.93;
	SPECULAR=.02;
}
void light(){
	// Broad rough leaf diffusion, with a small transmitted component. The
	// two-sided ribbons remain matte while their curved faces catch the key.
	meadow_diffuse(NORMAL,LIGHT,LIGHT_COLOR,ATTENUATION,DIFFUSE_LIGHT);
}
