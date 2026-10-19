shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 paint : source_color;
uniform float emission_energy = 0.5;
uniform float clock = 0.0;
uniform float phase = 0.0;
uniform float map_shade = 1.0;

void vertex() {
    float tip = clamp(VERTEX.y / 0.65, 0.0, 1.0);
    VERTEX.x += (sin(clock * 4.3 + VERTEX.y * 8.0 + phase) * 0.020 + sin(clock * 2.1) * 0.012) * tip;
    VERTEX.y *= 1.0 + sin(clock * 3.2 + phase) * 0.045;
}

void fragment() {
    ALBEDO = paint.rgb * map_shade;
    EMISSION = paint.rgb * emission_energy * map_shade;
}
