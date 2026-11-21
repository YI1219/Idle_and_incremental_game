// The physics view supplies absolute height and depth per authoritative cell.
global uniform sampler2D live_water_field : filter_nearest, repeat_disable;
global uniform vec4 live_water_rect;
global uniform float live_water_active;
float live_water_depth(vec2 p){
 if(live_water_active<.5)return 0.0;
 vec2 uv=(p-live_water_rect.xy)/live_water_rect.zw;
 if(uv.x<0.0 || uv.y<0.0 || uv.x>1.0 || uv.y>1.0)return 0.0;
 return max(0.0,texture(live_water_field,uv).g);
}
