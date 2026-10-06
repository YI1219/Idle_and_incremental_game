shader_type sky;
uniform sampler2D cloud_backdrop : source_color, filter_linear_mipmap, repeat_disable;
void sky(){
 if(AT_CUBEMAP_PASS){
  // Static directional sky radiance, sampled by the dielectric water BRDF.
  // This reflects sky only, not cottage/trees or other scene geometry.
  // The source is a cloud illustration, not an equirectangular panorama.
  // Map its lower cloud layer onto the horizon of an authored sky hemisphere.
  vec2 sky_uv=vec2(atan(EYEDIR.x,EYEDIR.z)/TAU+.5,.86-.45*max(EYEDIR.y,0.0));
  vec3 clouds=textureLod(cloud_backdrop,sky_uv,4.0).rgb;
  float cloud=smoothstep(.58,.88,dot(clouds,vec3(.2126,.7152,.0722)));
  vec3 clear=mix(vec3(.56,.75,.86),vec3(.20,.48,.72),smoothstep(-.1,.85,EYEDIR.y));
  COLOR=mix(clear,vec3(.92,.96,1.0),cloud*.85);
 }else{
  // Camera orientation is fixed; the generated cloud-only backdrop fills the
  // sky, while all editable scene objects remain real 3D geometry.
  // Broad cloud masses keep their shape while high-frequency billows soften.
  vec2 spread=vec2(.0020);
  vec3 cloud=textureLod(cloud_backdrop,SCREEN_UV,2.5).rgb*.4;
  cloud+=textureLod(cloud_backdrop,SCREEN_UV+vec2(spread.x,0.0),2.5).rgb*.15;
  cloud+=textureLod(cloud_backdrop,SCREEN_UV-vec2(spread.x,0.0),2.5).rgb*.15;
  cloud+=textureLod(cloud_backdrop,SCREEN_UV+vec2(0.0,spread.y),2.5).rgb*.15;
  cloud+=textureLod(cloud_backdrop,SCREEN_UV-vec2(0.0,spread.y),2.5).rgb*.15;
  float clear_sky=1.0-smoothstep(.55,.9,dot(cloud,vec3(.2126,.7152,.0722)));
  cloud=mix(cloud,vec3(.91,.94,.96),.20);
  COLOR=mix(cloud,vec3(.56,.84,.91),clear_sky*.65);
 }
}
