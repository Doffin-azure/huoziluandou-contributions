shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
varying vec3 world_normal;
varying vec4 vertex_tint;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = MODEL_NORMAL_MATRIX * NORMAL;
    vertex_tint = COLOR;
}
void fragment() {
    vec3 color = vertex_tint.rgb;
    if (world_normal.y > 0.8 && abs(world_position.y) < 0.025) {
        vec2 tile = fract(world_position.xz + vec2(0.5));
        float edge = min(min(tile.x, 1.0-tile.x), min(tile.y, 1.0-tile.y));
        float variation = mod(floor(world_position.x+0.5)+floor(world_position.z+0.5),3.0);
        color *= 0.95 + variation*0.025;
        color = mix(color*0.48, color, smoothstep(0.012,0.030,edge));
    }
    ALBEDO = color;
    ROUGHNESS = 1.0;
}
