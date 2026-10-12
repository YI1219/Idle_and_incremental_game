// Linear RGBA: mineral value, local U/V slopes, roughness. World-space
// triplanar projection continues across independent bodies and their backing.
uniform sampler2D stone_detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
vec3 stone_weights(vec3 n){vec3 w=pow(abs(n),vec3(4.0));return w/max(dot(w,vec3(1.0)),.001);}
vec4 stone_map(vec3 p,vec3 n){vec3 w=stone_weights(n);return texture(stone_detail_map,p.zy*.38)*w.x+texture(stone_detail_map,p.xz*.38)*w.y+texture(stone_detail_map,p.xy*.38)*w.z;}
vec3 stone_normal(vec3 p,vec3 n){
 vec3 w=stone_weights(n);
 vec2 x=(texture(stone_detail_map,p.zy*.38).gb-.5)*2.0;
 vec2 y=(texture(stone_detail_map,p.xz*.38).gb-.5)*2.0;
 vec2 z=(texture(stone_detail_map,p.xy*.38).gb-.5)*2.0;
 vec3 slope=vec3(0.0,x.y,x.x)*w.x+vec3(y.x,0.0,y.y)*w.y+vec3(z.x,z.y,0.0)*w.z;
 vec2 x2=(texture(stone_detail_map,p.zy*1.65+vec2(3.1,1.7)).gb-.5)*2.0;
 vec2 y2=(texture(stone_detail_map,p.xz*1.65+vec2(8.4,2.2)).gb-.5)*2.0;
 vec2 z2=(texture(stone_detail_map,p.xy*1.65+vec2(1.3,6.6)).gb-.5)*2.0;
 vec3 fine=vec3(0.0,x2.y,x2.x)*w.x+vec3(y2.x,0.0,y2.y)*w.y+vec3(z2.x,z2.y,0.0)*w.z;
 // Coarse tilt stays shallow so a facet does not scoop into a pit.
 // The finer octave is the 0.1 m grit that should still read up close.
 vec3 bent=(slope-n*dot(n,slope))*.07+(fine-n*dot(n,fine))*.09;
 return normalize(n-bent);
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
 float chip=stone_noise(p*3.3);
 float grit=stone_noise(p*12.5);
 vec3 stone=cliff_gray(.53)+vec3(.065,.075,.085);
 stone+=(cloud-.5)*vec3(.105,.115,.13)+(mineral-.5)*vec3(.09,.035,-.025);
 stone+=(chip-.5)*vec3(.045,.048,.05)+(grit-.5)*vec3(.03,.032,.034);
 return stone*(.98+grain*.04)*(1.0+(stone_map(p,n).r-.5)*.55);
}
