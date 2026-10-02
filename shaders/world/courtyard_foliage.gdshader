shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform sampler2D leaf_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 shade_color : source_color = vec4(0.19, 0.36, 0.28, 1.0);
uniform vec4 sun_color : source_color = vec4(0.57, 0.67, 0.37, 1.0);
uniform float wind_strength = 0.05;
uniform float preserve_color = 0.0;
instance uniform float ground_y = 0.0;
#include "res://shaders/world/ground_contact.gdshaderinc"
varying vec3 world_pos;
varying float local_height;
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    local_height = VERTEX.y;
    float tip = smoothstep(0.1, 2.0, VERTEX.y);
    float gust = sin(TIME * 0.85 + world_pos.x * 0.38 + world_pos.z * 0.3);
    VERTEX.x += gust * wind_strength * tip;
    VERTEX.z += sin(TIME * 1.15 + world_pos.x * 0.6) * wind_strength * 0.45 * tip;
    // Upward-biased normals gather light as a soft crown rather than separate dark cards.
    NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.91));
}
void fragment() {
    vec4 tex = texture(leaf_texture, UV);
    ALPHA = tex.a;
    ALPHA_SCISSOR_THRESHOLD = 0.38;
    float value = dot(tex.rgb, vec3(0.3, 0.5, 0.2));
    float crown = smoothstep(0.25, 4.0, local_height);
    float variation = sin(world_pos.x * 0.95 + world_pos.z * 0.72) * 0.07;
    vec3 leaf = mix(shade_color.rgb, sun_color.rgb, clamp(value * 0.62 + crown * 0.25 + variation, 0.0, 1.0));
    ALBEDO = blend_ground_contact(mix(leaf, tex.rgb, preserve_color), world_pos);
    ROUGHNESS = 0.95;
    BACKLIGHT = ALBEDO * 0.36;
}
