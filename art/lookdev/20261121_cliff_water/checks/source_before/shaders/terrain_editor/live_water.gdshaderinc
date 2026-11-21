// The physics view supplies absolute height and depth per authoritative cell.
global uniform sampler2D live_water_field : filter_nearest, repeat_disable;
global uniform vec4 live_water_rect;
global uniform float live_water_active;
float live_water_depth(vec3 root){
 if(live_water_active<.5)return 0.0;
 vec2 uv=(root.xz-live_water_rect.xy)/live_water_rect.zw;
 if(uv.x<0.0 || uv.y<0.0 || uv.x>1.0 || uv.y>1.0)return 0.0;
 vec4 water=texture(live_water_field,uv);
 // Cell depth marks water presence. A neighbouring upper lip can project
 // into this texel while its root remains above the actual water surface.
 if(water.a<.5 || water.g<=.0001)return 0.0;
 return max(0.0,water.r-root.y);
}

global uniform sampler2D grass_recovery_field : filter_linear, repeat_disable;
global uniform vec4 grass_recovery_rect;
global uniform float grass_recovery_active;
float live_grass_coverage(vec3 root){
 if(grass_recovery_active<.5)return 1.0-smoothstep(.0005,.004,live_water_depth(root));
 vec2 uv=(root.xz-grass_recovery_rect.xy)/grass_recovery_rect.zw;
 if(any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0))))return 1.0;
 vec4 growth=texture(grass_recovery_field,uv);
 if(growth.a<.5)return 1.0;
 // A high crown projecting into a lower neighbour keeps its own dry grass.
 if(root.y>growth.g+.25 && root.y>growth.b+.004)return 1.0;
 return clamp(growth.r,0.0,1.0);
}
bool grass_coverage_visible(float coverage,vec2 pixel){
 if(coverage>=.999)return true;
 float threshold=fract(52.9829189*fract(dot(floor(pixel),vec2(.06711056,.00583715))));
 return coverage>threshold;
}
