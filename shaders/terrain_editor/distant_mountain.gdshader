shader_type spatial;
render_mode unshaded,depth_prepass_alpha,shadows_disabled,fog_disabled;
#include "sky_palette.gdshaderinc"
uniform vec3 sun_direction = vec3(.56,.50,-.66);
uniform float aerial_density = .0012;
varying vec3 world_position;
varying vec3 world_normal;
varying float height;
void vertex(){
 height=VERTEX.y;
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment(){
 vec3 normal=normalize(world_normal);
 float light=clamp(dot(normal,normalize(sun_direction))*.6+.4,0.0,1.0);
 vec3 stone=mix(vec3(.17,.21,.23),vec3(.46,.45,.40),light*light);
 stone*=.90+COLOR.r*.16;
 float trees=step(.90,COLOR.r);
 stone=mix(stone,mix(vec3(.12,.16,.12),vec3(.27,.30,.19),light),trees);
 vec3 view=world_position-CAMERA_POSITION_WORLD;
 float distance=length(view);
 vec2 p=sky_coord(view/distance);
 // Exponential aerial perspective toward the sky colour behind each peak:
 // farther rings and peaks near the sun dissolve into warm haze.
 float aerial=1.0-exp(-max(distance-250.0,0.0)*aerial_density);
 aerial=mix(aerial,1.0,exp(-sky_sun_distance(p)*3.5)*.40);
 // Peaks seen near the horizon band read as the farthest layers.
 aerial=mix(aerial,1.0,(1.0-smoothstep(.05,.60,p.y))*.45);
 // Lower slopes sink into the cloud sea.
 aerial=mix(aerial,1.0,(1.0-smoothstep(.0,.42,height))*.75);
 ALBEDO=mix(stone,sky_gradient(p),clamp(aerial,0.0,.97));
 // The low sun burns through the hazy far ridges instead of being clipped
 // into a crescent by whichever peak happens to overlap it.
 ALBEDO=mix(ALBEDO,SKY_SUN_CORE,sky_sun_disc(p)*.92);
 ALPHA=smoothstep(.04,.35,height);
}
