shader_type spatial;
// Opaque only. Writing ALPHA, even 1.0, puts the mesh on the transparent
// pipeline and the island reads as a glass box.
render_mode cull_back, diffuse_burley, specular_disabled;
uniform vec4 moss_color : source_color = vec4(0.33, 0.42, 0.27, 1.0);
uniform vec4 meadow_color : source_color = vec4(0.46, 0.52, 0.30, 1.0);
uniform vec4 path_color : source_color = vec4(0.64, 0.59, 0.44, 1.0);
uniform vec4 earth_color : source_color = vec4(0.50, 0.41, 0.32, 1.0);
// seed7 wall palette: warm earth under the grass lip -> cool grey at the keel.
uniform vec4 rock_warm : source_color = vec4(0.50, 0.36, 0.26, 1.0);
uniform vec4 rock_mid : source_color = vec4(0.42, 0.36, 0.31, 1.0);
uniform vec4 rock_cool : source_color = vec4(0.34, 0.36, 0.38, 1.0);
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

vec3 seed7_rock(vec3 p, vec3 n) {
	float depth = clamp((-p.y) / 4.2, 0.0, 1.0);
	vec3 rock = mix(rock_warm.rgb, rock_mid.rgb, smoothstep(0.06, 0.42, depth));
	rock = mix(rock, rock_cool.rgb, smoothstep(0.40, 0.92, depth));
	// Crisp, subtle strata — hard bands, not smeared pastel.
	float band_y = p.y + (hash(floor(p.xz * 1.35)) - 0.5) * 0.10;
	float strata = step(0.58, fract(band_y * 1.35));
	rock *= mix(1.0, 0.88, strata);
	float grain = (hash(floor(p.xz * 2.8 + p.y * 1.1)) - 0.5) * 0.05;
	rock += grain;
	// Ambient occlusion just under the grass lip.
	float lip_ao = (1.0 - clamp(-p.y / 0.42, 0.0, 1.0)) * (1.0 - abs(n.y));
	rock *= 1.0 - lip_ao * 0.28;
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
	float ny = clamp(n.y, -1.0, 1.0);
	vec2 p = world_pos.xz;
	// Vertex blue is the rock flag. Ledge faces can have high ny; they must stay rock.
	if (vcol.b > 0.45) {
		ALBEDO = seed7_rock(world_pos, n);
		ROUGHNESS = 0.93;
		return;
	}
	float broad = noise(p * 0.36) * 0.65 + noise(p * 0.85) * 0.35;
	float detail = noise(p * 16.0);
	vec3 grass = mix(moss_color.rgb, meadow_color.rgb, smoothstep(0.2, 0.8, broad));
	grass += (detail - 0.5) * 0.025;
	float path = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= path_count) break;
		float d = segment_distance(p, path_segments[i].xy, path_segments[i].zw);
		path = max(path, 1.0 - smoothstep(0.35, 1.15, d + (noise(p * 2.8) - 0.5) * 0.42));
	}
	vec3 soil = mix(earth_color.rgb, path_color.rgb, path * 0.7);
	vec3 top = mix(grass, soil, path * 0.78);
	for (int i = 0; i < 32; i++) {
		if (i >= contact_count) break;
		vec4 patch = contact_patches[i];
		float d = length(p - patch.xy) / max(patch.z, 0.001);
		float root = (1.0 - smoothstep(0.1, 1.0, d + (noise(p * 4.0) - 0.5) * 0.2)) * patch.w;
		top = mix(top, moss_color.rgb * 0.72, root);
	}
	float inland = clamp(vcol.g, 0.0, 1.0);
	float soil_w = 1.0 - smoothstep(0.10, 0.48, inland + (noise(p * 3.1) - 0.5) * 0.08);
	vec3 rim = mix(top, earth_color.rgb, soil_w);
	float turf = smoothstep(0.48, 0.90, ny);
	ALBEDO = mix(earth_color.rgb, rim, turf);
	ROUGHNESS = mix(0.88, 0.94, turf * inland);
}
