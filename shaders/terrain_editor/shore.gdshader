shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
render_mode cull_disabled;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=terrain_morph_offset(world_position);}
void fragment(){
	vec2 p=world_position.xz;
	vec2 slope;
	vec3 grass=lawn_color(p,1.0-smoothstep(55.0,120.0,length(VERTEX)),slope);
	// The outer feather stays lawn. Toward the water the bank darkens into
	// damp olive soil, with a broken moss fleck where it has settled.
	float bank=smoothstep(0.0,1.0,COLOR.a);
	float above=world_position.y-UV.x;
	float wet=(1.0-smoothstep(0.0,1.05,above))*bank;
	float grit=gc_noise(p*1.6);
	vec3 soil=grass*mix(vec3(.44,.42,.34),vec3(.60,.68,.58),grit);
	soil=mix(soil,soil*vec3(.68,.80,.84),smoothstep(.28,1.0,wet)*.72);
	float earth=smoothstep(0.0,.48,bank)*smoothstep(0.0,.42,wet+gc_noise(p*.7)*.30);
	earth=min(earth,.90);
	vec3 color=mix(grass,soil,earth);
	float moss=smoothstep(.18,.48,wet)*(1.0-smoothstep(.55,.90,wet));
	moss*=smoothstep(.28,.72,gc_noise(p*1.15+vec2(2.0,4.0)));
	color=mix(color,color*vec3(.72,.96,.76),moss*.62);
	color*=mix(1.0,.68,smoothstep(.32,1.0,wet)*.82);
	ALBEDO=color;
	vec3 n=lawn_normal(vec3(0.0,1.0,0.0),slope,1.0,.42);
	NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
	ROUGHNESS=mix(.99,.72,wet);
	SPECULAR=mix(.03,.08,wet);
}
