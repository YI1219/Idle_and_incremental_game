shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 moss_color : source_color = vec4(0.34,0.43,0.33,1.0);
uniform vec4 meadow_color : source_color = vec4(0.48,0.54,0.37,1.0);
uniform vec4 path_color : source_color = vec4(0.64,0.59,0.44,1.0);
uniform vec4 path_segments[8];
uniform int path_count = 0;
uniform vec4 contact_patches[32];
uniform int contact_count = 0;
varying vec3 world_pos;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float segment_distance(vec2 p, vec2 a, vec2 b) {
 vec2 d=b-a; return length(p-a-d*clamp(dot(p-a,d)/max(dot(d,d),0.001),0.0,1.0));
}
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world_pos.xz;
 float broad=noise(p*0.36)*0.65+noise(p*0.85)*0.35;
 float detail=noise(p*16.0);
 vec3 grass=mix(moss_color.rgb,meadow_color.rgb,smoothstep(0.2,0.8,broad));
 grass += (detail-0.5)*0.025;
 float path=0.0;
 for(int i=0;i<8;i++) { if(i>=path_count) break; float d=segment_distance(p,path_segments[i].xy,path_segments[i].zw); path=max(path,1.0-smoothstep(0.35,1.15,d+(noise(p*2.8)-0.5)*0.42)); }
 vec3 soil=path_color.rgb*(0.92+detail*0.13);
 vec3 color=mix(grass,soil,path*0.78);
 for(int i=0;i<32;i++) { if(i>=contact_count) break; vec4 patch=contact_patches[i]; float d=length(p-patch.xy)/patch.z; float root=(1.0-smoothstep(0.1,1.0,d+(noise(p*4.0)-0.5)*0.2))*patch.w; color=mix(color,moss_color.rgb*0.72,root); }
 ALBEDO=color; ROUGHNESS=0.94;
}
