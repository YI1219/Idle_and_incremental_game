shader_type sky;
#include "sky_palette.gdshaderinc"
uniform sampler2D cloud_backdrop : source_color, filter_linear_mipmap, repeat_enable;
uniform float haze : hint_range(0.0,1.0) = .65;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x),u.y);}
void sky(){
 if(AT_CUBEMAP_PASS){
  // Radiance for water and other reflections uses the visible warm sky.
  float cloud=noise(EYEDIR.xz*17.0);
  COLOR=sky_gradient(sky_coord(EYEDIR))*(.90+.14*cloud);
 }else{
  vec2 p=sky_coord(EYEDIR);
  vec3 color=sky_gradient(p);
  float cirrus=smoothstep(.55,.69,noise(p*vec2(8,110))+noise(p*vec2(23,210))*.15);
  color=mix(color,vec3(1.0,.91,.78),cirrus*.06*(1.0-smoothstep(.3,.5,p.y)));
  vec2 uv=vec2(p.x*.85,.20+p.y*.80);
  vec3 source=textureLod(cloud_backdrop,uv,1.0).rgb;
  float density=smoothstep(.10,.65,source.r);
  float cloud_light=smoothstep(.24,.88,source.r);
  vec3 cloud_color=mix(vec3(.54,.62,.70),vec3(.97,.94,.86),cloud_light);
  float sun=sky_sun_distance(p);
  cloud_color+=vec3(.12,.08,.03)*exp(-sun*5.0);
  color=mix(color,cloud_color,density*smoothstep(.14,.60,p.y)*(.92+(haze-.65)*.12));
  COLOR=mix(color,SKY_SUN_CORE,sky_sun_disc(p));
 }
}
