shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 wisp_color : source_color = vec4(0.96, 0.95, 0.90, 1.0);
uniform vec4 island_disks[8];
uniform int island_count = 0;
varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float near = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= island_count) break;
		vec4 disk = island_disks[i];
		float d = length(world_pos.xz - disk.xy);
		near = max(near, 1.0 - smoothstep(disk.z * 0.55, disk.z * 1.35, d));
	}
	float n = noise(world_pos.xz * 0.11 + vec2(TIME * 0.03, TIME * -0.02));
	float ring = smoothstep(0.18, 0.72, n) * near;
	ALBEDO = wisp_color.rgb;
	ALPHA = ring * 0.42;
}
