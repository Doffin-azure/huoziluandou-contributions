shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.8,0.55,0.19,0.2);
uniform float map_shade = 1.0;
void fragment() {
    float falloff = 1.0-smoothstep(0.05,0.5,length(UV-vec2(0.5)));
    ALBEDO = tint.rgb*map_shade;
    ALPHA = tint.a*falloff*falloff*map_shade;
}
