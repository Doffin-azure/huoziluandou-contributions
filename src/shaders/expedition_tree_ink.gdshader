shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 ink_color : source_color = vec4(.05,.10,.12,1.0);
uniform float half_width_pixels = 2.0;

void vertex() {
    vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    // Authored curve tangent, not the triangle's surface normal.
    vec4 next_clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX + NORMAL, 1.0);
    vec2 direction = (next_clip.xy / next_clip.w - clip.xy / clip.w) * VIEWPORT_SIZE;
    direction /= max(length(direction), .0001);
    vec2 perpendicular = vec2(-direction.y, direction.x);
    clip.xy += perpendicular * UV.y * COLOR.r * half_width_pixels * 2.0 / VIEWPORT_SIZE * clip.w;
    clip.z += .000001 * clip.w;
    POSITION = clip;
}

uniform float map_shade = 1.0;

void fragment() {
    ALBEDO = ink_color.rgb * map_shade;
}
