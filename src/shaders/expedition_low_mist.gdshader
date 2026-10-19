shader_type fog;
uniform sampler2D fog_mask : filter_linear, repeat_disable;
#include "res://src/shaders/expedition_vision.gdshaderinc"
uniform vec3 camera_position = vec3(6.0,8.0,12.0);
uniform float unknown_density = 2.8;
uniform float remembered_density = .20;
uniform vec4 mist_color : source_color = vec4(.31,.33,.37,1.0);

float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void fog() {
    vec3 p = WORLD_POSITION;
    vec2 drift = vec2(TIME*.022,-TIME*.012);
    float clouds = noise(p.xz*.65+drift)*.70+noise(p.xz*1.4-drift)*.30;
    float wisps = smoothstep(.23,.73,clouds);
    float low = 1.0-smoothstep(.25,1.65,p.y);
    float bottom = smoothstep(-.85,-.40,p.y);
    vec2 edge = abs((p.xz-OBJECT_POSITION.xz)/(SIZE.xz*.5));
    float boundary = 1.0-smoothstep(.72,1.0,max(edge.x,edge.y));
    vec2 known = map_vision_at(p.xz);
    // Clear the line of sight to revealed ground as well. A tall fog bank in
    // a foreground unknown cell must not cover visible cells behind it.
    vec3 ray = p-camera_position;
    vec2 ground = p.xz-ray.xz*p.y/min(ray.y,-.001);
    vec2 target = map_vision_at(ground);
    known = max(known,target);
    float explored = smoothstep(.08,.92,known.r);
    float visible = smoothstep(.08,.92,known.g);
    float unknown = (1.0-explored)*unknown_density;
    float remembered = explored*(1.0-visible)*remembered_density;
    // Noise shapes the bank; it never opens holes into unexplored terrain.
    DENSITY = (unknown*(.72+wisps*.28)+remembered*wisps) * (1.0-visible) * low * bottom * boundary;
    ALBEDO = mist_color.rgb;
    // A small ambient contribution keeps shadowed ink wisps violet, not white.
    EMISSION = vec3(.006,.006,.009);
}
