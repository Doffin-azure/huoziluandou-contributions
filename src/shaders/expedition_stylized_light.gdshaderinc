// Native Godot lights/shadow maps, with broad diffuse bands and no specular gloss.
// Keep attenuation continuous: quantizing it makes ugly rings around local lamps.
uniform float diffuse_response : hint_range(0.0, 1.5) = 1.0;
void light() {
    float facing = max(dot(normalize(NORMAL), LIGHT), 0.0);
    float painted = smoothstep(0.02, 0.18, facing) * 0.30
        + smoothstep(0.35, 0.52, facing) * 0.42
        + smoothstep(0.72, 0.88, facing) * 0.28;
    // Godot multiplies the accumulated diffuse result by ALBEDO afterwards.
    DIFFUSE_LIGHT += (LIGHT_COLOR / PI) * painted * ATTENUATION * diffuse_response;
}
