vec3 rock_hash(vec3 p){
	vec3 q=fract(p*vec3(.123,.117,.139));
	q+=dot(q,q.zxy+vec3(19.19));
	return fract(vec3((q.x+q.y)*q.z,(q.y+q.z)*q.x,(q.z+q.x)*q.y));
}
vec3 cliff_gray(float variation){
	return mix(vec3(.43,.42,.39),vec3(.58,.56,.51),variation);
}
