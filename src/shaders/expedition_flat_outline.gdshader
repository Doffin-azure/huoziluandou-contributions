shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 ink_color : source_color;
uniform float width_pixels = 2.2;

void vertex() {
    vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    vec4 clip_position = PROJECTION_MATRIX * view_position;
    // NORMAL carries the line direction; UV selects its endpoint and side.
    vec4 other_position = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX + NORMAL, 1.0);
    vec2 delta = (other_position.xy / other_position.w - clip_position.xy / clip_position.w) * VIEWPORT_SIZE;
    vec2 along = delta / max(length(delta), 0.0001);
    vec2 across = vec2(-along.y, along.x);
    vec2 offset = across * UV.y + along * (UV.x * 2.0 - 1.0);
    clip_position.xy += offset * width_pixels * 2.0 / VIEWPORT_SIZE * clip_position.w;
    clip_position.z += 0.000001 * clip_position.w;
    POSITION = clip_position;
}

uniform float map_shade = 1.0;

void fragment() {
    ALBEDO = ink_color.rgb * map_shade;
}
