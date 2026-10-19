shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 water_color : source_color = vec4(.10,.22,.25,1.0);

void fragment() {
    // The quiet river joins the distant haze without exposing a rectangular plane edge.
    float north = smoothstep(0.0, 0.25, UV.y);
    float sides = smoothstep(0.0, 0.12, UV.x) * smoothstep(0.0, 0.12, 1.0 - UV.x);
    float south = smoothstep(0.0, 0.15, 1.0 - UV.y);
    ALBEDO = water_color.rgb;
    ALPHA = north * sides * south * .96;
}
