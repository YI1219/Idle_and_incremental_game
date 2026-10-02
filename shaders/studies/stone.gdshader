shader_type spatial;
render_mode specular_disabled;
uniform vec4 tint : source_color = vec4(.55,.59,.56,1.0);
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float n=sin(wp.x*2.1+wp.y*2.8)*sin(wp.z*1.9-wp.x)*.025;ALBEDO=tint.rgb+n;ROUGHNESS=1.;}
