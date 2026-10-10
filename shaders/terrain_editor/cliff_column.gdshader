shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
// Rock bodies: each mesh is one faceted solid, crown at y=0, foot below.
// The crown carries the same world-space lawn as the cap beside it. Moss stays
// on that crown. The rock below weathers in vertical streaks. Instance scale
// stays near uniform, so the silhouette is the mesh, not a stretched box.
uniform float cover_relief = .55;
varying vec3 local_position;
varying vec3 column_origin;
varying vec3 world_position;

float hash_column(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise_column(vec2 p){
	vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(hash_column(i),hash_column(i+vec2(1,0)),u.x),mix(hash_column(i+vec2(0,1)),hash_column(i+vec2(1,1)),u.x),u.y);
}

void vertex(){
	local_position=VERTEX;
	column_origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	if(terrain_morph_progress<1.0){vec3 origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;VERTEX+=(inverse(MODEL_MATRIX)*vec4(0.0,terrain_morph_offset(origin),0.0,0.0)).xyz;}
}

void fragment(){
	// Flat facets of this solid, facing the viewer.
	vec3 facet=normalize(cross(dFdx(VERTEX),dFdy(VERTEX)));
	if(dot(facet,VERTEX)>0.0)facet=-facet;
	NORMAL=facet;
	vec3 world_normal=(INV_VIEW_MATRIX*vec4(facet,0.0)).xyz;
	vec3 variation=rock_hash(floor(column_origin*2.3)+vec3(17.0));
	// Facet shade from the source stone, softened; instance tone sets the block.
	vec3 stone=cliff_gray(.25+.6*variation.x)*mix(vec3(1.0),COLOR.rgb/.66,.55);
	// Vertical weathering streaks run the height of this body.
	vec2 q=vec2(local_position.x*6.0+local_position.z*6.0+variation.y*19.0,local_position.y*2.6);
	float streak=noise_column(q)*.6+noise_column(q*vec2(2.7,1.9)+vec2(4.1,7.3))*.4;
	stone*=.90+.20*streak;
	stone*=mix(.80,1.0,smoothstep(-.85,.25,world_normal.y));
	// Metres below this body's crown. The foot is the same solid, just darker.
	float below=column_origin.y-world_position.y;
	stone*=mix(1.0,.78,smoothstep(1.6,4.2,below));
	float up=world_normal.y;
	// Moss creeps over the bevel and hangs in a ragged fringe down the face.
	float ragged=noise_column(vec2((world_position.x+world_position.z)*3.1,variation.z*7.0))*.65+noise_column(vec2((world_position.x-world_position.z)*9.0,3.0))*.35;
	// Moss stays on the crown. A long fringe painted a green lip on every course.
	float fringe=1.0-smoothstep(.02+.10*ragged,.10+.18*ragged,below);
	float moss=max(smoothstep(.15,.55,up)*(1.0-smoothstep(.25,.70,below)),fringe*.80);
	vec3 moss_color=vec3(.40,.45,.27);
	vec3 color=mix(stone,moss_color,moss*(.70+.30*streak));
	// The crown is the lawn itself, lit like the cap beside it.
	float footprint=length(fwidth(world_position.xz))*9.0;
	float detail=1.0-smoothstep(.35,1.0,footprint);
	vec2 slope=vec2(0.0);
	vec3 lawn=color;
	float crown=smoothstep(.45,.78,up)*(1.0-smoothstep(.30,.60,below));
	if(crown>0.0)lawn=ground_cover(world_position.xz,detail,slope);
	ALBEDO=mix(color,lawn,crown);
	vec3 lawn_normal=normalize(vec3(-slope.x*cover_relief*detail,1.0,-slope.y*cover_relief*detail));
	NORMAL=normalize(mix(NORMAL,(VIEW_MATRIX*vec4(lawn_normal,0.0)).xyz,crown));
	ROUGHNESS=mix(.93,.95,crown);
	SPECULAR=mix(.16,.30,crown);
}
