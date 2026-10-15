shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "land_palette.gdshaderinc"
#include "ground_cover.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D stone_mineral_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
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
 vec3 earth=mix(vec3(.25,.28,.20),vec3(.38,.37,.26),broad);
 earth*=mix(1.0,.78,wet);
 earth=mix(earth,vec3(.57,.57,.47),smoothstep(.66,.83,grit)*.28);
 vec3 mineral=textureLod(stone_mineral_map,p*.28,1.5).rgb*vec3(.80,.83,.72);
 vec3 damp=mix(earth,mineral,.65)*.82;
 float cover=smoothstep(.12,.95,COLOR.a*(.70+.45*gc_noise(p*4.0)));
 ALBEDO=mix(grass,mix(earth,damp,wet),max(cover,wet*.90));
 vec3 n=normalize(vec3(-slope.x*.2,1.0,-slope.y*.2));
 NORMAL=normalize(mix(NORMAL,(VIEW_MATRIX*vec4(n,0.0)).xyz,.25));
 ROUGHNESS=mix(.94,.74,wet);
 SPECULAR=.15;
}
