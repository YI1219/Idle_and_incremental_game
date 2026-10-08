shader_type spatial;
render_mode unshaded,blend_mix,depth_draw_never,cull_disabled,shadows_disabled,fog_disabled;
#include "sky_palette.gdshaderinc"
// One flat, world-anchored layer of the cloud sea. Two texture taps form the
// billows and one offset tap toward the sun shades their lit and shadowed sides.
uniform sampler2D billow : filter_linear_mipmap, repeat_enable;
uniform vec3 sun_direction = vec3(.56,.50,-.66);
uniform float uv_scale = .0016;
uniform vec2 uv_offset = vec2(0.0);
uniform float coverage = .48;
uniform float opacity = .92;
uniform float aerial_density = .0010;
uniform float fade_radius = 1500.0;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float shape(vec2 uv){return texture(billow,uv).r*.72+texture(billow,uv*3.1+vec2(.37,.11)).r*.28;}
void fragment(){
 vec2 uv=world_position.xz*uv_scale+uv_offset+vec2(TIME*.0012,TIME*.0005);
 float body=shape(uv);
 float toward_sun=shape(uv+normalize(sun_direction.xz)*.018);
 float density=smoothstep(coverage,coverage+.10,body);
 float thick=smoothstep(coverage,coverage+.30,body);
 // Billow sides facing the sun brighten; the far sides and thin rims fall
 // into a soft grey shadow, so stacked layers stay separable.
 float lit=clamp(.45+(body-toward_sun)*14.0,0.0,1.0);
 vec3 shade=vec3(.62,.56,.53);
 vec3 sunlit=vec3(1.0,.89,.72);
 vec3 color=mix(shade,sunlit,clamp(lit*.70+thick*.45-.10,0.0,1.0));
 vec3 view=world_position-CAMERA_POSITION_WORLD;
 float distance=length(view);
 vec2 p=sky_coord(view/distance);
 float aerial=1.0-exp(-distance*aerial_density);
 aerial=mix(aerial,1.0,exp(-sky_sun_distance(p)*3.5)*.40);
 ALBEDO=mix(color,sky_gradient(p),clamp(aerial,0.0,.90));
 float horizontal=length(world_position.xz-NODE_POSITION_WORLD.xz);
 // Like the painted backdrop clouds, the sea thins out toward the horizon
 // band by view elevation, leaving the upper sky, sun and far peaks clear.
 float horizon=smoothstep(.12,.40,p.y);
 ALPHA=density*opacity*horizon*(1.0-smoothstep(fade_radius*.55,fade_radius,horizontal));
}
