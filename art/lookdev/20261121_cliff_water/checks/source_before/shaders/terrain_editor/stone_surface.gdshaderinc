#include "weathering.gdshaderinc"
// Matte rice-gray mineral pigment: broad gouache wash, quiet warm/cool
// islands and fine chalk tooth. Shared by existing stone assets and cliffs.
// Shared across cliff monoliths, core hull, boulders, shore stones, and ground/grass.
uniform sampler2D stone_detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_mineral_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_gouache_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float stone_relief_strength : hint_range(0.0, 1.0) = .009;
uniform float stone_roughness : hint_range(0.0, 1.0) = .92;
uniform vec3 stone_shadow_color : source_color = vec3(.24,.31,.43);
uniform vec3 stone_mid_color : source_color = vec3(.50,.48,.46);
uniform vec3 stone_lit_color : source_color = vec3(.80,.73,.62);
uniform vec3 stone_mist_color : source_color = vec3(.89,.89,.86);

vec3 stone_weights(vec3 n){vec3 w=pow(abs(n),vec3(3.0));return w/max(dot(w,vec3(1.0)),.001);}
vec4 stone_map(vec3 p,vec3 n){vec3 w=stone_weights(n);return texture(stone_detail_map,p.zy*.24)*w.x+texture(stone_detail_map,p.xz*.24)*w.y+texture(stone_detail_map,p.xy*.24)*w.z;}
vec3 stone_mineral(vec3 p,vec3 n){vec3 w=stone_weights(n);return texture(stone_mineral_map,p.zy*.20).rgb*w.x+texture(stone_mineral_map,p.xz*.20).rgb*w.y+texture(stone_mineral_map,p.xy*.20).rgb*w.z;}
vec3 stone_pigment_tex(vec2 uv){return texture(stone_gouache_map,uv,1.15).rgb;}
vec3 stone_gouache(vec3 p,vec3 n){
	vec3 w=stone_weights(n);
	vec3 broad=stone_pigment_tex(p.zy*.11)*w.x+stone_pigment_tex(p.xz*.11)*w.y+stone_pigment_tex(p.xy*.11)*w.z;
	vec3 med=stone_pigment_tex(p.zy*.26+vec2(.37,.61))*w.x+stone_pigment_tex(p.xz*.26+vec2(.37,.61))*w.y+stone_pigment_tex(p.xy*.26+vec2(.37,.61))*w.z;
	return mix(broad,med,.38);
}

vec3 stone_normal(vec3 p,vec3 n){
	vec3 w=stone_weights(n);
	vec2 x=(texture(stone_detail_map,p.zy*.22).gb-.5)*2.0+(texture(stone_detail_map,p.zy*.54+vec2(.31,.17)).gb-.5)*.9;
	vec2 y=(texture(stone_detail_map,p.xz*.22).gb-.5)*2.0+(texture(stone_detail_map,p.xz*.54+vec2(.31,.17)).gb-.5)*.9;
	vec2 z=(texture(stone_detail_map,p.xy*.22).gb-.5)*2.0+(texture(stone_detail_map,p.xy*.54+vec2(.31,.17)).gb-.5)*.9;
	vec3 slope=vec3(0.0,x.y,x.x)*w.x+vec3(y.x,0.0,y.y)*w.y+vec3(z.x,z.y,0.0)*w.z;
	return normalize(n-(slope-n*dot(n,slope))*(stone_relief_strength*1.35));
}

float stone_noise(vec3 p){
	vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(mix(rock_hash(i).x,rock_hash(i+vec3(1,0,0)).x,f.x),mix(rock_hash(i+vec3(0,1,0)).x,rock_hash(i+vec3(1,1,0)).x,f.x),f.y),mix(mix(rock_hash(i+vec3(0,0,1)).x,rock_hash(i+vec3(1,0,1)).x,f.x),mix(rock_hash(i+vec3(0,1,1)).x,rock_hash(i+vec3(1,1,1)).x,f.x),f.y),f.z);
}

// Mineral pigment and rough diffuse are separate. No fixed sun direction is baked
// into the stone: the same surface must read from reverse and in moonlight.
vec3 stone_surface(vec3 p,vec3 n){
 vec3 wash=stone_gouache(p*.82,n);
 // Linear mean of the neutral, unlit pigment asset. Preserve its local
 // warm/cool strokes while the scene palette remains authoritative.
 vec3 pigment_wash=clamp(wash/vec3(.4988,.4529,.3858),vec3(.72),vec3(1.28));
 float cloud=stone_noise(p*.38+vec3(3.2,7.4,1.8));
 float chalk=stone_noise(p*1.35+vec3(8.1,2.7,6.4));
 vec3 rice=mix(stone_mid_color,stone_lit_color,.48)*vec3(1.0,1.018,1.15);
 // Night palette keys already contain moonlight color. Neutralize their
 // extra blue in the pigment so real blue illumination is not applied twice.
 float moon_palette=smoothstep(0.0,.06,stone_mid_color.b-stone_mid_color.r);
 rice=mix(rice,vec3(dot(rice,vec3(.2126,.7152,.0722))),moon_palette*.78);
 vec3 pigment=rice*pigment_wash;
 // Pigment has three real scales: broad brushed wash, warm/cool mineral
 // islands, then restrained stone tooth. None is a painted directional light.
 pigment*=.935+.105*cloud+.020*chalk;
 float tooth=stone_map(p*1.4,n).r;
 return pigment*(.998+.004*tooth);
}

// Presence for tall faces. A calm wash alone leaves a wide wall paper-flat, most
// of all in shade where only albedo can speak. Painted layers, all world
// anchored so neighbouring slabs share them:
//  - long mineral plates: the mineral map stretched about 3:1 along gravity,
//    with its darkest flakes deepened into seams;
//  - fissures: the same map stretched about 7:1, keeping only its dark tail, so
//    a few long uneven strokes run down the face;
//  - a mossy weathered brow that runs down from the grass lip in uneven drips.
// A broad "voice" field lets parts of every face rest. Tops stay untouched.
// Costs four taps of an already bound map and two value noises; a low quality
// tier can set cliff_character to 0 and skip all of it.
// Linear statistics of stone_mineral_v1: mean .338, spread about .10.
uniform float cliff_character : hint_range(0.0, 1.5) = 1.0;
const float CLIFF_PLATE_MEAN = .338;
const float CLIFF_PLATE_SPREAD = .10;
const vec3 CLIFF_PLATE_CHROMA = vec3(1.077, 1.019, .905);
vec3 stone_cliff_character(vec3 pigment, vec3 p, vec3 n, float cap_height, float brow){
	float steep = 1.0 - smoothstep(.50, .82, abs(n.y));
	if(cliff_character <= .001 || steep <= .001) return pigment;
	vec2 w = abs(n.xz);
	w /= max(w.x + w.y, .001);
	vec3 plate = texture(stone_mineral_map, vec2(p.z * .135 + .21, p.y * .046)).rgb * w.x
		+ texture(stone_mineral_map, vec2(p.x * .135 + .63, p.y * .046 + .37)).rgb * w.y;
	float lum = dot(plate, vec3(.3333));
	float tone = clamp((lum - CLIFF_PLATE_MEAN) / CLIFF_PLATE_SPREAD, -1.0, 1.0);
	float voice = smoothstep(.28, .64, stone_noise(p * vec3(.10, .065, .10) + vec3(4.7, 1.3, 9.2)));
	float amount = cliff_character * steep * mix(.45, 1.0, voice);
	pigment *= 1.0 + tone * .21 * amount;
	pigment *= mix(vec3(1.0), clamp(plate / max(lum, .02) / CLIFF_PLATE_CHROMA, vec3(.89), vec3(1.11)), .85 * amount);
	float seam = smoothstep(CLIFF_PLATE_MEAN - CLIFF_PLATE_SPREAD * .75, CLIFF_PLATE_MEAN - CLIFF_PLATE_SPREAD * 1.35, lum);
	pigment *= 1.0 - seam * .20 * amount;
	float streak = texture(stone_mineral_map, vec2(p.z * .074 + .52, p.y * .0105 + .11)).g * w.x
		+ texture(stone_mineral_map, vec2(p.x * .074 + .08, p.y * .0105 + .71)).g * w.y;
	float fissure = smoothstep(CLIFF_PLATE_MEAN - CLIFF_PLATE_SPREAD * .55, CLIFF_PLATE_MEAN - CLIFF_PLATE_SPREAD * 1.15, streak);
	pigment *= 1.0 - fissure * .30 * cliff_character * steep * mix(.25, 1.0, voice);
	float depth = cap_height - p.y;
	float reach = mix(.25, 2.4, smoothstep(.34, .70, stone_noise(vec3(p.x * .38, 5.3, p.z * .38))));
	float moss = brow * (1.0 - smoothstep(reach * .30, reach, depth + tone * .22)) * step(-.08, depth);
	return mix(pigment, pigment * vec3(.76, .92, .60), moss * .55 * min(cliff_character, 1.0) * steep);
}

// Oren-Nayar rough diffuse: broad mineral grains return light at grazing angles
// without a plastic specular sheet. Cast shadows remain real ATTENUATION.
void stone_painted_light(vec3 n,vec3 v,vec3 l,vec3 light_color,float attenuation,inout vec3 diffuse){
 float nl=max(dot(n,l),0.0);
 float nv=max(dot(n,v),.001);
 float lv=dot(l,v);
 float sigma=stone_roughness*.78;
 float sigma2=sigma*sigma;
 float a=1.0-.5*sigma2/(sigma2+.33);
 float b=.45*sigma2/(sigma2+.09);
 float s=lv-nl*nv;
 float t=mix(1.0,max(nl,nv),step(0.0,s));
 float rough_diffuse=nl*(a+b*max(s,0.0)/max(t,.08));
 // Small diffuse multiple scattering keeps matte stone from going charcoal.
 float multiple_scatter=.075*nl;
 vec3 lc=light_color/PI;
 diffuse+=lc*(rough_diffuse*1.10+multiple_scatter)*attenuation;
}

// Broad mineral relief affects illumination, rather than adding photographic
// grain to albedo. It stays world-anchored across adjacent geological planes.
vec3 stone_mineral_normal(vec3 p,vec3 n){
 float e=.10;
 float h=stone_noise(p*.95);
 vec3 g=vec3(stone_noise((p+vec3(e,0,0))*.95)-h,
             stone_noise((p+vec3(0,e,0))*.95)-h,
             stone_noise((p+vec3(0,0,e))*.95)-h)/e;
 vec3 broad=normalize(n-(g-n*dot(n,g))*.035);
 return normalize(mix(broad,stone_normal(p,n),.65));
}

vec3 stone_mist_dissolve(vec3 stone,vec3 p,vec3 n){
	// Gentle aerial mist veil on deep mountain roots (-5.2m .. -11.8m) so colossal keels melt poetically into clouds:
	float wave=sin(p.x*.14+p.z*.12)*.42+cos(p.x*.25-p.z*.19)*.18;
	float mist_t=smoothstep(-5.0+wave,-11.6+wave,p.y);
	float haze=clamp(pow(mist_t,1.18)*.48,0.0,.48);
	return mix(stone,stone_mist_color,haze);
}

float stone_lip_ao(vec3 p,vec3 n,float cap_height,float dry){
	if(dry<.5)return 0.0;
	float depth=cap_height-p.y;
	if(depth<-.04 || depth>.24)return 0.0;
	float lip_noise=stone_noise(vec3(p.x*1.1,p.y*1.0,p.z*1.1));
	float band=(1.0-smoothstep(.008,.085+.065*lip_noise,max(0.0,depth)))*(.65+.35*lip_noise);
	return clamp(band*smoothstep(.70,-.30,n.y),0.0,1.0);
}

// A thin planted contact, without painting a blue-grey belt around the island.
vec3 stone_root_contact(vec3 stone,vec3 p,vec3 n,float cap_height,float dry){
	float lip_crease=stone_lip_ao(p,n,cap_height,dry);
	if(lip_crease<=.001)return stone;
	return stone*mix(vec3(1.0),vec3(.68,.71,.64),lip_crease*.48);
}

// Stylized Tri-Hemisphere Gouache Meadow & Turf Lighting (luminous golden-jade lawn + deep cool emerald cast shadows):
void stone_gouache_light(vec3 normal_v,vec3 light_v,vec3 light_col,float atten,inout vec3 diff_out){
	vec3 lc=light_col/PI;
	float l_peak=max(lc.r,max(lc.g,lc.b));
	float l_lum=dot(lc,vec3(.299,.587,.114));
	float ndl=dot(normal_v,light_v);
	if(l_peak<.45){
		float sky_up=.36+.64*clamp(.50+.50*ndl,0.0,1.0);
		diff_out+=vec3(.66,.86,1.08)*(.34*sky_up*l_lum);
		return;
	}
	float wrap=.30+.78*smoothstep(-.15,.95,ndl);
	float sun_atten=atten*atten;
	float direct_t=clamp(smoothstep(-.02,.38,ndl)*sun_atten,0.0,1.0);
	vec3 direct_col=lc*vec3(1.03,1.01,.95)*(wrap*sun_atten*.94+smoothstep(.26,.86,ndl)*sun_atten*.10);
	vec3 shadow_sky=vec3(.60,.83,1.06)*(.050*(1.0-direct_t)*l_lum);
	diff_out+=direct_col+shadow_sky;
}

// Stylized Tri-Hemisphere GI + Crisp Chiseled Boulder Facet Lighting (Refs 01–04 / Tiny Glade):
// - Zero intra-face wavy bumpiness: every boulder face stays crisp, flat-planar, and cleanly stepped!
// - Bright sunlit & sky-lit top tables (world_ny > 0.5) vs calm vertical cleavage walls vs dark undercut bellies!
void stone_crisp_facet_light(vec3 normal_v,vec3 light_v,vec3 light_col,float atten,bool is_dir,float world_ny,inout vec3 diff_out){
	vec3 lc=light_col/PI;
	float l_peak=max(lc.r,max(lc.g,lc.b));
	float l_lum=dot(lc,vec3(.299,.587,.114));
	float ndl=dot(normal_v,light_v);

	if(is_dir && l_peak<.45){
		float dir_sculpt=pow(clamp(.52+.48*ndl,0.0,1.0),1.45);
		float top_lift=.38+.62*smoothstep(-.54,.86,world_ny);
		diff_out+=vec3(.62,.77,1.18)*(.56*dir_sculpt*top_lift*l_lum);
		return;
	}

	float top_zenith=smoothstep(.38,.84,world_ny);
	float under_tuck=smoothstep(-.08,-.62,world_ny);

	// Grazing-safe sculptural terminator across flat chiseled boulder arêtes:
	float cut_lo=mix(.085,.018,top_zenith);
	float cut_hi=mix(.265,.105,top_zenith);
	float shadow_gate=smoothstep(.12,.55,atten);
	float term=smoothstep(cut_lo,cut_hi,ndl)*shadow_gate;

	float lambert_curve=pow(clamp((ndl+.02)/1.02,0.0,1.0),.72);
	float side_lit=.26+.52*lambert_curve;
	float top_lit=.46*top_zenith*(.54+.46*smoothstep(.02,.66,ndl));
	vec3 sun_tint=mix(vec3(1.10,1.00,.88),vec3(1.15,1.04,.91),top_zenith);
	vec3 direct_contrib=lc*sun_tint*(term*(side_lit+top_lit));

	// In shadow, upward boulder shelves catch direct overhead zenith sky (even on West-facing cliffs!)
	// while vertical walls sit in calm celadon-slate and undercuts receive soft cloud-sea bounce:
	float facet_sky=smoothstep(-.56,.88,world_ny);
	float facet_sun_side=smoothstep(-.82,.26,ndl);
	vec3 deep_slate=vec3(.48,.61,1.12);
	vec3 horizon_celadon=vec3(.80,.90,1.15);
	vec3 sky_table=vec3(.92,.98,1.20);
	float shadow_grad=(.022+.038*facet_sky)*(.52+.80*facet_sun_side)*(1.0-.16*under_tuck);
	float shelf_sky_boost=top_zenith*(1.0-.46*smoothstep(.05,.45,ndl));
	vec3 zenith_gi=mix(deep_slate,horizon_celadon,facet_sun_side*.62+top_zenith*.38)*(shadow_grad*l_lum)+sky_table*(.042*shelf_sky_boost*l_lum);
	vec3 cloud_bounce_gi=mix(vec3(.62,.75,1.10),vec3(1.04,.93,.82),facet_sun_side)*((.036+.034*facet_sun_side)*under_tuck*l_lum);
	vec3 indirect_gi=(zenith_gi+cloud_bounce_gi)*(1.0-term*.68);

	diff_out+=direct_contrib+indirect_gi;
}
