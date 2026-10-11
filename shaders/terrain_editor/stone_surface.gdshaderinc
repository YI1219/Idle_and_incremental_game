// Quiet world-anchored mineral variation shared by the stone envelope,
// fractured sides and shore rocks. Physical planes provide the large facets.
float stone_noise(vec3 p){
 vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(rock_hash(i).x,rock_hash(i+vec3(1,0,0)).x,f.x),mix(rock_hash(i+vec3(0,1,0)).x,rock_hash(i+vec3(1,1,0)).x,f.x),f.y),mix(mix(rock_hash(i+vec3(0,0,1)).x,rock_hash(i+vec3(1,0,1)).x,f.x),mix(rock_hash(i+vec3(0,1,1)).x,rock_hash(i+vec3(1,1,1)).x,f.x),f.y),f.z);
}
vec3 stone_surface(vec3 p){
 float cloud=stone_noise(p*.72);
 float mineral=stone_noise(p*.29+vec3(13.0,4.0,7.0));
 float grain=stone_noise(p*8.0);
 vec3 stone=cliff_gray(.53)+vec3(.065,.075,.085);
 stone+=(cloud-.5)*vec3(.105,.115,.13)+(mineral-.5)*vec3(.09,.035,-.025);
 return stone*(.98+grain*.04);
}
