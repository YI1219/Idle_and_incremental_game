shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
uniform vec3 hi_color : source_color = vec3(0.93, 0.95, 0.97);
uniform vec3 lo_color : source_color = vec3(0.78, 0.84, 0.90);
uniform float fade_start = 0.52;
varying float radial;
varying float lift;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	radial = length(wp.xz) / 40.0;
	lift = COLOR.r;
}

void fragment() {
	ALBEDO = mix(lo_color, hi_color, clamp(lift, 0.0, 1.0));
	ALPHA = 1.0 - smoothstep(fade_start, 0.98, radial);
	if (ALPHA < 0.02) {
		discard;
	}
}
