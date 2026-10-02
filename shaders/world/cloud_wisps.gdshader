shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, blend_mix;
uniform vec4 wisp_color : source_color = vec4(0.98, 0.97, 0.93, 1.0);
uniform vec4 shade_color : source_color = vec4(0.62, 0.70, 0.74, 1.0);
uniform vec4 island_disks[8];
uniform int island_count = 0;
varying vec3 world_pos;
varying float lift;

float hash(vec2 p) { return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lift = noise(world_pos.xz * 0.08);
	VERTEX.y += (lift - 0.35) * 1.6;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float near = 0.18;
	for (int i = 0; i < 8; i++) {
		if (i >= island_count) break;
		vec4 disk = island_disks[i];
		float d = length(world_pos.xz - disk.xy);
		near = max(near, 1.0 - smoothstep(disk.z * 0.35, disk.z * 1.55, d));
	}
	float n = noise(world_pos.xz * 0.09 + vec2(TIME * 0.03, TIME * -0.02));
	float ring = smoothstep(0.22, 0.78, n * 0.55 + lift * 0.45) * near;
	ALBEDO = mix(shade_color.rgb, wisp_color.rgb, ring);
	ALPHA = clamp(mix(0.55, 0.95, ring), 0.0, 0.95);
}
