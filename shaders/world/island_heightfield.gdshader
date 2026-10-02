shader_type spatial;
// Opaque only. Writing ALPHA, even 1.0, puts the mesh on the transparent
// pipeline and the island reads as a glass box.
render_mode cull_back, diffuse_burley, specular_disabled;
uniform vec4 moss_color : source_color = vec4(0.30, 0.46, 0.28, 1.0);
uniform vec4 meadow_color : source_color = vec4(0.54, 0.62, 0.28, 1.0);
uniform vec4 shade_grass : source_color = vec4(0.22, 0.34, 0.22, 1.0);
uniform vec4 path_color : source_color = vec4(0.58, 0.48, 0.34, 1.0);
uniform vec4 earth_color : source_color = vec4(0.50, 0.41, 0.32, 1.0);
// seed7 wall palette: warm earth under the grass lip -> cool grey at the keel.
uniform vec4 rock_warm : source_color = vec4(0.62, 0.44, 0.30, 1.0);
uniform vec4 rock_mid : source_color = vec4(0.50, 0.42, 0.36, 1.0);
uniform vec4 rock_cool : source_color = vec4(0.40, 0.42, 0.45, 1.0);
uniform vec4 path_segments[8];
uniform int path_count = 0;
uniform vec4 contact_patches[32];
uniform int contact_count = 0;
varying vec3 world_pos;
varying vec3 world_n;
varying vec4 vcol;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 d = b - a;
	return length(p - a - d * clamp(dot(p - a, d) / max(dot(d, d), 0.001), 0.0, 1.0));
}

vec3 seed7_rock(vec3 p, vec3 n, float ao) {
	float depth = clamp((-p.y) / 4.2, 0.0, 1.0);
	vec3 rock = mix(rock_warm.rgb, rock_mid.rgb, smoothstep(0.05, 0.40, depth));
	rock = mix(rock, rock_cool.rgb, smoothstep(0.38, 0.90, depth));
	float band_y = p.y + (hash(floor(p.xz * 0.85)) - 0.5) * 0.18;
	float strata = step(0.55, fract(band_y * 1.05));
	rock *= mix(1.06, 0.82, strata);
	float grain = (hash(floor(p.xz * 2.2 + p.y * 0.9)) - 0.5) * 0.07;
	rock += grain;
	// Facet light/dark from the authored flat normal so slabs don't read as one slab.
	float facet = clamp(dot(normalize(n), normalize(vec3(0.48, 0.70, 0.32))) * 0.55 + 0.52, 0.42, 1.18);
	rock *= facet;
	float lip_ao = (1.0 - clamp(-p.y / 0.38, 0.0, 1.0)) * (1.0 - abs(n.y));
	rock *= 1.0 - lip_ao * 0.34;
	rock *= mix(0.58, 1.0, clamp(ao, 0.0, 1.0));
	return rock;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_NORMAL_MATRIX * NORMAL));
	vcol = COLOR;
}

void fragment() {
	vec3 n = world_n;
	if (length(n) < 0.001) {
		n = vec3(0.0, 1.0, 0.0);
	}
	vec2 p = world_pos.xz;
	float ao = clamp(vcol.r, 0.35, 1.0);
	if (vcol.b > 0.45) {
		ALBEDO = seed7_rock(world_pos, n, ao);
		ROUGHNESS = 0.92;
		EMISSION = ALBEDO * 0.015;
	} else {
		float broad = noise(p * 0.22) * 0.55 + noise(p * 0.62) * 0.30 + noise(p * 1.4) * 0.15;
		float detail = noise(p * 12.0);
		vec3 grass = mix(moss_color.rgb, meadow_color.rgb, smoothstep(0.18, 0.78, broad));
		grass += (detail - 0.5) * 0.045;
		float inland = clamp(vcol.g, 0.0, 1.0);
		grass = mix(shade_grass.rgb, grass, smoothstep(0.18, 0.82, inland));
		float path = 0.0;
		for (int i = 0; i < 8; i++) {
			if (i >= path_count) break;
			float d = segment_distance(p, path_segments[i].xy, path_segments[i].zw);
			path = max(path, 1.0 - smoothstep(0.55, 1.55, d + (noise(p * 2.2) - 0.5) * 0.70));
		}
		vec3 worn = mix(earth_color.rgb, path_color.rgb, 0.45 + noise(p * 3.4) * 0.25);
		vec3 top = mix(grass, worn, path * 0.58);
		for (int i = 0; i < 32; i++) {
			if (i >= contact_count) break;
			vec4 patch = contact_patches[i];
			float d = length(p - patch.xy) / max(patch.z, 0.001);
			float root = (1.0 - smoothstep(0.08, 1.0, d + (noise(p * 3.6) - 0.5) * 0.22)) * patch.w;
			top = mix(top, shade_grass.rgb * 0.78, root);
		}
		ALBEDO = top * mix(0.70, 1.0, ao);
		ROUGHNESS = mix(0.90, 0.96, inland);
		EMISSION = ALBEDO * 0.025;
	}
}
