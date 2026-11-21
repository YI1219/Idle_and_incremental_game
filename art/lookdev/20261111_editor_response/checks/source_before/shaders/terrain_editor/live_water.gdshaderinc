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
