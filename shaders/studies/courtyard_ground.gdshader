shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 moss_color : source_color = vec4(0.43,0.50,0.35,1.0);
uniform vec4 meadow_color : source_color = vec4(0.52,0.57,0.40,1.0);
uniform vec4 path_color : source_color = vec4(0.62,0.60,0.48,1.0);
uniform vec4 path_segments[8];
uniform int path_count = 0;
uniform vec4 contact_patches[32];
uniform int contact_count = 0;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float sd_segment(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/max(dot(d,d),0.001),0.0,1.0));}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_pos.xz;
 float broad=noise(p*.27)*.7+noise(p*.9)*.3;
 vec3 color=mix(moss_color.rgb,meadow_color.rgb,broad);
 float path=0.;
 for(int i=0;i<8;i++){if(i>=path_count)break;float d=sd_segment(p,path_segments[i].xy,path_segments[i].zw);path=max(path,1.-smoothstep(.44,1.32,d+(noise(p*2.2)-.5)*.28));}
 float fleck=noise(p*8.);
 vec3 soil=path_color.rgb*(.96+fleck*.065);
 color=mix(color,soil,path*.94);
 for(int i=0;i<32;i++){if(i>=contact_count)break;vec4 c=contact_patches[i];float d=length(p-c.xy)/max(c.z,.01);float contact=(1.-smoothstep(.10,1.,d+(noise(p*2.)-.5)*.12))*c.w;color=mix(color,moss_color.rgb*.94,contact*.55);}
 color+=(noise(p*22.)-.5)*.012;
 ALBEDO=color;ROUGHNESS=1.;
}
