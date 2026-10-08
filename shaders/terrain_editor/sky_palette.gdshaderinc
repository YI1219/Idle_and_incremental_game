// Shared by the sky backdrop, distant mountains and cloud decks so distant
// haze resolves to the sky colour actually drawn behind it.
const vec2 SKY_SUN = vec2(.885,.105);
vec2 sky_coord(vec3 direction){
	return vec2(.5+(atan(direction.x,-direction.z)+.279253)/.96,.5-(asin(clamp(direction.y,-1.0,1.0))+.471239)/.54);
}
float sky_sun_distance(vec2 p){return length((p-SKY_SUN)*vec2(1.7768,1.0));}
vec3 sky_gradient(vec2 p){
	float sun=sky_sun_distance(p);
	vec3 color=mix(vec3(.70,.67,.62),vec3(.97,.79,.55),smoothstep(-.12,.30,p.y));
	color=mix(color,vec3(.90,.81,.68),smoothstep(.30,.80,p.y));
	color=mix(color,vec3(1.0,.83,.57),exp(-sun*4.2)*.70);
	return color+vec3(1.0,.74,.42)*exp(-sun*13.0)*.55;
}
// HDR core lets the environment glow draw the halo; the gradient keeps a soft
// falloff when glow is disabled on low quality.
const vec3 SKY_SUN_CORE = vec3(2.7,2.15,1.40);
float sky_sun_disc(vec2 p){return 1.0-smoothstep(.056,.066,sky_sun_distance(p));}
