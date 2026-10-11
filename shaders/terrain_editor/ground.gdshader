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
	// Crown tops are part of this same surface. Their outward band mixes
	// olive turf and stone without a raised ledge or an inland outline.
	float rim=(1.0-COLOR.a)*(1.0-smoothstep(.02,.28,UV.x))*smoothstep(.0,.24,UV.y);
	float mineral=rock_hash(floor(vec3(p.x,0.0,p.y)*5.0)).x;
	vec3 stone=cliff_gray(.45+.25*mineral)+vec3(.03,.045,.055);
	color=mix(color,stone,rim*(.30+.22*mineral));
	if(show_grid){vec2 grid=abs(fract(p)-0.5);float edge=step(0.486,max(grid.x,grid.y));color=mix(color,vec3(0.91,0.95,0.66),edge*0.35);}
	ALBEDO=color*COLOR.rgb;
	vec3 normal_world=normalize(vec3(-slope.x*cover_relief*detail,1.0,-slope.y*cover_relief*detail));
	NORMAL=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
	ROUGHNESS=0.95;
	SPECULAR=.30;
}
