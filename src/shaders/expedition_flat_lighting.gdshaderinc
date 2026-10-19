uniform vec3 fire_position = vec3(0.0);
uniform vec4 fire_color : source_color = vec4(1.0, 0.75, 0.47, 1.0);
uniform float fire_radius = 2.2;
uniform float fire_energy = 0.0;
uniform float fire_pulse = 1.0;

vec3 painted_fire_light(vec3 base, vec3 point, vec3 normal) {
    vec3 offset = fire_position - point;
    float distance_to_fire = length(offset);
    float falloff = max(0.0, 1.0 - distance_to_fire / max(0.001, fire_radius));
    float facing = smoothstep(-0.05, 0.8, dot(normalize(normal), offset / max(0.001, distance_to_fire)));
    float amount = falloff * facing;
    // A quiet wash plus two broad painted light bands, with bounded brightness.
    float wash = falloff * falloff * 0.075;
    float bands = smoothstep(0.14, 0.24, amount) * 0.09 + smoothstep(0.40, 0.55, amount) * 0.10;
    return mix(base, fire_color.rgb, clamp((wash + bands) * fire_energy * fire_pulse, 0.0, 0.30));
}
