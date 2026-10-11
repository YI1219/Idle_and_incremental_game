shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
#include "cliff_palette.gdshaderinc"
render_mode cull_disabled;
uniform bool show_grid = false;
uniform float cover_relief = .55;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=terrain_morph_offset(world_position);}
void fragment(){
	vec2 p=world_position.xz;
	float footprint=length(fwidth(p))*9.0;
	float detail=1.0-smoothstep(.35,1.0,footprint);
	vec2 slope;
	vec3 color=ground_cover(p,detail,slope);
	// Exposed crown patches, never a perimeter-distance stroke. Most of the
 // shared cap is turf, including its edge; sparse mineral windows stop inland.
 float patch=gc_noise(p*1.65+vec2(11.0,3.0));
 float exposed=(1.0-COLOR.a)*smoothstep(.70,.83,patch)*(1.0-smoothstep(.04,.20,UV.x));
 color=mix(color,cliff_gray(.65)+vec3(.03,.04,.05),exposed*.8);
	if(show_grid){vec2 grid=abs(fract(p)-0.5);float edge=step(0.486,max(grid.x,grid.y));color=mix(color,vec3(0.91,0.95,0.66),edge*0.35);}
	ALBEDO=color*COLOR.rgb;
	vec3 base_normal=normalize(cross(dFdx(world_position),dFdy(world_position)));
 if(base_normal.y<0.0)base_normal=-base_normal;
 vec3 normal_world=normalize(base_normal+vec3(-slope.x*cover_relief*detail,0.0,-slope.y*cover_relief*detail));
	NORMAL=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	ROUGHNESS=0.95;
	SPECULAR=.30;
}
