shader_type spatial;
#include "terrain_morph.gdshaderinc"
render_mode cull_disabled;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform vec2 shore_origin = vec2(0.0);
uniform vec2 shore_extent = vec2(1.0);
uniform vec3 water_deep : source_color = vec3(.10,.35,.34);
varying vec3 world_position;

float hash_water(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * .1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// A continuous height and its exact XZ derivatives. Unlike directional sine
// waves, its slopes cannot align a whole lake into equally spaced bands.
vec3 height_gradient(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 blend = f*f*(3.0-2.0*f);
	vec2 derivative = 6.0*f*(1.0-f);
	float a = hash_water(cell);
	float b = hash_water(cell+vec2(1.0,0.0));
	float c = hash_water(cell+vec2(0.0,1.0));
	float d = hash_water(cell+vec2(1.0,1.0));
	float cross_term = a-b-c+d;
	float height = a+(b-a)*blend.x+(c-a)*blend.y+cross_term*blend.x*blend.y;
	vec2 gradient = derivative*vec2(b-a+cross_term*blend.y,c-a+cross_term*blend.x);
	return vec3(height,gradient);
}

// Forward+ uses reverse-Z depth in [0,1], as the existing soft-spray shader.
vec3 scene_position(vec2 uv,mat4 inv_projection,mat4 inv_view){
 float depth=texture(depth_texture,uv).r;
 vec4 local=inv_projection*vec4(uv*2.0-1.0,depth,1.0);
 return (inv_view*vec4(local.xyz/local.w,1.0)).xyz;
}

void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float morph=terrain_morph_offset(world_position);
 VERTEX.y+=morph;world_position.y+=morph;
}

void fragment(){
 vec2 p=world_position.xz;
 vec4 basin=texture(shore_field,(p-shore_origin)/shore_extent);
 mat2 turn=mat2(vec2(.80,.60),vec2(-.60,.80));
 vec3 broad=height_gradient(p*.95+vec2(TIME*.055,-TIME*.043));
 vec3 small=height_gradient(turn*p*2.8+vec2(-TIME*.08,TIME*.061)+vec2(17.3,5.8));
 vec3 fine=height_gradient(p*6.4+vec2(TIME*.03,-TIME*.07)+vec2(2.1,31.7));
 vec2 slope=broad.yz*.040+transpose(turn)*small.yz*.034+fine.yz*.013;
 slope*=mix(.50,1.0,smoothstep(.015,.35,basin.r));
 vec3 impact=height_gradient(p*4.1+vec2(TIME*.30,TIME*1.25)+vec2(41.2,7.3));
 slope+=impact.yz*.09*basin.b;
 vec3 normal_world=normalize(vec3(-slope.x,1.0,-slope.y));
 vec3 normal_view=normalize((VIEW_MATRIX*vec4(normal_world,0.0)).xyz);
 NORMAL=normal_view;
 vec3 view_world=normalize(CAMERA_POSITION_WORLD-world_position);
 vec3 behind=scene_position(SCREEN_UV,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
 float vertical_depth=clamp(world_position.y-behind.y,.01,4.0);
 vec2 bend=normal_view.xy*.012*min(vertical_depth,1.4);
 vec2 bent_uv=clamp(SCREEN_UV+bend,vec2(.001),vec2(.999));
 vec3 bent_position=scene_position(bent_uv,INV_PROJECTION_MATRIX,INV_VIEW_MATRIX);
 // Refraction cannot pull foreground lawn or the cloud sea over a bank.
 float bent_wet=texture(shore_field,(bent_position.xz-shore_origin)/shore_extent).a;
 bool valid=bent_wet>.45 && bent_position.y<world_position.y-.015 && bent_position.y>world_position.y-5.0 && abs(bent_position.y-behind.y)<.20;
 vec2 sample_uv=valid?bent_uv:SCREEN_UV;
 if(valid)vertical_depth=clamp(world_position.y-bent_position.y,.01,4.0);
 float path=vertical_depth/max(abs(view_world.y),.25);
 vec3 transmission=exp(-vec3(1.35,.35,.23)*path);
 vec3 bed=texture(screen_texture,sample_uv).rgb;
 vec3 color=bed*transmission+water_deep*(vec3(1.0)-transmission)*.65;
 float fresnel=.02+.60*pow(1.0-max(dot(view_world,normal_world),0.0),5.0);
 color=mix(color,vec3(.38,.49,.43),basin.b*basin.b*.04);
 // The opaque buffer already lights the actual submerged terrain. Re-lighting
 // it as diffuse water would flatten the bank shadows and mineral relief.
 ALBEDO=vec3(0.0);
 EMISSION=color*(1.0-fresnel);
 ALPHA=1.0;
 METALLIC=0.0;ROUGHNESS=.075+basin.b*.13;SPECULAR=.60;
}
