// Shared by the sky backdrop, its reflection cubemap, distant mountains and
// cloud decks so haze and reflections resolve to the sky colour drawn behind.
const vec2 SKY_SUN = vec2(.885,.105);
vec2 sky_coord(vec3 direction){
	return vec2(.5+(atan(direction.x,-direction.z)+.279253)/.96,.5-(asin(clamp(direction.y,-1.0,1.0))+.471239)/.54);
}
float sky_sun_distance(vec2 p){return length((p-SKY_SUN)*vec2(1.7768,1.0));}
vec3 sky_gradient(vec2 p){
	float sun=sky_sun_distance(p);
	vec3 color=mix(vec3(.84,.74,.60),vec3(.97,.76,.47),smoothstep(-.12,.30,p.y));
	color=mix(color,vec3(.91,.80,.64),smoothstep(.30,.80,p.y));
	color=mix(color,vec3(1.0,.80,.50),exp(-sun*4.2)*.60);
	return color+vec3(.45,.30,.12)*exp(-sun*13.0);
}
// The disc stays just below white in the Linear tonemapper so it reads as a
// warm sun rather than a clipped hole; glow supplies a little extra bloom.
const vec3 SKY_SUN_CORE = vec3(1.0,.90,.60);
float sky_sun_disc(vec2 p){return 1.0-smoothstep(.056,.066,sky_sun_distance(p));}
