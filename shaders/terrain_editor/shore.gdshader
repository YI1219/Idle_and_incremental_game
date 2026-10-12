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
 vec3 grass=ground_cover(p,1.0-smoothstep(.35,1.0,length(fwidth(p))*9.0),slope);
 // The outer feather stays lawn. Damp soil appears only on the last soft
 // stretch into the water, with a noisy edge instead of a hard colour band.
 float bank=smoothstep(0.0,1.0,COLOR.a);
 float wet=(1.0-smoothstep(.02,.50,world_position.y-UV.x))*bank;
 float grit=gc_noise(p*6.2);
 vec3 soil=mix(vec3(.32,.30,.23),vec3(.40,.36,.27),grit);
 soil=mix(soil,soil*vec3(.76,.84,.82),wet*.5);
 float earth=smoothstep(.05,.78,bank)*smoothstep(.08,.75,wet+gc_noise(p*1.7)*.38);
 ALBEDO=mix(grass,soil,earth);
 vec3 n=normalize(vec3(-slope.x*.5,1.0,-slope.y*.5));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 ROUGHNESS=mix(.98,.84,wet);
 SPECULAR=mix(.03,.07,wet);
}
