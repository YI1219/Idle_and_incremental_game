// Shared damp earth/mineral substrate. Both shore and shallow bed use this
// material at the same world position; requires stone_mineral_map/tw_noise.
vec3 wet_bank_earth(vec3 p){
 float broad=.5+.5*sin(p.x*.40+sin(p.z*.34));
 float grit=tw_noise(vec3(p.x*2.4,3.0,p.z*2.4));
 vec3 earth=mix(vec3(.42,.44,.36),vec3(.54,.52,.43),broad);
 return mix(earth,tw_soil(p.xz)*.94,smoothstep(.74,.92,grit)*.16);
}
vec3 wet_bank_material(vec3 p){
 vec3 mineral=textureLod(stone_mineral_map,p.xz*.28,1.5).rgb*vec3(.80,.83,.72);
 return mix(wet_bank_earth(p)*.78,mineral,.65)*.82;
}
