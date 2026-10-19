shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled;
uniform vec3 deep_color : source_color;
uniform vec3 light_color : source_color;
uniform float map_shade = 1.0;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 p = world_position.xz;
    // World-space bands cross grid boundaries with one shared clock.
    float band = sin(p.x*2.0+p.y*.6+sin(p.y*1.7)*.32+TIME*.10);
    float quiet = smoothstep(-.8,.8,band)*.22;
    float stroke = smoothstep(.985,1.0,sin(p.x*4.0-p.y*.4+sin(p.y*2.1)*.16+TIME*.08));
    vec3 paint = mix(deep_color,light_color,quiet+stroke*.075);
    ALBEDO = paint*map_shade;
}
