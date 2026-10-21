#include "weathering.gdshaderinc"
// Linear RGBA: mineral value, local U/V slopes, roughness. World-space
// triplanar projection continues across independent bodies and their backing.
uniform sampler2D stone_detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_mineral_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// The packed map recalibrates the retained fine slopes to their former .07
// response, then adds local shallow spalls. This is not a fine-noise boost.
uniform float stone_relief_strength : hint_range(0.0, 1.0) = .12;
vec3 stone_weights(vec3 n){vec3 w=pow(abs(n),vec3(4.0));return w/max(dot(w,vec3(1.0)),.001);}
vec4 stone_map(vec3 p,vec3 n){vec3 w=stone_weights(n);return texture(stone_detail_map,p.zy*.38)*w.x+texture(stone_detail_map,p.xz*.38)*w.y+texture(stone_detail_map,p.xy*.38)*w.z;}
vec3 stone_normal(vec3 p,vec3 n){
 vec3 w=stone_weights(n);
 vec2 x=(texture(stone_detail_map,p.zy*.38).gb-.5)*2.0;
 vec2 y=(texture(stone_detail_map,p.xz*.38).gb-.5)*2.0;
 vec2 z=(texture(stone_detail_map,p.xy*.38).gb-.5)*2.0;
 vec3 slope=vec3(0.0,x.y,x.x)*w.x+vec3(y.x,0.0,y.y)*w.y+vec3(z.x,z.y,0.0)*w.z;
 return normalize(n-(slope-n*dot(n,slope))*stone_relief_strength);
}
// Quiet world-anchored mineral variation shared by the stone envelope,
// fractured sides and shore rocks. Physical planes provide the large facets.
float stone_noise(vec3 p){
 vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(rock_hash(i).x,rock_hash(i+vec3(1,0,0)).x,f.x),mix(rock_hash(i+vec3(0,1,0)).x,rock_hash(i+vec3(1,1,0)).x,f.x),f.y),mix(mix(rock_hash(i+vec3(0,0,1)).x,rock_hash(i+vec3(1,0,1)).x,f.x),mix(rock_hash(i+vec3(0,1,1)).x,rock_hash(i+vec3(1,1,1)).x,f.x),f.y),f.z);
}
vec3 stone_surface(vec3 p,vec3 n){
 // Large beige-grey blocks. Variation stays broader than a facet so a face
 // reads as one matte plane; packed slopes still carry a little relief.
 float cloud=stone_noise(p*.42);
 float mineral=stone_noise(p*.20+vec3(13.0,4.0,7.0));
 float grain=stone_noise(p*2.6);
 float layers=stone_noise(vec3(p.x*.32,p.y*.90+stone_noise(p*.22)*.35,p.z*.32));
 vec3 stone=mix(vec3(.30,.31,.30),vec3(.43,.42,.39),.58);
 stone+=(cloud-.5)*vec3(.034,.036,.032)+(mineral-.5)*vec3(.026,.014,.002)+(layers-.5)*vec3(.014,.014,.012);
 vec3 w=stone_weights(n);
 vec3 mineral_paint=texture(stone_mineral_map,p.zy*.18).rgb*w.x+texture(stone_mineral_map,p.xz*.18).rgb*w.y+texture(stone_mineral_map,p.xy*.18).rgb*w.z;
 stone*=(.99+(grain-.5)*.02)*(1.0+(stone_map(p,n).r-.5)*.06)*(vec3(1.02)+(mineral_paint-vec3(.36))*.22);
 vec3 deposit=tw_deposits(p);
 float exposed=.45+.55*smoothstep(-.65,.25,n.y);
 stone=mix(stone,stone*vec3(.90,.90,.86)+vec3(.012,.010,.006),deposit.x*.08*exposed);
 stone=mix(stone,stone*vec3(.94,.90,.84),deposit.y*.05*exposed);
 stone=mix(stone,vec3(.56,.54,.48),deposit.z*.07*exposed);
 return stone;
}

// A short grass tint, then the same beige soil as the path, then bare stone.
// The reach is uneven and shallow so it cannot draw a dark belt or a lichen speckle.
vec3 stone_root_contact(vec3 stone,vec3 p,vec3 n,float cap_height,float dry){
 float depth=cap_height-p.y;
 if(dry<.5 || depth<-.02 || depth>1.05)return stone;
 float tone=tw_noise(vec3(p.x*.50,cap_height,p.z*.50)+vec3(23.0));
 float reach=.05+.14*tone;
 float facing=smoothstep(-.05,.35,n.y);
 float near=(1.0-smoothstep(0.0,reach,max(depth,0.0)))*facing;
 stone=mix(stone,tw_soil(p.xz),clamp(near*.45,0.0,.20));
 vec3 green=vec3(.46,.53,.40);
 float lip=(1.0-smoothstep(0.0,.06,max(depth,0.0)))*facing;
 return mix(stone,green,clamp(lip*.22,0.0,.12));
}
