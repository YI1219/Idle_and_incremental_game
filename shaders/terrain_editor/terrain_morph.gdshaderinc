// Edit growth. A published terrain revision eases up from the heights on
// screen before the edit. Per cell, r is the previous top and g the new one.
// A column maps linearly between them above a shared floor, so expanded land
// rises and a raise lifts the wall with it. Instanced decoration moves with
// the column at its origin. TerrainRenderer drives the uniforms.
global uniform sampler2D terrain_morph_field : filter_linear, repeat_disable;
global uniform vec4 terrain_morph_rect;
global uniform float terrain_morph_progress;
const float TERRAIN_MORPH_FLOOR = -7.0;

float terrain_morph_ease(float t){
	float u = clamp(t, 0.0, 1.0) - 1.0;
	return 1.0 + 2.2 * u * u * u + 1.2 * u * u;
}
float terrain_morph_offset(vec3 p){
	if(terrain_morph_progress >= 1.0) return 0.0;
	vec2 uv = (p.xz - terrain_morph_rect.xy) / terrain_morph_rect.zw;
	if(uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0;
	vec2 tops = texture(terrain_morph_field, uv).rg;
	float scale = (tops.x - TERRAIN_MORPH_FLOOR) / max(tops.y - TERRAIN_MORPH_FLOOR, .001);
	float old_y = TERRAIN_MORPH_FLOOR + (p.y - TERRAIN_MORPH_FLOOR) * scale;
	return (old_y - p.y) * (1.0 - terrain_morph_ease(terrain_morph_progress));
}
