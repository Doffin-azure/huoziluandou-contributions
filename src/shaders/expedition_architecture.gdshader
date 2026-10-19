shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D fog_mask : filter_linear, repeat_disable;
uniform vec2 quadrant = vec2(0);
uniform vec4 tint : source_color = vec4(1.0);
uniform bool fog_enabled = false;
uniform bool solid_color = false;
varying vec3 world_position;
varying float face_value;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1)).xyz;
    face_value = mix(0.67,1.0,clamp(NORMAL.y,0.0,1.0));
}
void fragment() {
    vec2 uv = mix(vec2(0.012), vec2(0.988), fract(UV * 0.999));
    vec3 col = texture(atlas, (quadrant + uv) * 0.5).rgb * tint.rgb;
    if (solid_color) { col = tint.rgb; }
    col *= face_value;
    if (fog_enabled) {
        vec2 fog = texture(fog_mask, clamp(world_position.xz/vec2(12,8), vec2(0.001), vec2(0.999))).rg;
        col *= mix(0.35, 1., smoothstep(0.08,0.9,fog.g));
        col = mix(vec3(0.025,0.07,0.075), col, smoothstep(0.08,0.70,fog.r));
    }
    ALBEDO = col;
    ROUGHNESS = 1.;
}
