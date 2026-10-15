// Shared damp earth/mineral substrate. Both shore and shallow bed use this
// material at the same world position; requires stone_mineral_map/tw_noise.
vec3 wet_bank_earth(vec3 p){
 float broad=.5+.5*sin(p.x*.71+sin(p.z*.63));
 float grit=tw_noise(vec3(p.x*14.0,3.0,p.z*14.0));
 vec3 earth=mix(vec3(.25,.28,.20),vec3(.38,.37,.26),broad);
 return mix(earth,vec3(.57,.57,.47),smoothstep(.66,.83,grit)*.28);
}
vec3 wet_bank_material(vec3 p){
 vec3 mineral=textureLod(stone_mineral_map,p.xz*.28,1.5).rgb*vec3(.80,.83,.72);
 return mix(wet_bank_earth(p)*.78,mineral,.65)*.82;
}
