shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D fog_mask : filter_linear, repeat_disable;
#include "res://src/shaders/expedition_vision.gdshaderinc"
uniform vec3 tint : source_color = vec3(.13,.17,.15);
uniform vec3 grass_dark : source_color = vec3(.08,.16,.14);
uniform vec3 grass_moss : source_color = vec3(.24,.31,.22);
uniform vec3 fog_color : source_color = vec3(.039,.082,.114);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p = world_position.xz;
    float grain = sin(p.x*3.1+sin(p.y*1.7)) * sin(p.y*2.6+p.x*.4);
    float blades = smoothstep(.48,.82,fract(sin(dot(floor(p*2.0),vec2(41.7,17.3)))*43758.5));
    float moss = smoothstep(.70,.94,fract(sin(dot(floor(p*.72),vec2(12.8,73.1)))*19341.2));
    vec3 planted = mix(tint,grass_dark,blades*.34);
    planted = mix(planted,grass_moss,moss*.16);
    vec2 fog = map_vision_at(p);
    float explored = smoothstep(.08,.70,fog.r);
    ALBEDO = planted * (1.0 + grain*.035) * mix(.42,1.0,smoothstep(.08,.9,fog.g)) * explored;
    EMISSION = fog_color*(1.0-explored);
    ROUGHNESS = 1.0; SPECULAR = 0.0;
}
#include "res://src/shaders/expedition_stylized_light.gdshaderinc"
