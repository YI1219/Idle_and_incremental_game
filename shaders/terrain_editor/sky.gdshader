shader_type sky;
// Fixed-camera, inexpensive layered ink-wash silhouettes. No scene buildings,
// foreground cards, fog volume or particles are involved. The retained cloud
// texture supplies only broad cloud density, recolored below.
uniform sampler2D cloud_backdrop : source_color, filter_linear_mipmap, repeat_disable;
uniform float haze : hint_range(0.0,1.0) = .65;
uniform vec3 sky_top : source_color = vec3(.68,.75,.77);
uniform vec3 ivory : source_color = vec3(.937,.894,.816);
uniform vec3 mountain_color : source_color = vec3(.627,.694,.694);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);vec2 u=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),u.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),u.x),u.y);}
float peak(float x,float center,float width,float height){
 float t=abs((x-center)/width);
 return height*pow(max(0.0,1.0-t),.45);
}
void sky(){
 if(AT_CUBEMAP_PASS){
  COLOR=mix(ivory,sky_top,smoothstep(-.1,.6,EYEDIR.y));
 }else{
  vec2 p=SCREEN_UV;
  vec3 color=mix(sky_top,ivory,smoothstep(.0,.68,p.y));
  float sun=1.0-smoothstep(.042,.044,length((p-vec2(.877,.14))*vec2(1.7768,1.0)));
  color=mix(color,vec3(.96,.83,.57),sun*.72);
  for(int i=0;i<3;i++){
   float layer=float(i);
   float x=p.x+layer*.173;
   float ridge=max(peak(x,.06,.073,.20),peak(x,.12,.046,.14));
   ridge=max(ridge,max(peak(x,.44,.065,.17),peak(x,.50,.045,.12)));
   ridge=max(ridge,max(peak(x,.70,.060,.18),peak(x,.76,.040,.13)));
   ridge=max(ridge,max(peak(x,1.14,.08,.20),peak(x,1.22,.05,.13)));
   float facet=(abs(fract(x*67.0+layer*3.7)-.5)*.009+abs(fract(x*57.0)-.5)*.012)*smoothstep(.02,.10,ridge);
   float horizon=.32+layer*.19;
   float silhouette=smoothstep(horizon-ridge+facet-.002,horizon-ridge+facet+.002,p.y);
   silhouette*=smoothstep(.0,.025,ridge);
   float fade=1.0-smoothstep(horizon-.04,horizon+.10,p.y);
   vec3 ink=mix(mountain_color,sky_top,.30-layer*.06);
   ink=mix(ink,sky_top,.35-layer*.10+haze*.15);
   float plane=noise(vec2(floor(x*55.0),layer*7.0));
   ink*=.97+plane*.05;
   color=mix(color,ink,silhouette*fade*(.68+layer*.10));
  }
  // Reuse the existing cloud-only source as soft monochrome billows. Warm
  // tops / cool shade replace its cyan sky without a fullscreen scene filter.
  vec3 source=textureLod(cloud_backdrop,vec2(p.x,.20+p.y*.80),2.0).rgb;
  float density=smoothstep(.12,.65,source.r);
  float cloud_light=smoothstep(.32,.93,source.r);
  vec3 cloud_color=mix(mix(sky_top,ivory,.38),ivory,cloud_light);
  float sea=smoothstep(.30,.83,p.y);
  color=mix(color,mix(sky_top,ivory,.52),sea*.18);
  color=mix(color,cloud_color,density*(.80+haze*.18));
  // Thin horizontal haze binds the peaks into the sea, leaving the island clear.
  float mist=noise(vec2(p.x*5.0,p.y*25.0));
  color=mix(color,ivory,smoothstep(.55,.82,mist)*.10*sea);
  COLOR=color;
 }
}
