shader_type sky;
uniform sampler2D cloud_backdrop : source_color, filter_linear_mipmap, repeat_disable;
void sky(){
 if(AT_CUBEMAP_PASS){
  // Neutral lighting remains stable during camera panning and wheel zoom.
  COLOR=mix(vec3(.67,.84,.95),vec3(.35,.70,.90),smoothstep(-1.0,.6,EYEDIR.y));
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
