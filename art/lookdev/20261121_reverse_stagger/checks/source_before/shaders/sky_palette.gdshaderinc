// Shared by the sky backdrop, its reflection cubemap, distant mountains and
// cloud decks so haze and reflections resolve to one seamless 360-degree sky.
const vec3 SKY_SUN_DIR = vec3(.93, -.06, -.36);
uniform vec3 sky_zenith : source_color = vec3(.62, .75, .79);
uniform vec3 sky_mid : source_color = vec3(.80, .86, .86);
uniform vec3 sky_horizon : source_color = vec3(.95, .92, .83);
uniform vec3 sky_sun_glow : source_color = vec3(.99, .93, .79);
uniform vec3 sky_sun_core : source_color = vec3(1.0, .97, .88);

// Seamless 360-degree sky coordinates:
// x = azimuth in [0, 1], y = elevation coordinate (0 = upper sky, 1 = deep below horizon).
vec2 sky_coord(vec3 direction){
	vec3 d = normalize(direction);
	float az = atan(d.x, -d.z) / 6.2831853 + .5;
	float el = .5 - (asin(clamp(d.y, -1.0, 1.0)) + .471239) / .54;
	return vec2(az, el);
}

// Seamless 3D angular distance to the morning sun glow direction.
float sky_sun_distance(vec2 p){
	float az_rad = (p.x - .5) * 6.2831853;
	float el_rad = (.5 - p.y) * .54 - .471239;
	float ce = cos(clamp(el_rad, -1.57, 1.57));
	vec3 dir = normalize(vec3(sin(az_rad) * ce, sin(clamp(el_rad, -1.57, 1.57)), -cos(az_rad) * ce));
	vec3 sun_d = normalize(SKY_SUN_DIR);
	return acos(clamp(dot(dir, sun_d), -1.0, 1.0)) * 1.35;
}

// Seamless 360-degree horizontal sun-side factor in [0, 1] (0 = cool left mist, 1 = warm right morning sun):
float sky_horiz_sun(vec2 p){
	float az_rad = (p.x - .5) * 6.2831853;
	vec2 dir_xz = vec2(sin(az_rad), -cos(az_rad));
	vec2 sun_xz = normalize(vec2(SKY_SUN_DIR.x, SKY_SUN_DIR.z));
	return smoothstep(-.26, .42, dot(dir_xz, sun_xz));
}

// Elevation, sun distance and warm-side weight directly from the view ray.
// Avoid atan -> sin/cos round trips in every sky/cloud/mountain fragment.
// Callers supply EYEDIR or a nonzero, near-clipped fragment-to-camera ray.
vec3 sky_view_factors(vec3 direction){
	vec3 d = normalize(direction);
	float el = asin(clamp(d.y, -1.0, 1.0));
	float elevation = .5 - (el + .471239) / .54;
	// atan(0, -0) has backend-specific signed-zero behaviour at a pole.
	// Keep the original path only there; normal view rays avoid the round trip.
	if(dot(d.xz, d.xz) == 0.0){
		vec2 pole_coord = sky_coord(d);
		return vec3(pole_coord.y, sky_sun_distance(pole_coord), sky_horiz_sun(pole_coord));
	}
	vec2 horizontal = normalize(d.xz);
	float h_sun = smoothstep(-.26, .42, dot(horizontal, normalize(SKY_SUN_DIR.xz)));
	// Preserve the angular implementation's tiny clamp at the exact poles.
	if(abs(el) > 1.57){
		float pole = clamp(el, -1.57, 1.57);
		d = normalize(vec3(horizontal.x * cos(pole), sin(pole), horizontal.y * cos(pole)));
	}
	float sun = acos(clamp(dot(d, normalize(SKY_SUN_DIR)), -1.0, 1.0)) * 1.35;
	return vec3(elevation, sun, h_sun);
}

vec3 sky_gradient_factors(vec3 factors){
	float sun = factors.y;
	float h_sun = factors.z;
	// Cool cerulean-slate mist on left -> warm creamy golden-ivory morning glow on right (Ref 1):
	vec3 cool_sky = mix(sky_zenith * vec3(1.12, 1.09, 1.05), sky_mid * vec3(.98, 1.02, 1.04), smoothstep(-.16, .34, factors.x));
	cool_sky = mix(cool_sky, sky_zenith * vec3(.66, .79, .86), smoothstep(.38, .92, factors.x) * .95);
	vec3 warm_sky = mix(sky_zenith * vec3(1.28, 1.13, .89), sky_horizon * vec3(1.08, 1.01, .91), smoothstep(-.18, .38, factors.x));
	warm_sky = mix(warm_sky, sky_sun_glow * vec3(1.04, .97, .85), smoothstep(.24, .92, factors.x) * .88);
	vec3 color = mix(cool_sky, warm_sky, h_sun);
	float sun_bloom = exp(-sun * 1.45);
	color = mix(color, sky_sun_glow, sun_bloom * .68);
	float day_t = smoothstep(.35, .80, sky_horizon.r);
	float sub_cool_damp = mix(1.0, .82, smoothstep(.42, .88, factors.x) * (1.0 - h_sun));
	float day_hdr = mix(1.0, (mix(1.54, 1.84, h_sun) + .28 * sun_bloom) * sub_cool_damp, day_t);
	return color * day_hdr + vec3(.18, .13, .05) * exp(-sun * 3.8) * day_t;
}

vec3 sky_gradient(vec2 p){
	return sky_gradient_factors(vec3(p.y, sky_sun_distance(p), sky_horiz_sun(p)));
}

#define SKY_SUN_CORE sky_sun_core
float sky_disc_from_distance(float d){
	return clamp(exp(-d * 9.0) * .58 + exp(-d * 28.0) * .32, 0.0, 1.0);
}

float sky_sun_disc(vec2 p){return sky_disc_from_distance(sky_sun_distance(p));}
