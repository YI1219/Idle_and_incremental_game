shader_type spatial;
#include "cliff_palette.gdshaderinc"
#include "land_palette.gdshaderinc"
// Standing stone columns that clad broad outer walls below the turf lip.
// Mesh space is a unit box with its top at y=0 and its foot at y=-1.
varying vec3 local_position;
varying vec3 column_origin;
varying vec3 world_normal;

float hash_column(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise_column(vec2 p){
	vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);
	return mix(mix(hash_column(i),hash_column(i+vec2(1,0)),u.x),mix(hash_column(i+vec2(0,1)),hash_column(i+vec2(1,1)),u.x),u.y);
}

void vertex(){
	local_position=VERTEX;
	column_origin=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment(){
	vec3 variation=rock_hash(floor(column_origin*2.3)+vec3(17.0));
	// Facet shade from the source stone, softened; instance tone sets the block.
	vec3 stone=cliff_gray(.25+.6*variation.x)*mix(vec3(1.0),COLOR.rgb/.66,.55);
	// Vertical weathering streaks run the height of each block.
	vec2 q=vec2(local_position.x*6.0+local_position.z*6.0+variation.y*19.0,local_position.y*2.6);
	float streak=noise_column(q)*.6+noise_column(q*vec2(2.7,1.9)+vec2(4.1,7.3))*.4;
	stone*=.90+.20*streak;
	// The foot of each block sits in the shadow of the mass below the lip.
	stone*=mix(.78,1.0,smoothstep(-1.0,-.45,local_position.y));
	stone*=mix(.80,1.0,smoothstep(-.85,.25,world_normal.y));
	// Moss on the block tops and a ragged fringe just under the turf.
	float fringe=smoothstep(-.10-.08*noise_column(vec2(local_position.x*9.0+variation.z*5.0,3.0)),-.01,local_position.y);
	float moss=max(smoothstep(.45,.80,world_normal.y),fringe*.55);
	vec3 moss_color=mix(grass_base,grass_highlight,.35)*.82;
	ALBEDO=mix(stone,moss_color,moss*(.65+.35*streak));
	ROUGHNESS=.93;
	SPECULAR=.16;
}
