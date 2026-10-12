shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
render_mode cull_disabled, specular_disabled;
uniform bool show_grid = false;
uniform float cover_relief = 1.15;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=terrain_morph_offset(world_position);}
void fragment(){
	vec2 p=world_position.xz;
	float footprint=length(fwidth(p))*9.0;
	float detail=1.0-smoothstep(.35,1.0,footprint);
	vec2 slope;
	vec3 color=ground_cover(p,detail,slope);
	// Up close the olive pair would read as a painted sheet between blades.
	// Loam shows in those gaps; distance falls back to the unresolved lawn.
	float moss=smoothstep(.58,.88,gc_noise(p*1.15+vec2(3.2,8.4)));
	float loam_n=gc_noise(p*2.35+vec2(4.2,1.6));
	float clod=gc_noise(p*vec2(6.2,7.4)+vec2(1.4,9.0));
	float grit=gc_noise(p*vec2(15.0,17.0));
	vec3 loam=mix(vec3(.10,.08,.055),vec3(.18,.14,.09),loam_n*.60+clod*.40);
	loam*=1.0+(grit-.5)*.08;
	loam=mix(loam,loam*vec3(.92,1.0,.86),smoothstep(.55,.88,gc_noise(p*.42+vec2(7.0,2.2))));
	float pebble=smoothstep(.86,.97,gc_noise(p*vec2(22.0,26.0)));
	loam=mix(loam,loam*vec3(1.22,1.14,1.02),pebble*.35);
	// Same low-frequency meadow as the clump scatter. Thick grass keeps the
	// olive pair underneath so a missed blade is not a hole in a dirt field.
	// Thin patches open into loam.
	float meadow=clamp((sin(p.x*1.15+p.y*.42)*sin(p.y*1.35-p.x*.33)*.55+sin(p.x*2.05-p.y*.70)*sin(p.y*1.80+p.x*.55)*.45)*.5+.74,0.0,1.0);
	meadow=meadow*meadow*(3.0-2.0*meadow);
	float soil_amt=mix(.84,.18,meadow);
	soil_amt=mix(soil_amt,soil_amt*.72,moss);
	color=mix(color,loam,detail*soil_amt);
	// Exposed crown patches, never a perimeter-distance stroke. Most of the
 // shared cap is turf, including its edge; sparse mineral windows stop inland.
 float patch=gc_noise(p*1.65+vec2(11.0,3.0));
 float exposed=(1.0-COLOR.a)*smoothstep(.70,.83,patch)*(1.0-smoothstep(.04,.20,UV.x));
 color=mix(color,stone_surface(world_position,vec3(0.0,1.0,0.0)),exposed*.8);
	if(show_grid){vec2 grid=abs(fract(p)-0.5);float edge=step(0.486,max(grid.x,grid.y));color=mix(color,vec3(0.91,0.95,0.66),edge*0.35);}
	ALBEDO=color*COLOR.rgb;
	vec3 base_normal=normalize(cross(dFdx(world_position),dFdy(world_position)));
 if(base_normal.y<0.0)base_normal=-base_normal;
 vec3 normal_world=normalize(base_normal+vec3(-slope.x*cover_relief*detail,0.0,-slope.y*cover_relief*detail));
	NORMAL=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	ROUGHNESS=0.98;
}
