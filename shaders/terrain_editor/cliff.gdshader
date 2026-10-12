shader_type spatial;
#include "terrain_morph.gdshaderinc"
#include "cliff_palette.gdshaderinc"
#include "stone_surface.gdshaderinc"
render_mode cull_disabled;
varying vec3 world_position;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=terrain_morph_offset(world_position);
}
void fragment(){
 vec3 material_normal=normalize((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz);
 // Short closure skirts share the calm downward response of the base.
 // This avoids a bright seam where small low-foot variations turn upward.
 if(UV.y<-.5)material_normal=normalize(mix(material_normal,vec3(0.0,-1.0,0.0),.72));
 // The cap is one stone surface. Painted cell boundaries would restore the
 // patchwork read even after removing the separate extruded bottom blocks.
 ALBEDO=stone_surface(world_position,material_normal)*mix(vec3(1.0),COLOR.rgb,.35);
 ROUGHNESS=stone_map(world_position,material_normal).a;SPECULAR=.15;
 NORMAL=normalize((VIEW_MATRIX*vec4(stone_normal(world_position,material_normal),0.0)).xyz);
}
