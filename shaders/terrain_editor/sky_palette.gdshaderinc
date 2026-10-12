// Shared by the sky backdrop, its reflection cubemap, distant mountains and
// cloud decks so haze and reflections resolve to the sky colour drawn behind.
const vec2 SKY_SUN = vec2(.885,.105);
vec2 sky_coord(vec3 direction){
	return vec2(.5+(atan(direction.x,-direction.z)+.279253)/.96,.5-(asin(clamp(direction.y,-1.0,1.0))+.471239)/.54);
}
float sky_sun_distance(vec2 p){return length((p-SKY_SUN)*vec2(1.7768,1.0));}
vec3 sky_gradient(vec2 p){
	float sun=sky_sun_distance(p);
	// The low band is the mist sea: luminous warm cream, not a grey wash.
	vec3 color=mix(vec3(1.14,.98,.74),vec3(1.12,.90,.60),smoothstep(-.12,.28,p.y));
	color=mix(color,vec3(1.06,.94,.74),smoothstep(.28,.78,p.y));
	color=mix(color,vec3(1.06,.86,.58),exp(-sun*3.4)*.64);
	return color+vec3(.46,.32,.14)*exp(-sun*11.0);
}
// The disc stays just below white in the Linear tonemapper so it reads as a
// warm sun rather than a clipped hole; glow supplies a little extra bloom.
const vec3 SKY_SUN_CORE = vec3(1.0,.90,.60);
float sky_sun_disc(vec2 p){return 1.0-smoothstep(.056,.066,sky_sun_distance(p));}
