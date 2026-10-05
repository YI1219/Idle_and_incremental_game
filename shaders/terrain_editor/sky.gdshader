shader_type sky;
uniform sampler2D cloud_backdrop : source_color, filter_linear_mipmap, repeat_disable;
void sky(){
 if(AT_CUBEMAP_PASS){
  // Neutral lighting remains stable during camera panning and wheel zoom.
  COLOR=mix(vec3(.67,.84,.95),vec3(.35,.70,.90),smoothstep(-1.0,.6,EYEDIR.y));
 }else{
  // Camera orientation is fixed; the generated cloud-only backdrop fills the
  // sky, while all editable scene objects remain real 3D geometry.
  vec3 cloud=texture(cloud_backdrop,SCREEN_UV).rgb;
  float clear_sky=1.0-smoothstep(.55,.9,dot(cloud,vec3(.2126,.7152,.0722)));
  COLOR=mix(cloud,vec3(.53,.80,.91),clear_sky*.5);
 }
}
