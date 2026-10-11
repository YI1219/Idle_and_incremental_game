shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
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
	NORMAL=facet;
	vec3 world_normal=(INV_VIEW_MATRIX*vec4(facet,0.0)).xyz;
	vec3 variation=rock_hash(floor(column_origin*2.3)+vec3(17.0));
	// Facet shade from the source stone, softened; instance tone sets the block.
	vec3 stone=(cliff_gray(.25+.6*variation.x)+vec3(.065,.075,.085))*mix(vec3(1.0),COLOR.rgb/.66,mix(.55,.85,crown_cover));
	// World-scale triplanar mineral clouds; no unique UV textures. Blended
 // projections avoid stretched streaks on sides with different orientations.
 vec3 blend=pow(abs(world_normal),vec3(4.0));blend/=max(dot(blend,vec3(1.0)),.001);
 vec3 p=world_position*.85;
 float cloud=noise_column(p.yz+vec2(11,3))*blend.x+noise_column(p.xz+vec2(5,17))*blend.y+noise_column(p.xy+vec2(23,7))*blend.z;
 float fine=noise_column(world_position.xy*7.0)*blend.z+noise_column(world_position.zy*7.0)*blend.x+noise_column(world_position.xz*7.0)*blend.y;
 float warm=noise_column(world_position.xz*.63+world_position.y*.2)-.5;
 stone+=crown_cover*((cloud-.5)*vec3(.13,.14,.16)+warm*vec3(.065,.018,-.05)+(fine-.5)*.025);
 // Broad, low-contrast mineral patches; no textures or extra draw calls.
	float mineral=noise_column(local_position.xz*4.0+local_position.y*2.0+variation.xy*11.0);
	stone+=crown_cover*(mineral-.5)*vec3(.045,.055,.075);
	// Vertical weathering streaks run the height of this body.
	vec2 q=vec2(local_position.x*6.0+local_position.z*6.0+variation.y*19.0,local_position.y*2.6);
	float streak=noise_column(q)*.6+noise_column(q*vec2(2.7,1.9)+vec2(4.1,7.3))*.4;
	stone*=.90+.20*streak;
	stone*=mix(.80,1.0,smoothstep(-.85,.25,world_normal.y));
	// Metres below this body's shoulder; lower facets weather darker.
	float below=column_origin.y-world_position.y;
	stone*=mix(1.0,.78,smoothstep(1.6,4.2,below));
 // A ragged, shallow green spill coats the vertical stone. It is albedo
 // only: no shoulder geometry, and roots keep their existing stone finish.
 float fringe=noise_column(world_position.xz*3.2)*.65+noise_column(world_position.xz*8.5)*.35;
 float spill=crown_cover*(1.0-smoothstep(.06+.11*fringe,.13+.21*fringe,below));
 spill*=mix(.22,1.0,smoothstep(.24,.68,noise_column(world_position.xz*.9)));
 vec3 green=mix(grass_base,grass_highlight,.48+fringe*.28)*vec3(.98,1.0,.93);
 ALBEDO=mix(stone,green,spill*.30);
	ROUGHNESS=.93;
	SPECULAR=.16;
	float seam=smoothstep(.28,.49,abs(local_position.x))*(1.0-smoothstep(-.5,-.05,local_position.y));
 AO=mix(1.0,.77,crown_cover*max(seam,(1.0-smoothstep(-.65,-.25,local_position.y))*.6));
}
