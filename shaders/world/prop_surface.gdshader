shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 albedo : source_color = vec4(0.70, 0.66, 0.58, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform float use_tex = 0.0;
instance uniform float ground_y = 0.0;
#include "res://shaders/world/ground_contact.gdshaderinc"
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = albedo.rgb;
	if (use_tex > 0.5) {
		base *= texture(albedo_tex, UV).rgb;
	}
	ALBEDO = blend_ground_contact(base, world_pos);
	ROUGHNESS = 0.93;
}
