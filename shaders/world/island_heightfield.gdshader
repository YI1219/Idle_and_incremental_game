shader_type spatial;
render_mode diffuse_burley, specular_disabled, shadows_disabled;
uniform vec4 grass_a : source_color = vec4(0.38, 0.50, 0.28, 1.0);
uniform vec4 grass_b : source_color = vec4(0.52, 0.60, 0.32, 1.0);
uniform vec4 soil_color : source_color = vec4(0.50, 0.41, 0.32, 1.0);
uniform vec4 rock_warm : source_color = vec4(0.58, 0.47, 0.39, 1.0);
uniform vec4 rock_cool : source_color = vec4(0.42, 0.44, 0.47, 1.0);
uniform vec4 fog_under : source_color = vec4(0.55, 0.62, 0.66, 1.0);
uniform vec4 path_color : source_color = vec4(0.64, 0.59, 0.44, 1.0);
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
vec3 triplanar_rock(vec3 p, vec3 n) {
	float bands = smoothstep(0.28, 0.72, fract(p.y * 0.85 + noise(p.xz * 0.22) * 0.2));
	vec3 rock = mix(rock_warm.rgb, rock_cool.rgb, bands);
	vec3 nx = vec3(noise(p.zy * 0.55), noise(p.zy * 1.3), noise(p.zy * 0.31));
	vec3 ny = vec3(noise(p.xz * 0.55), noise(p.xz * 1.3), noise(p.xz * 0.31));
	vec3 nz = vec3(noise(p.xy * 0.55), noise(p.xy * 1.3), noise(p.xy * 0.31));
	vec3 w = abs(n);
	w = w / max(w.x + w.y + w.z, 0.001);
	vec3 grain = nx * w.x + ny * w.y + nz * w.z;
	return rock + (grain - vec3(0.5)) * 0.07;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_n = normalize((MODEL_NORMAL_MATRIX * NORMAL));
	vcol = COLOR;
	// Hard-edged facets: use the authored face normal, not interpolated vertex normals.
}

void fragment() {
	vec3 n = normalize(cross(dFdx(world_pos), dFdy(world_pos)));
	if (length(n) < 0.001) {
		n = world_n;
	}
	float ny = clamp(n.y, -1.0, 1.0);
	vec2 p = world_pos.xz;
	float broad = noise(p * 0.34) * 0.65 + noise(p * 0.82) * 0.35;
	vec3 grass = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.2, 0.8, broad));
	grass += (noise(p * 14.0) - 0.5) * 0.03;
	float path = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= path_count) break;
		float d = segment_distance(p, path_segments[i].xy, path_segments[i].zw);
		path = max(path, 1.0 - smoothstep(0.35, 1.15, d + (noise(p * 2.8) - 0.5) * 0.42));
	}
	vec3 soil = mix(soil_color.rgb, path_color.rgb, path * 0.7);
	for (int i = 0; i < 32; i++) {
		if (i >= contact_count) break;
		vec4 patch = contact_patches[i];
		float d = length(p - patch.xy) / max(patch.z, 0.001);
		float root = (1.0 - smoothstep(0.1, 1.0, d + (noise(p * 4.0) - 0.5) * 0.2)) * patch.w;
		grass = mix(grass, grass_a.rgb * 0.72, root);
	}
	vec3 rock = triplanar_rock(world_pos, n);
	float grass_w = clamp(vcol.r + smoothstep(0.62, 0.86, ny) * 0.85, 0.0, 1.0);
	float soil_w = clamp(vcol.g + (1.0 - smoothstep(0.50, 0.78, ny)) * 0.55, 0.0, 1.0);
	float rock_w = clamp(vcol.b + (1.0 - smoothstep(0.38, 0.62, ny)), 0.0, 1.0);
	vec3 top = mix(soil, grass, clamp(grass_w, 0.0, 1.0));
	top = mix(top, soil, path * 0.65);
	vec3 albedo = mix(top, rock, clamp(rock_w * (1.0 - grass_w * 0.55), 0.0, 1.0));
	float under = smoothstep(-1.6, -3.6, world_pos.y);
	albedo = mix(albedo, fog_under.rgb, under * 0.55);
	ALBEDO = albedo;
	ROUGHNESS = mix(0.92, 0.78, clamp(rock_w, 0.0, 1.0));
}
