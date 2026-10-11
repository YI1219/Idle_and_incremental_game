shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
#include "land_palette.gdshaderinc"
// Separate crown/root solids: local y=0 anchors each body's own shoulder.
// Crown tops are baked into the shared terrain surface; this material shades
// the independent side bodies and the separately tapered roots.
uniform float crown_cover = 1.0;
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
	// A narrow rounded lighting response calms the knife-edge without
 // moving cap vertices or adding a coloured perimeter band.
 float edge_soft=crown_cover*(1.0-smoothstep(.015,.22,column_origin.y-world_position.y));
 vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
 NORMAL=normalize(mix(facet,up,edge_soft*.38));
	vec3 world_normal=(INV_VIEW_MATRIX*vec4(facet,0.0)).xyz;
	vec3 variation=rock_hash(floor(column_origin*2.3)+vec3(17.0));
	// Facet shade from the source stone, softened; instance tone sets the block.
	vec3 stone=stone_surface(world_position)*(.96+.08*variation.x)*mix(vec3(1.0),COLOR.rgb/.66,.65);
	// Vertical weathering streaks run the height of this body.
	vec2 q=vec2(local_position.x*6.0+local_position.z*6.0+variation.y*19.0,local_position.y*2.6);
	float streak=noise_column(q)*.6+noise_column(q*vec2(2.7,1.9)+vec2(4.1,7.3))*.4;
	stone*=.96+.08*streak;
	stone*=mix(.87,1.0,smoothstep(-.85,.25,world_normal.y));
	// Metres below this body's shoulder; lower facets weather darker.
	float below=column_origin.y-world_position.y;
	stone*=mix(1.0,.86,smoothstep(1.6,4.2,below));
 ALBEDO=stone;
	ROUGHNESS=.93;
	SPECULAR=.16;
	float seam=smoothstep(.28,.49,abs(local_position.x))*(1.0-smoothstep(-.5,-.05,local_position.y));
 AO=mix(1.0,.77,crown_cover*max(seam,(1.0-smoothstep(-.65,-.25,local_position.y))*.6));
}
