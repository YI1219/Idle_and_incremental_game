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
 float wet=(1.0-smoothstep(.025,.105,world_position.y-UV.x))*UV.y;
 float grit=gc_noise(p*14.0);
 vec3 earth=mix(vec3(.40,.42,.29),vec3(.51,.50,.36),broad);
 earth*=mix(1.0,.78,wet);
 earth=mix(earth,vec3(.57,.57,.47),smoothstep(.66,.83,grit)*.28);
 ALBEDO=mix(grass,earth,smoothstep(.12,.95,COLOR.a*(.70+.45*gc_noise(p*4.0))));
 ROUGHNESS=mix(.94,.74,wet);
 SPECULAR=.15;
}
