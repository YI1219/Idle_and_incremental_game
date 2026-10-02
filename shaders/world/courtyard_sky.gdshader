shader_type sky;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void sky() {
 float h=EYEDIR.y;
 vec3 color=mix(vec3(0.43,0.58,0.60),vec3(0.14,0.26,0.34),smoothstep(-0.25,0.8,h));
 vec2 p=EYEDIR.xz/max(0.12,abs(h)+0.22)*2.0;
 float cloud=noise(p)*0.6+noise(p*2.1)*0.27+noise(p*4.2)*0.13;
 color=mix(color,vec3(0.64,0.68,0.62),smoothstep(0.43,0.74,cloud)*0.65);
 COLOR=color;
}
