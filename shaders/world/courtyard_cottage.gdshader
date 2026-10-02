shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D original_texture : source_color, filter_linear_mipmap_anisotropic;
varying vec3 local_pos;
varying vec3 local_normal;
void vertex() { local_pos=VERTEX; local_normal=NORMAL; }
void fragment() {
 vec3 original=texture(original_texture,UV).rgb;
 float roof=smoothstep(2.0,2.5,local_pos.y)*smoothstep(0.15,0.6,abs(local_normal.y));
 // Fine roof courses live in asset space and travel with this cottage.
 float course=abs(sin(local_pos.z*22.0));
 float seam=1.0-smoothstep(0.015,0.11,course);
 float panel=sin(local_pos.z*6.6)*0.018+sin(local_pos.x*14.0+local_pos.z*1.4)*0.009;
 ALBEDO=original*(1.0+roof*(panel-seam*0.065));
 ROUGHNESS=0.87; SPECULAR=0.22;
}
