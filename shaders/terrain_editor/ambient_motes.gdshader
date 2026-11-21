shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform float mote_time = -1.0;
uniform vec3 pollen_color : source_color = vec3(0.98, 0.93, 0.78);
uniform vec3 leaflet_color : source_color = vec3(0.76, 0.83, 0.58);
uniform float opacity_scale : hint_range(0.0, 2.0) = 1.0;

varying vec4 v_custom;
varying float v_cam_fade;
varying float v_twinkle;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	float t = mote_time >= 0.0 ? mote_time : TIME;
	float seed = v_custom.x * 62.8318;
	float drift_radius = mix(0.45, 1.35, v_custom.y);
	float speed = mix(0.26, 0.54, v_custom.z);
	bool is_leaf = v_custom.w >= 0.76;

	vec3 anchor = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 drift = vec3(
		sin(t * speed + seed) * drift_radius + cos(t * 0.19 + seed * 1.7) * 0.42,
		sin(t * speed * 0.72 + seed * 1.31) * (is_leaf ? 0.52 : 0.34),
		cos(t * speed * 0.83 + seed * 0.91) * drift_radius * 0.78 + sin(t * 0.17 + seed) * 0.35
	);
	if (is_leaf) {
		float fall_cycle = fract(t * 0.055 + v_custom.y);
		drift.y += mix(0.85, -0.75, fall_cycle);
		drift.x += fall_cycle * 0.95;
	}
	vec3 world_center = anchor + drift;
	float cam_dist = length(CAMERA_POSITION_WORLD - world_center);
	v_cam_fade = smoothstep(3.2, 7.5, cam_dist) * (1.0 - smoothstep(48.0, 76.0, cam_dist));
	float raw_tw = 0.5 + 0.5 * sin(t * (is_leaf ? 1.35 : 1.05) + seed * 2.3);
	v_twinkle = pow(raw_tw, 1.35);

	float size = is_leaf ? mix(0.042, 0.064, v_custom.z) : mix(0.036, 0.062, v_custom.z);
	vec3 cam_right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 cam_up = normalize(INV_VIEW_MATRIX[1].xyz);
	if (is_leaf) {
		float spin = t * mix(1.1, 1.9, v_custom.x) + seed;
		float cs = cos(spin);
		float sn = sin(spin);
		vec3 r2 = cam_right * cs + cam_up * sn;
		vec3 u2 = (-cam_right * sn + cam_up * cs) * (0.58 + 0.42 * abs(cos(t * 0.9 + seed)));
		cam_right = r2;
		cam_up = u2;
	}
	vec3 world_pos = world_center + (cam_right * VERTEX.x + cam_up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	bool is_leaf = v_custom.w >= 0.76;
	if (is_leaf) {
		float leaf_mask = 1.0 - smoothstep(0.56, 0.88, abs(p.x) * 1.85 + p.y * p.y * 0.92);
		float alpha = leaf_mask * v_cam_fade * mix(0.28, 0.54, v_twinkle) * opacity_scale;
		if (alpha < 0.008) {
			discard;
		}
		ALBEDO = mix(leaflet_color * 0.88, leaflet_color * 1.12, clamp(p.y * 0.5 + 0.5, 0.0, 1.0));
		ALPHA = clamp(alpha, 0.0, 0.58);
	} else {
		float r2 = dot(p, p);
		float halo = exp(-r2 * 3.8);
		float core = exp(-r2 * 11.5);
		float alpha = (halo * 0.28 + core * 0.30) * v_cam_fade * (0.28 + 0.72 * v_twinkle) * opacity_scale;
		if (alpha < 0.005) {
			discard;
		}
		ALBEDO = mix(pollen_color, vec3(1.0, 0.99, 0.92), core * 0.55);
		ALPHA = clamp(alpha, 0.0, 0.54);
	}
}
