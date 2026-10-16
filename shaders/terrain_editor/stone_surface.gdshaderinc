#include "weathering.gdshaderinc"
// Linear RGBA: mineral value, local U/V slopes, roughness. World-space
// triplanar projection continues across independent bodies and their backing.
uniform sampler2D stone_detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_mineral_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float stone_relief_strength : hint_range(0.0, 1.0) = .07;
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
 float cloud=stone_noise(p*.72);
 float mineral=stone_noise(p*.29+vec3(13.0,4.0,7.0));
 float grain=stone_noise(p*8.0);
 float layers=stone_noise(vec3(p.x*.58,p.y*2.4+stone_noise(p*.38)*.8,p.z*.58));
 vec3 stone=mix(vec3(.27,.30,.32),vec3(.43,.43,.39),.58);
 stone+=(cloud-.5)*vec3(.065,.075,.085)+(mineral-.5)*vec3(.065,.028,-.015)+(layers-.5)*vec3(.035,.039,.042);
 vec3 w=stone_weights(n);
 vec3 mineral_paint=texture(stone_mineral_map,p.zy*.27).rgb*w.x+texture(stone_mineral_map,p.xz*.27).rgb*w.y+texture(stone_mineral_map,p.xy*.27).rgb*w.z;
 // Albedo supplies the missing middle scale; packed slopes still carry fine
 // relief. Compress the paint contrast around its mineral midtone; keep
 // the mapped slopes and roughness so quieter color never becomes smooth gloss.
 stone=stone*.94*(.98+grain*.04)*(1.0+(stone_map(p,n).r-.5)*.24)*(vec3(.78)+mineral_paint*.65);
 vec3 deposit=tw_deposits(p);
 float exposed=.45+.55*smoothstep(-.65,.25,n.y);
 // Mineral weathering is uneven within a face, rather than one clean tint.
 stone=mix(stone,stone*vec3(.58,.60,.59)+vec3(.015,.011,.005),deposit.x*.24*exposed);
 stone=mix(stone,stone*vec3(.74,.67,.52),deposit.y*.12*exposed);
 stone=mix(stone,vec3(.48,.48,.40),deposit.z*.18*exposed);
 return stone;
}

// Grass roots, soil and sparse lichen mingle locally below a real dry cap.
// Shared deposits match the lawn above; the uneven reach cannot form a belt.
vec3 stone_root_contact(vec3 stone,vec3 p,vec3 n,float cap_height,float dry){
 float depth=cap_height-p.y;
 if(dry<.5 || depth<-.015 || depth>.72)return stone;
 vec3 deposits=tw_deposits(vec3(p.x,cap_height,p.z));
 float reach=.055+.24*tw_noise(vec3(p.x*.9,cap_height,p.z*.9)+vec3(23.0));
 float near=(1.0-smoothstep(.015,reach,depth))*smoothstep(-.30,.15,n.y);
 float fragments=tw_noise(p*vec3(19.0,11.0,19.0));
 float soil=deposits.x*near*(.45+.55*smoothstep(.35,.64,fragments));
 vec3 root_earth=mix(vec3(.09,.075,.044),vec3(.18,.15,.09),deposits.y);
 stone=mix(stone,root_earth,clamp(soil*1.35,0.0,.75));
 float lichen=deposits.y*near*(1.0-deposits.x)*.40;
 return mix(stone,stone*vec3(.71,.81,.55),lichen);
}
