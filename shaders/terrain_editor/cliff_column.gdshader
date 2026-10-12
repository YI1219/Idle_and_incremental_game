shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
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
 vec3 material_normal=normalize(cross(dFdx(world_position),dFdy(world_position)));
 vec3 authored=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 if(dot(material_normal,authored)<0.0)material_normal=-material_normal;
	// Facet shading follows the authored outward normal. A test against the
	// view-space position flips grazing convex cuts and lights them as pits.
	vec3 facet=normalize(cross(dFdx(VERTEX),dFdy(VERTEX)));
	if(dot(facet,normalize(NORMAL))<0.0)facet=-facet;
	// A narrow rounded lighting response calms the knife-edge without
 // moving cap vertices or adding a coloured perimeter band.
 float edge_soft=crown_cover*(1.0-smoothstep(.015,.22,column_origin.y-world_position.y));
 vec3 up=(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz;
 NORMAL=normalize(mix(facet,up,edge_soft*.38));
	vec3 world_normal=(INV_VIEW_MATRIX*vec4(facet,0.0)).xyz;
	vec3 variation=rock_hash(floor(column_origin*1.3)+vec3(17.0));
	// One value for the whole block, with a small warm or cool shift.
	// Face tint stays quiet so a flat cut does not break into wedges.
	vec3 stone=stone_surface(world_position,material_normal)*mix(.92,1.10,variation.x);
	stone*=mix(vec3(1.0),COLOR.rgb/.66,.22);
	stone*=mix(vec3(.98,.99,1.01),vec3(1.02,1.01,.98),variation.y);
	vec2 q=vec2(local_position.x*2.4+local_position.z*2.2+variation.y*9.0,local_position.y*1.1);
	float streak=noise_column(q)*.6+noise_column(q*vec2(1.8,1.3)+vec2(4.1,7.3))*.4;
	stone*=.96+.08*streak;
	// Sun-worn on the upper outward face. Colour only; the normal stays
	// the authored outward cut, so the crown does not scoop into a pit.
	float worn=smoothstep(.05,.72,world_normal.y)*crown_cover;
	stone=mix(stone,stone*vec3(1.12,1.10,1.06),worn*.40);
	stone*=mix(.92,1.0,smoothstep(-.85,.25,world_normal.y));
	float below=column_origin.y-world_position.y;
	stone*=mix(1.0,.90,smoothstep(1.6,4.2,below));
	// A broken cleft shadow, not a continuous course line. The face itself
	// is not bent.
	float side=max(abs(local_position.x),abs(local_position.z));
	float seam=noise_column(local_position.xz*2.6+column_origin.xz*1.7);
	float joint=smoothstep(.472,.505,side)*crown_cover*(.30+.70*seam);
	float lip=crown_cover*(1.0-smoothstep(.008,.04,-local_position.y));
	lip*=.35+.65*noise_column(column_origin.xz*2.2+local_position.xz*6.0);
	stone*=mix(1.0,.84,clamp(joint*.80+lip*.32,0.0,1.0));
	ALBEDO=cliff_weather(stone,world_position,material_normal);
	ROUGHNESS=stone_map(world_position,material_normal).a;
	SPECULAR=.08;
	AO=mix(1.0,.64,joint);
 NORMAL=normalize((VIEW_MATRIX*vec4(cliff_face_normal(world_position,material_normal),0.0)).xyz);
}
