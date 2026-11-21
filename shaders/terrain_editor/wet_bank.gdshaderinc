// Shared warm cream-sandstone & celadon-jade watercolor shore bank substrate
// in LINEAR color space (sRGB ~0.45..0.54, zero dark mud & zero chalky white!).
vec3 wet_bank_earth(vec3 p){
	float broad=.5+.5*sin(p.x*.62+sin(p.z*.55));
	float wash=tw_noise(vec3(p.x*2.4,3.0,p.z*2.4));
	vec3 sand_jade=mix(vec3(.16,.16,.105),vec3(.24,.22,.145),broad);
	return mix(sand_jade,vec3(.29,.28,.19),smoothstep(.45,.82,wash)*.32);
}
vec3 wet_bank_material(vec3 p){
	vec3 mineral=textureLod(stone_mineral_map,p.xz*.22,2.0).rgb*vec3(.88,.92,.82);
	return mix(wet_bank_earth(p)*.94,mineral,.32);
}
