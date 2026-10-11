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
 float lawn=sin(p.x*.51+p.y*.22)*sin(p.y*.47-p.x*.18)*.5+.5;
 vec2 slope;
 vec3 grass=ground_cover(p,1.0-smoothstep(.35,1.0,length(fwidth(p))*9.0),slope);
 vec3 earth=COLOR.rgb*mix(vec3(.92,.98,.89),vec3(1.06,1.02,.94),broad);
 ALBEDO=mix(grass,earth,smoothstep(.12,.95,COLOR.a*(.70+.45*gc_noise(p*4.0))));
 ROUGHNESS=.88;
 SPECULAR=.15;
}
