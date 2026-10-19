shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D fog_mask : filter_linear, repeat_disable;
#include "res://src/shaders/expedition_vision.gdshaderinc"
uniform vec3 stone_color : source_color = vec3(.115,.125,.130);
uniform vec3 fog_color : source_color = vec3(.022,.026,.033);
uniform float water_level = -.32;
uniform bool outer_fade = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 fog = map_vision_at(world_position.xz);
    float explored = smoothstep(.08,.70,fog.r);
    if (outer_fade) {
        vec2 p = world_position.xz;
        vec2 outside = max(max(-p,p-vec2(12,8)),vec2(0));
        explored *= 1.0-smoothstep(.6,2.6,length(outside));
    }
    float waterline = smoothstep(water_level-.16,water_level+.10,world_position.y);
    ALBEDO = stone_color*mix(.61,1.0,waterline)*mix(.42,1.0,smoothstep(.08,.9,fog.g))*explored;
    EMISSION = fog_color*(1.0-explored);
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
#include "res://src/shaders/expedition_stylized_light.gdshaderinc"
