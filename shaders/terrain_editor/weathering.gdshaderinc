#ifndef TERRAIN_WEATHERING_INCLUDED
#define TERRAIN_WEATHERING_INCLUDED
// Shared world-space deposits. Large uneven patches carry the material read;
// smaller grains break their margins without drawing an edge-distance stripe.
float tw_hash(vec3 p){
 p=fract(p*vec3(.1031,.11369,.13787));p+=dot(p,p.yxz+19.19);
 return fract((p.x+p.y)*p.z);
}
float tw_noise(vec3 p){
 vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(tw_hash(i),tw_hash(i+vec3(1,0,0)),f.x),mix(tw_hash(i+vec3(0,1,0)),tw_hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(tw_hash(i+vec3(0,0,1)),tw_hash(i+vec3(1,0,1)),f.x),mix(tw_hash(i+vec3(0,1,1)),tw_hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
vec3 tw_deposits(vec3 p){
 float broad=tw_noise(p*.68+vec3(7.3,2.1,11.7));
 float broken=tw_noise(p*3.2+vec3(17.1,5.3,3.2));
 float grain=tw_noise(p*17.0+vec3(2.3,9.1,31.7));
 return vec3(smoothstep(.49,.68,broad*.55+broken*.30+grain*.15),smoothstep(.53,.73,broken*.60+grain*.40),smoothstep(.62,.79,grain*.65+broken*.35));
}
// Warm beige-grey soil. Shared by the path, open wear and the grass-stone shoulder
// so those joints sit in one matte family instead of a separate brown scar.
vec3 tw_soil(vec2 p){
 float tone=tw_noise(vec3(p.x*.70,1.5,p.y*.70));
 return mix(vec3(.40,.36,.30),vec3(.50,.45,.37),tone);
}
#endif
