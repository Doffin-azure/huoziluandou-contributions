shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform sampler2D fog_mask : filter_linear, repeat_disable;
#include "res://src/shaders/expedition_vision.gdshaderinc"
uniform vec3 fog_color : source_color = vec3(.030,.037,.047);
varying vec2 map_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() { map_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
    float explored = map_vision_at(map_position).r;
    // Opaque at unknown cell centres, transparent on revealed ground. This
    // prevents shore silhouettes leaking even without volumetric rendering.
    ALPHA = 1.0-smoothstep(.08,.92,explored);
    float cloud = noise(map_position*.8+vec2(TIME*.015,-TIME*.009));
    ALBEDO = fog_color * mix(.85,1.15,cloud);
}
