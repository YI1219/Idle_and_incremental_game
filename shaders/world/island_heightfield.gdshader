shader_type spatial;
// Opaque only. Writing ALPHA, even 1.0, puts the mesh on the transparent
// pipeline and the island reads as a glass box.
render_mode cull_back, diffuse_burley, specular_disabled;
// Olive pair, ~35% saturation. Do not use the old saturated meadow greens.
uniform vec4 moss_color : source_color = vec4(0.435, 0.478, 0.302, 1.0);
uniform vec4 meadow_color : source_color = vec4(0.494, 0.545, 0.353, 1.0);
uniform vec4 shade_grass : source_color = vec4(0.36, 0.40, 0.27, 1.0);
uniform vec4 path_color : source_color = vec4(0.50, 0.43, 0.32, 1.0);
uniform vec4 earth_color : source_color = vec4(0.38, 0.28, 0.20, 1.0);
uniform vec4 earth_hi : source_color = vec4(0.46, 0.34, 0.24, 1.0);
uniform vec4 rock_warm : source_color = vec4(0.58, 0.44, 0.34, 1.0);
uniform vec4 rock_mid : source_color = vec4(0.48, 0.42, 0.38, 1.0);
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
	float band = noise(p.xz * 0.18 + p.y * 0.07);
	vec3 rock = mix(rock_warm.rgb, rock_mid.rgb, smoothstep(0.08, 0.45, depth + (band - 0.5) * 0.18));
	rock = mix(rock, rock_cool.rgb, smoothstep(0.40, 0.92, depth + (band - 0.5) * 0.12));
	// Skewed grain so walls do not stripe horizontally.
	vec2 skew = p.xz + vec2(p.y * 0.37, p.y * -0.22);
	float block = hash(floor(skew * 1.15 + p.y * 0.4));
	rock *= 0.90 + block * 0.22;
	float grain = (noise(skew * 3.4) - 0.5) * 0.06;
	rock += grain;
	float facet = clamp(dot(normalize(n), normalize(vec3(0.48, 0.70, 0.32))) * 0.40 + 0.62, 0.50, 1.12);
	rock *= facet;
	float lip_ao = (1.0 - clamp(-p.y / 0.38, 0.0, 1.0)) * (1.0 - abs(n.y));
	rock *= 1.0 - lip_ao * 0.30;
	rock *= mix(0.72, 1.05, clamp(ao, 0.0, 1.0));
	return rock;
}

vec3 earth_band(vec3 p) {
	vec2 skew = p.xz + vec2(p.y * 0.31, p.y * -0.18);
	float n = noise(skew * 5.7) * 0.55 + noise(skew * 31.0) * 0.45;
	return mix(earth_color.rgb, earth_hi.rgb, smoothstep(0.28, 0.72, n));
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
		float nx = noise(p * 0.55 + world_pos.y * 0.2);
		float ny = noise(p * 2.1 + 3.7);
		// Facets stay flat. A little grain only, so the blocks keep their planes.
		n = normalize(n + vec3((nx - 0.5) * 0.04, (ny - 0.5) * 0.03, (nx - 0.5) * 0.04));
		ALBEDO = seed7_rock(world_pos, n, ao);
		ROUGHNESS = 0.93;
		NORMAL = n;
	} else if (vcol.g < 0.32) {
		ALBEDO = earth_band(world_pos) * mix(0.78, 1.0, ao);
		ROUGHNESS = 0.96;
	} else {
		float broad = noise(p * 0.28) * 0.55 + noise(vec2(p.y, -p.x) * 0.28 + 2.1) * 0.45;
		float mid = noise(p * 0.85);
		float detail = noise(p * 14.0);
		vec3 grass = mix(moss_color.rgb, meadow_color.rgb, smoothstep(0.28, 0.72, broad));
		grass = mix(grass, shade_grass.rgb, (mid - 0.5) * 0.32 + 0.08);
		grass += (detail - 0.5) * 0.028;
		float inland = clamp(vcol.g, 0.0, 1.0);
		float path = 0.0;
		for (int i = 0; i < 8; i++) {
			if (i >= path_count) break;
			float d = segment_distance(p, path_segments[i].xy, path_segments[i].zw);
			path = max(path, 1.0 - smoothstep(0.55, 1.55, d + (noise(p * 2.2) - 0.5) * 0.70));
		}
		vec3 worn = mix(earth_color.rgb, path_color.rgb, 0.40 + noise(p * 3.4) * 0.22);
		vec3 top = mix(grass, worn, path * 0.52);
		for (int i = 0; i < 32; i++) {
			if (i >= contact_count) break;
			vec4 patch = contact_patches[i];
			float d = length(p - patch.xy) / max(patch.z, 0.001);
			float root = (1.0 - smoothstep(0.05, 1.0, d + (noise(p * 3.6) - 0.5) * 0.28)) * patch.w;
			top = mix(top, earth_color.rgb * 0.62, root * 0.85);
			top = mix(top, shade_grass.rgb * 0.70, root * 0.35);
		}
		float n1 = noise(p * 0.50);
		float n2 = noise(p * 2.05);
		float n3 = noise(p * 8.2);
		n = normalize(n + vec3((n1 - n2) * 0.14, 0.0, (n2 - n3) * 0.14));
		ALBEDO = top * mix(0.78, 1.0, ao);
		ROUGHNESS = mix(0.92, 0.97, inland);
		NORMAL = n;
	}
}
