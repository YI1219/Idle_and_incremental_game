shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
render_mode cull_disabled;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=terrain_morph_offset(world_position);}
void fragment(){
 float broad=.5+.5*sin(world_position.x*.71+sin(world_position.z*.63));
 vec2 p=world_position.xz;
 vec2 slope;
 vec3 grass=ground_cover(p,1.0-smoothstep(.35,1.0,length(fwidth(p))*9.0),slope);
 // Only the inner bank is damp. The outer feather uses exactly the lawn
 // function, while mineral flecks break up the damp earth at the waterline.
 float wet=(1.0-smoothstep(.015,.34,world_position.y-UV.x))*UV.y;
 float grit=gc_noise(p*14.0);
 float pebbles=gc_noise(p*7.5+vec2(2.0,9.0));
 vec3 earth=mix(vec3(.40,.42,.29),vec3(.51,.50,.36),broad);
 earth*=mix(1.0,.82,wet);
 earth=mix(earth,vec3(.57,.57,.47),smoothstep(.66,.83,grit)*.22);
 earth=mix(earth,vec3(.55,.56,.50),smoothstep(.62,.84,pebbles)*.16);
 ALBEDO=mix(grass,earth,smoothstep(.06,.78,COLOR.a*(.55+.40*gc_noise(p*2.6))));
 vec3 n=normalize(vec3(-slope.x*.42,1.0,-slope.y*.42));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
 ROUGHNESS=mix(.94,.74,wet);
 SPECULAR=.15;
}
