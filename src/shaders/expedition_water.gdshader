shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D fog_mask : filter_linear, repeat_disable;
#include "res://src/shaders/expedition_vision.gdshaderinc"
uniform vec3 water_tint : source_color = vec3(.032,.042,.052);
uniform vec3 fog_color : source_color = vec3(.022,.026,.033);
uniform bool outer_fade = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p = world_position.xz;
    float wave = pow(max(0.0,sin(p.x*3.0+sin(p.y*1.3+TIME*.22)*.4+TIME*.16)),40.0);
    vec3 col = water_tint*(.78+wave*.14);
    vec2 fog = map_vision_at(p);
    col *= mix(.42,1.0,smoothstep(.05,.9,fog.g));
    float explored = smoothstep(.08,.70,fog.r);
    if (outer_fade) {
        vec2 outside = max(max(-p,p-vec2(12,8)),vec2(0));
        explored *= 1.0-smoothstep(.6,2.6,length(outside));
    }
    ALBEDO = mix(fog_color,col,explored);
}
